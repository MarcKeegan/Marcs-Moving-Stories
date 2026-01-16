/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum StoryStyle: String, Codable, CaseIterable, Identifiable {
    case noir = "NOIR"
    case children = "CHILDREN"
    case historical = "HISTORICAL"
    case fantasy = "FANTASY"
    case historianGuide = "HISTORIAN_GUIDE"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .noir: return "Noir Thriller"
        case .children: return "Children's Story"
        case .historical: return "Historical Epic"
        case .fantasy: return "Fantasy Adventure"
        case .historianGuide: return "Historian Guide"
        }
    }
    
    var description: String {
        switch self {
        case .noir: return "Gritty, mysterious, rain-slicked streets."
        case .children: return "Whimsical, magical, and full of wonder."
        case .historical: return "Grand, dramatic, echoing the past."
        case .fantasy: return "An epic quest through a magical realm."
        case .historianGuide: return "Factual, authoritative, and deeply researched."
        }
    }
    
    var iconName: String {
        switch self {
        case .noir: return "cloud.rain.fill"
        case .children: return "sparkles"
        case .historical: return "scroll.fill"
        case .fantasy: return "wand.and.stars"
        case .historianGuide: return "books.vertical.fill"
        }
    }
}
