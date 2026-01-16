/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct RouteDetails: Codable {
    let startAddress: String
    let endAddress: String
    let distance: String
    let duration: String
    let durationSeconds: Int
    let travelMode: String // "WALKING" or "DRIVING"
    let voiceName: String
    let storyStyle: StoryStyle
    let polyline: [Coordinate]
}
