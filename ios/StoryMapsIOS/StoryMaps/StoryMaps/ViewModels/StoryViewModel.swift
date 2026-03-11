/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Combine
import CoreLocation

@MainActor
class StoryViewModel: ObservableObject {
    @Published var story: AudioStory?
    @Published var loadingMessage = ""
    @Published var isBackgroundGenerating = false
    @Published var bufferingError: String?
    @Published var activeRoute: RouteDetails?
    @Published var userCoordinate: Coordinate?
    @Published var liveJourneyContext: LiveJourneyContext = .empty

    let locationManager = LocationManager()

    private var currentRoute: RouteDetails?
    private var isGenerating = false
    private var failedSegments: Set<Int> = []
    private var retryAttempts: [Int: Int] = [:]
    private var lastGenerationTime: Date?
    private var generationSessionID = UUID()
    private var cancellables = Set<AnyCancellable>()
    private var lastPlaybackIndex = 0
    private var lastPOIRefreshLocation: Coordinate?
    private var lastRerouteAt: Date?
    private var lastProcessedLocation: Coordinate?
    private var lastLocationRefreshAt: Date?
    private var consecutiveOffRouteUpdates = 0

    private let maxRetryAttempts = 3
    private let segmentsToBufferAhead = 2
    private let rateLimitDelay: TimeInterval = 0.0
    private let poiRefreshDistanceMeters: CLLocationDistance = 120
    private let poiRefreshCooldown: TimeInterval = 15
    private let offRouteThresholdMeters: CLLocationDistance = 45
    private let rerouteCooldown: TimeInterval = 20
    private let rerouteMinimumDistanceMeters: CLLocationDistance = 55

