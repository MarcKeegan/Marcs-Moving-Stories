/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum AppState: Int {
    case planning = 0
    case calculatingRoute = 1
    case routeConfirmed = 2
    case generatingInitialSegment = 3
    case readyToPlay = 4
    case playing = 5
}
