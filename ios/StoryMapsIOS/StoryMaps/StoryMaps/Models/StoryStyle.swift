/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum StoryStyle: String, Codable, CaseIterable, Identifiable {
    case horror = "HORROR"
    case mystery = "MYSTERY"
    case historicalFiction = "HISTORICAL_FICTION"
    case scienceFiction = "SCIENCE_FICTION"
    case NoirEpic = "NOIR_EPIC"
    case walkingTourAdventure = "WALKINGTOUR_ADVENTURE"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .horror: return "Horror Narration"
        case .mystery: return "Mystery Detective"
        case .historicalFiction: return "Historical Fiction"
        case .scienceFiction: return "Science Fiction"
        case .NoirEpic: return "Noir Adventure"
        case .walkingTourAdventure: return "Walking Tour"
        }
    }
    
    var description: String {
        switch self {
        case .horror: return "Intimate, slow, and building dread."
        case .mystery: return "Calm, precise, and observant."
        case .historicalFiction: return "Warm, vivid, and immersive."
        case .scienceFiction: return "Clean, cool, and focused."
        case .NoirEpic: return "Hard-boiled Noir story."
        case .walkingTourAdventure: return "Bright, conversational, and knowledgeable."
        }
    }
    
    var iconName: String {
        switch self {
        case .horror: return "eye.trianglebadge.exclamationmark.fill"
        case .mystery: return "magnifyingglass.circle.fill"
        case .historicalFiction: return "hourglass"
        case .scienceFiction: return "cpu"
        case .NoirEpic: return "shield.lefthalf.filled"
        case .walkingTourAdventure: return "face.smiling.fill"
        }
    }
}
