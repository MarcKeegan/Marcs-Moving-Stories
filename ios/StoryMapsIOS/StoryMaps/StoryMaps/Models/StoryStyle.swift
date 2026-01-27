/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum StoryStyle: String, Codable, CaseIterable, Identifiable {
    case walkingTourAdventure = "WALKINGTOUR_ADVENTURE"
    case horror = "HORROR"
    case mystery = "MYSTERY"
    case historicalFiction = "HISTORICAL_FICTION"
    case scienceFiction = "SCIENCE_FICTION"
    case NoirEpic = "NOIR_EPIC"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .walkingTourAdventure: return "Walking Tour"
        case .horror: return "Horror Narration"
        case .mystery: return "Mystery Detective"
        case .historicalFiction: return "Historical Fiction"
        case .scienceFiction: return "Science Fiction"
        case .NoirEpic: return "Noir Adventure"
        }
    }
    
    var description: String {
        switch self {
        case .walkingTourAdventure: return "Bright, conversational, and knowledgeable."
        case .horror: return "Intimate, slow, and building dread."
        case .mystery: return "Calm, precise, and observant."
        case .historicalFiction: return "Warm, vivid, and immersive."
        case .scienceFiction: return "Clean, cool, and focused."
        case .NoirEpic: return "Hard-boiled Noir story."
        }
    }
    
    var iconName: String {
        switch self {
        case .walkingTourAdventure: return "signpost.right"
        case .horror: return "moon"
        case .mystery: return "magnifyingglass.circle.fill"
        case .historicalFiction: return "hourglass"
        case .scienceFiction: return "robotic.vacuum.fill"
        case .NoirEpic: return "cloud.drizzle"
        }
    }
}
