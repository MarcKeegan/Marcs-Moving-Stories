/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import SwiftUI
import Combine

@MainActor
class RoutePlannerViewModel: ObservableObject {
    @Published var startPlace: Place?
    @Published var endPlace: Place?
    @Published var travelMode: TravelMode = .walking
    @Published var selectedStyle: StoryStyle = .walkingTourAdventure
    @Published var journeyMode: JourneyMode = .planned
    @Published var isCalculating = false
    @Published var errorMessage: String?
    @Published var currentRoute: RouteDetails?
    
    enum TravelMode: String, CaseIterable {
        case walking = "WALKING"
        case driving = "DRIVING"
        
        var displayName: String {
            switch self {
            case .walking: return "Walk"
            case .driving: return "Drive"
            }
        }
        
        var iconName: String {
            switch self {
            case .walking: return "figure.walk"
            case .driving: return "car.fill"
            }
        }
    }
    
    func calculateRoute() async throws -> RouteDetails {
        guard let start = startPlace else {
            throw RouteError.missingLocations
        }

        if journeyMode == .planned && endPlace == nil {
            throw RouteError.missingLocations
        }
        
        isCalculating = true
        errorMessage = nil
        
        defer { isCalculating = false }
        
        do {
            let routeDetails: RouteDetails

            if let end = endPlace {
                let route = try await DirectionsClient.shared.getDirections(
                    from: start.coordinate,
                    to: end.coordinate,
                    travelMode: travelMode.rawValue
                )
                
                if journeyMode == .planned && route.durationSeconds > 14400 {
                    throw RouteError.routeTooLong
                }

                routeDetails = RouteDetails(
                    id: UUID().uuidString,
                    startAddress: route.startAddress,
                    endAddress: route.endAddress,
                    distance: route.distance,
                    duration: route.duration,
                    durationSeconds: route.durationSeconds,
                    travelMode: travelMode.rawValue,
                    voiceName: "Kore",
                    storyStyle: selectedStyle,
                    polyline: route.polyline,
                    startCoordinate: start.coordinate,
                    endCoordinate: end.coordinate,
                    journeyMode: journeyMode,
                    routeVersion: 1
                )
            } else {
                routeDetails = RouteDetails(
                    id: UUID().uuidString,
                    startAddress: start.address,
                    endAddress: "Wherever the road leads",
                    distance: "Live",
                    duration: "Adaptive",
                    durationSeconds: 0,
                    travelMode: travelMode.rawValue,
                    voiceName: "Kore",
                    storyStyle: selectedStyle,
                    polyline: [],
                    startCoordinate: start.coordinate,
                    endCoordinate: nil,
                    journeyMode: .freeRoam,
                    routeVersion: 1
                )
            }

            currentRoute = routeDetails
            return routeDetails
            
        } catch {
            if let routeError = error as? RouteError {
                errorMessage = routeError.localizedDescription
            } else {
                errorMessage = "Could not calculate route. Please try again."
            }
            throw error
        }
    }
    
    func reset() {
        startPlace = nil
        endPlace = nil
        travelMode = .walking
        selectedStyle = .walkingTourAdventure
        journeyMode = .planned
        isCalculating = false
        errorMessage = nil
        currentRoute = nil
    }
}

enum RouteError: LocalizedError {
    case missingLocations
    case routeTooLong
    case calculationFailed
    
    var errorDescription: String? {
        switch self {
        case .missingLocations:
            return "Please select a starting point and, for planned routes, a destination"
        case .routeTooLong:
            return "Sorry, this journey is too long. Please select a route under 4 hours."
        case .calculationFailed:
            return "Could not calculate route. Please try again."
        }
    }
}
