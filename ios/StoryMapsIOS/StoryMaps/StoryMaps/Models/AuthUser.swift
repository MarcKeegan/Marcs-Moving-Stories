/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct AuthUser: Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let photoURL: URL?
}