    init() {
        locationManager.$userLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self, let location else { return }
                Task { @MainActor in
                    await self.handleLocationUpdate(location)
                }
            }
            .store(in: &cancellables)
    }

    func generateInitialStory(for route: RouteDetails) async throws {
        let sessionID = UUID()
        generationSessionID = sessionID
        currentRoute = route
        activeRoute = route
        liveJourneyContext = .empty
        userCoordinate = route.startCoordinate
        lastPlaybackIndex = 0
        lastPOIRefreshLocation = nil
        lastRerouteAt = nil
        lastProcessedLocation = nil
        lastLocationRefreshAt = nil
        consecutiveOffRouteUpdates = 0

        if route.isFreeRoam {
            locationManager.startUpdatingLocation()
            try await generateInitialFreeRoamStory(for: route, sessionID: sessionID)
        } else {
            locationManager.stopUpdatingLocation()
            try await generateInitialPlannedStory(for: route, sessionID: sessionID)
        }
    }

    func bufferNextSegments() {
        guard let story, let route = currentRoute else {
            return
        }

        if isGenerating { return }

        let neededSegmentCount = lastPlaybackIndex + segmentsToBufferAhead + 1
        let withinFiniteLimit = story.isContinuous || story.segments.count < story.totalSegmentsEstimate

        guard story.segments.count < neededSegmentCount, withinFiniteLimit else {
            return
        }

        isGenerating = true
        isBackgroundGenerating = true
        bufferSegment(index: story.segments.count + 1, route: route)
    }

    func handlePlaybackIndexChanged(_ index: Int) {
        lastPlaybackIndex = index
        bufferNextSegments()
    }

    func retryFailedSegments() {
        guard currentRoute != nil else { return }

        if let nextFailedIndex = failedSegments.sorted().first {
            failedSegments.remove(nextFailedIndex)
            bufferNextSegments()
        }
    }

    func reset() {
        generationSessionID = UUID()
        story = nil
        currentRoute = nil
        activeRoute = nil
        isGenerating = false
        isBackgroundGenerating = false
        loadingMessage = ""
        bufferingError = nil
        failedSegments.removeAll()
        retryAttempts.removeAll()
        lastGenerationTime = nil
        lastPlaybackIndex = 0
        liveJourneyContext = .empty
        userCoordinate = nil
        lastPOIRefreshLocation = nil
        lastRerouteAt = nil
        lastProcessedLocation = nil
        lastLocationRefreshAt = nil
        consecutiveOffRouteUpdates = 0
        locationManager.stopUpdatingLocation()
    }

    private func generateInitialPlannedStory(for route: RouteDetails, sessionID: UUID) async throws {
        let totalSegments = StoryService.shared.defaultTotalSegments(for: route)
        let fallbackOutline = StoryService.shared.makeFallbackOutline(for: route, totalSegments: totalSegments)
        let outlineTask = Task(priority: .utility) {
            try await StoryService.shared.generateOutline(for: route)
        }

        loadingMessage = "Writing first chapter..."
        let firstOutlineBeat = fallbackOutline.first ?? "Begin the journey."
        var firstSegment = try await StoryService.shared.generateSegment(
            for: route,
            segmentIndex: 1,
            totalSegments: totalSegments,
            outlineBeat: firstOutlineBeat,
            previousContext: ""
        )

        lastGenerationTime = Date()

        loadingMessage = "Preparing audio stream..."
        await applyRateLimit()

        let audioData = try await StoryService.shared.generateAudio(for: firstSegment.text, voiceName: route.voiceName)
        firstSegment.audioData = audioData

        story = AudioStory(
            totalSegmentsEstimate: totalSegments,
            outline: fallbackOutline,
            segments: [firstSegment]
        )

        bufferNextSegments()

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let outline = try? await outlineTask.value else { return }
            guard self.generationSessionID == sessionID else { return }
            guard var currentStory = self.story else { return }

            currentStory.outline = outline
            self.story = currentStory
        }
    }

    private func generateInitialFreeRoamStory(for route: RouteDetails, sessionID: UUID) async throws {
        let initialLocation = locationManager.userLocation ?? CLLocation(latitude: route.startCoordinate.latitude, longitude: route.startCoordinate.longitude)
        let initialContext = try await buildLiveContext(from: initialLocation, route: route, forcePOIRefresh: true)

        guard generationSessionID == sessionID else { return }

        liveJourneyContext = initialContext
        loadingMessage = "Listening to your surroundings..."

        let generated = try await StoryService.shared.generateContextualSegment(
            for: route,
            liveContext: initialContext,
            narrativeState: .empty,
            segmentIndex: 1,
            previousContext: ""
        )

        var firstSegment = generated.segment
        lastGenerationTime = Date()

        loadingMessage = "Preparing live audio..."
        await applyRateLimit()

        let audioData = try await StoryService.shared.generateAudio(for: firstSegment.text, voiceName: route.voiceName)
        firstSegment.audioData = audioData

        story = AudioStory(
            totalSegmentsEstimate: StoryService.shared.defaultTotalSegments(for: route),
            outline: [],
            segments: [firstSegment],
            isContinuous: true,
            narrativeState: generated.narrativeState
        )

        bufferNextSegments()
    }

    private func bufferSegment(index: Int, route: RouteDetails) {
        let sessionID = generationSessionID

        Task {
            bufferingError = nil

            defer {
                Task { @MainActor in
                    self.isGenerating = false
                    self.isBackgroundGenerating = false
                }
            }

            var lastError: Error?

            for attempt in 1...maxRetryAttempts {
                do {
                    guard generationSessionID == sessionID else { return }
                    await applyRateLimit()
                    guard var currentStory = story,
                          let currentRoute = currentRoute else { return }

                    let previousText = currentStory.segments.map { $0.text }.joined(separator: " ")
                    let trimmedContext = String(previousText.suffix(3000))

                    let newSegment: StorySegment

                    if currentRoute.isFreeRoam {
                        let liveContext = try await latestLiveContext(for: currentRoute)
                        let generated = try await StoryService.shared.generateContextualSegment(
                            for: currentRoute,
                            liveContext: liveContext,
                            narrativeState: currentStory.narrativeState,
                            segmentIndex: index,
                            previousContext: trimmedContext
                        )
                        newSegment = generated.segment
                        currentStory.narrativeState = generated.narrativeState
                    } else {
                        let outlineBeat = currentStory.outline.indices.contains(index - 1)
                            ? currentStory.outline[index - 1]
                            : "Continue the journey forward, deepen the atmosphere, and move the traveler toward a satisfying conclusion."

                        newSegment = try await StoryService.shared.generateSegment(
                            for: currentRoute,
                            segmentIndex: index,
                            totalSegments: currentStory.totalSegmentsEstimate,
                            outlineBeat: outlineBeat,
                            previousContext: trimmedContext
                        )
                    }

                    lastGenerationTime = Date()
                    await applyRateLimit()

                    let audioData = try await StoryService.shared.generateAudio(for: newSegment.text, voiceName: currentRoute.voiceName)
                    var hydratedSegment = newSegment
                    hydratedSegment.audioData = audioData
                    lastGenerationTime = Date()

                    await MainActor.run {
                        guard generationSessionID == sessionID else { return }
                        self.story?.segments.append(hydratedSegment)
                        if currentRoute.isFreeRoam {
                            self.story?.narrativeState = currentStory.narrativeState
                        }
                        self.failedSegments.remove(index)
                        self.retryAttempts.removeValue(forKey: index)
                    }

                    return
                } catch {
                    lastError = error
                    retryAttempts[index] = retryAttempts[index, default: 0] + 1

                    if attempt < maxRetryAttempts {
                        let delay = 3.0 * Double(pow(2.0, Double(attempt - 1)))
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }

            await MainActor.run {
                self.failedSegments.insert(index)
                self.bufferingError = "Failed to generate segment \(index) after \(maxRetryAttempts) attempts"
                print("❌ [Buffering] Segment \(index) failed permanently: \(lastError?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func latestLiveContext(for route: RouteDetails) async throws -> LiveJourneyContext {
        let location = locationManager.userLocation ?? CLLocation(
            latitude: userCoordinate?.latitude ?? route.startCoordinate.latitude,
            longitude: userCoordinate?.longitude ?? route.startCoordinate.longitude
        )

        let shouldRefreshPOIs = shouldRefreshPOIs(for: Coordinate(clLocation: location.coordinate))
        let context = try await buildLiveContext(
            from: location,
            route: route,
            forcePOIRefresh: shouldRefreshPOIs
        )
        liveJourneyContext = context
        return context
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        let coordinate = Coordinate(clLocation: location.coordinate)
        userCoordinate = coordinate

        guard let route = currentRoute, route.isFreeRoam else {
            return
        }

        let shouldRefresh = shouldRefreshPOIs(for: coordinate)

        do {
            let context = try await buildLiveContext(
                from: location,
                route: route,
                forcePOIRefresh: shouldRefresh
            )
            liveJourneyContext = context
            lastProcessedLocation = coordinate
            lastLocationRefreshAt = Date()

            if context.isOffRoute {
                consecutiveOffRouteUpdates += 1
            } else {
                consecutiveOffRouteUpdates = 0
            }

            if shouldReroute(for: route, context: context) {
                try await reroute(from: location, route: route)
            }
        } catch {
            print("⚠️ Live context update failed: \(error.localizedDescription)")
        }
    }

    private func shouldRefreshPOIs(for coordinate: Coordinate) -> Bool {
        guard let lastPOIRefreshLocation else {
            return true
        }

        if lastPOIRefreshLocation.distance(to: coordinate) >= poiRefreshDistanceMeters {
            return true
        }

        if let lastLocationRefreshAt, Date().timeIntervalSince(lastLocationRefreshAt) >= poiRefreshCooldown {
            return true
        }

        return false
    }

    private func buildLiveContext(
        from location: CLLocation,
        route: RouteDetails,
        forcePOIRefresh: Bool
    ) async throws -> LiveJourneyContext {
        let coordinate = Coordinate(clLocation: location.coordinate)
        let nearest = Coordinate.nearestPoint(to: coordinate, on: route.polyline)
        let distanceFromRoute = nearest?.distanceMeters
        let isOffRoute = route.polyline.count > 1 && (distanceFromRoute ?? 0) > offRouteThresholdMeters

        var nearbyPOIs = liveJourneyContext.nearbyPOIs
        if forcePOIRefresh || nearbyPOIs.isEmpty {
            do {
                nearbyPOIs = try await NearbyPlacesClient.shared.fetchNearbyPOIs(around: coordinate)
                lastPOIRefreshLocation = coordinate
            } catch {
                print("⚠️ Nearby POI refresh failed: \(error.localizedDescription)")
                nearbyPOIs = liveJourneyContext.nearbyPOIs
            }
        }

        let routeSummary: String
        if route.endCoordinate == nil {
            routeSummary = isOffRoute
                ? "The traveler has moved beyond the last implied path and is roaming freely through a new stretch of the city."
                : "The traveler is roaming freely with no fixed destination, and the narration should follow the immediate surroundings."
        } else if isOffRoute {
            routeSummary = "The traveler has drifted away from the prior route and may be exploring an alternate path toward \(route.endAddress)."
        } else {
            routeSummary = "The traveler is still broadly following the current route toward \(route.endAddress)."
        }

        return LiveJourneyContext(
            currentLocation: coordinate,
            snappedLocation: nearest?.point ?? coordinate,
            headingDegrees: location.course >= 0 ? location.course : nil,
            speedMps: location.speed >= 0 ? location.speed : nil,
            distanceFromRouteMeters: distanceFromRoute,
            isOffRoute: isOffRoute,
            nearbyPOIs: nearbyPOIs,
            routeSummary: routeSummary
        )
    }

    private func shouldReroute(for route: RouteDetails, context: LiveJourneyContext) -> Bool {
        guard route.endCoordinate != nil else { return false }
        guard context.isOffRoute else { return false }
        guard (context.distanceFromRouteMeters ?? 0) >= rerouteMinimumDistanceMeters else { return false }
        guard consecutiveOffRouteUpdates >= 2 else { return false }

        if let lastRerouteAt, Date().timeIntervalSince(lastRerouteAt) < rerouteCooldown {
            return false
        }

        return true
    }

    private func reroute(from location: CLLocation, route: RouteDetails) async throws {
        guard let destination = route.endCoordinate else { return }

        let directions = try await DirectionsClient.shared.getDirections(
            from: Coordinate(clLocation: location.coordinate),
            to: destination,
            travelMode: route.travelMode
        )

        let updatedRoute = RouteDetails(
            id: route.id,
            startAddress: directions.startAddress,
            endAddress: directions.endAddress,
            distance: directions.distance,
            duration: directions.duration,
            durationSeconds: directions.durationSeconds,
            travelMode: route.travelMode,
            voiceName: route.voiceName,
            storyStyle: route.storyStyle,
            polyline: directions.polyline,
            startCoordinate: Coordinate(clLocation: location.coordinate),
            endCoordinate: destination,
            journeyMode: route.journeyMode,
            routeVersion: route.routeVersion + 1
        )

        currentRoute = updatedRoute
        activeRoute = updatedRoute
        lastRerouteAt = Date()
        consecutiveOffRouteUpdates = 0

        let refreshedContext = try await buildLiveContext(from: location, route: updatedRoute, forcePOIRefresh: false)
        liveJourneyContext = refreshedContext
    }

    private func applyRateLimit() async {
        guard rateLimitDelay > 0 else {
            return
        }

        guard let lastTime = lastGenerationTime else {
            return
        }

        let timeSinceLastCall = Date().timeIntervalSince(lastTime)
        if timeSinceLastCall < rateLimitDelay {
            let waitTime = rateLimitDelay - timeSinceLastCall
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }
}
