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
    @Published var selectedStyle: StoryStyle = .noir
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
        guard let start = startPlace, let end = endPlace else {
            throw RouteError.missingLocations
        }
        
        isCalculating = true
        errorMessage = nil
        
        defer { isCalculating = false }
        
        do {
            let route = try await DirectionsClient.shared.getDirections(
                from: start.coordinate,
                to: end.coordinate,
                travelMode: travelMode.rawValue
            )
            
            // Enforce 4-hour limit
            guard route.durationSeconds <= 14400 else {
                throw RouteError.routeTooLong
            }
            
            // Create full route details with style
            let routeDetails = RouteDetails(
                startAddress: start.address,
                endAddress: end.address,
                distance: route.distance,
                duration: route.duration,
                durationSeconds: route.durationSeconds,
                travelMode: travelMode.rawValue,
                voiceName: "Kore",
                storyStyle: selectedStyle,
                polyline: route.polyline
            )
            
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
        selectedStyle = .noir
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
            return "Please select both start and end locations"
        case .routeTooLong:
            return "Sorry, this journey is too long. Please select a route under 4 hours."
        case .calculationFailed:
            return "Could not calculate route. Please try again."
        }
    }
}

