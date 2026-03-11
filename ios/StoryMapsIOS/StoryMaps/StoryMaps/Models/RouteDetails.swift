/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum JourneyMode: String, Codable, CaseIterable {
    case planned = "PLANNED"
    case freeRoam = "FREE_ROAM"

    var displayName: String {
        switch self {
        case .planned:
            return "Planned Route"
        case .freeRoam:
            return "Free Roaming"
        }
    }
}

struct RouteDetails: Codable {
    let id: String
    let startAddress: String
    let endAddress: String
    let distance: String
    let duration: String
    let durationSeconds: Int
    let travelMode: String // "WALKING" or "DRIVING"
    let voiceName: String
    let storyStyle: StoryStyle
    let polyline: [Coordinate]
    let startCoordinate: Coordinate
    let endCoordinate: Coordinate?
    let journeyMode: JourneyMode
    let routeVersion: Int

    var isFreeRoam: Bool {
        journeyMode == .freeRoam
    }
}
