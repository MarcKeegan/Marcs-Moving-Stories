/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import os

/// Unified logging. Unlike `print`, os.Logger redacts non-literal values in
/// release builds by default and can be filtered per category in Console.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.marckeegan.StoryMaps"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let story = Logger(subsystem: subsystem, category: "story")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let location = Logger(subsystem: subsystem, category: "location")
}
