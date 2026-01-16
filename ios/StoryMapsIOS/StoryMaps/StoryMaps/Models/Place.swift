/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct Place: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let coordinate: Coordinate
    
    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}
