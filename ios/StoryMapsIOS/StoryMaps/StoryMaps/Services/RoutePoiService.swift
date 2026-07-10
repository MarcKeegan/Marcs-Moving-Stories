/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Fetches real points of interest along a planned route (via the server's
/// /api/nearby-pois proxy) and assigns them to story segments so the narration
/// can reference actual places the traveler is passing. Mirrors the web
/// client's services/poiService.ts so both platforms ground stories the same
/// way.
///
/// Everything is best-effort: any failure or timeout yields an empty
/// assignment and story generation proceeds exactly as before.
struct RoutePoiService {

    /// Cap on Places requests per journey, independent of journey length.
    private static let maxSamplePoints = 8
    private static let poisPerSegment = 2

    /// Landmark-ish place types get priority over generic businesses.
    private static let notableTypes: Set<String> = [
        "tourist_attraction", "museum", "park", "church", "place_of_worship",
        "landmark", "stadium", "university", "library", "art_gallery",
        "city_hall", "castle", "cemetery", "zoo", "aquarium", "amusement_park",
        "natural_feature", "town_square", "historical_landmark",
    ]

    /// Types that make for poor storytelling scenery.
    private static let boringTypes: Set<String> = [
        "lodging", "gas_station", "parking", "atm", "car_repair", "car_wash",
        "car_dealer", "storage", "real_estate_agency", "insurance_agency",
        "lawyer", "dentist", "doctor", "bank", "finance", "moving_company",
    ]

    /// Fetch and assign landmarks for a planned journey. Returns landmark
    /// names keyed by 1-based segment index. Never throws; the whole lookup
    /// is capped by `timeout` so a slow network can't stall story generation.
    static func fetchSegmentLandmarks(
        polyline: [Coordinate],
        travelMode: String,
        totalSegments: Int,
        timeout: TimeInterval = 6
    ) async -> [Int: [String]] {
        guard !polyline.isEmpty, totalSegments > 0 else { return [:] }

        let work = Task { () -> [Int: [String]] in
            let sampleCount = min(maxSamplePoints, max(1, totalSegments))
            let indices = samplePathIndices(pathLength: polyline.count, samples: sampleCount)
            // Walkers notice what's on the block; drivers pass a wider corridor.
            let radius = travelMode.uppercased() == "WALKING" ? 400 : 1200

            var poisPerSample = Array(repeating: [NearbyPOI](), count: indices.count)
            await withTaskGroup(of: (Int, [NearbyPOI]).self) { group in
                for (slot, pathIndex) in indices.enumerated() {
                    let coordinate = polyline[pathIndex]
                    group.addTask {
                        let pois = (try? await NearbyPlacesClient.shared.fetchNearbyPOIs(
                            around: coordinate,
                            radius: radius
                        )) ?? []
                        return (slot, pois)
                    }
                }
                for await (slot, pois) in group {
                    poisPerSample[slot] = pois
                }
            }

            return assignPoisToSegments(poisPerSample: poisPerSample, totalSegments: totalSegments)
        }

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            work.cancel()
        }
        let assignment = await work.value
        timeoutTask.cancel()

        if assignment.isEmpty {
            Log.story.info("No route landmarks found; generating without POI grounding")
        }
        return assignment
    }

    /// Pick `samples` roughly evenly spaced indices along a path.
    static func samplePathIndices(pathLength: Int, samples: Int) -> [Int] {
        guard pathLength > 0, samples > 0 else { return [] }
        let count = min(samples, pathLength)
        guard count > 1 else { return [pathLength / 2] }
        return (0..<count).map { i in
            Int((Double(i) / Double(count - 1) * Double(pathLength - 1)).rounded())
        }
    }

    /// Map a 1-based segment index to its nearest sample slot.
    static func sampleIndexForSegment(segmentIndex: Int, totalSegments: Int, samples: Int) -> Int {
        guard samples > 0 else { return 0 }
        let ratio = Double(segmentIndex - 1) / Double(max(1, totalSegments))
        return min(samples - 1, Int(ratio * Double(samples)))
    }

    /// Distribute sampled POIs across segments: each segment draws up to
    /// `poisPerSegment` names from its nearest sample point, best-scored
    /// first, and no landmark is mentioned in more than one segment.
    static func assignPoisToSegments(
        poisPerSample: [[NearbyPOI]],
        totalSegments: Int,
        perSegment: Int = RoutePoiService.poisPerSegment
    ) -> [Int: [String]] {
        guard !poisPerSample.isEmpty else { return [:] }

        let ranked = poisPerSample.map { pois in
            pois.filter { score($0) >= 0 }.sorted { score($0) > score($1) }
        }

        var assignment: [Int: [String]] = [:]
        var used = Set<String>()

        for segment in 1...max(1, totalSegments) {
            let slot = sampleIndexForSegment(
                segmentIndex: segment,
                totalSegments: totalSegments,
                samples: ranked.count
            )
            var names: [String] = []
            for poi in ranked[slot] {
                if names.count >= perSegment { break }
                if used.contains(poi.name) { continue }
                used.insert(poi.name)
                names.append(poi.name)
            }
            if !names.isEmpty {
                assignment[segment] = names
            }
        }
        return assignment
    }

    private static func score(_ poi: NearbyPOI) -> Int {
        if poi.types.contains(where: { boringTypes.contains($0) }) { return -1 }
        let notable = poi.types.contains(where: { notableTypes.contains($0) }) ? 100_000 : 0
        return notable + (poi.userRatingsTotal ?? 0)
    }
}
