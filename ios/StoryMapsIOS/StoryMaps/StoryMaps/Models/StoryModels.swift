/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct StorySegment: Identifiable, Codable {
    let id: Int
    let text: String
    var audioData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id = "index"
        case text
    }
    
    init(id: Int, text: String, audioData: Data? = nil) {
        self.id = id
        self.text = text
        self.audioData = audioData
    }
}

struct AudioStory {
    var totalSegmentsEstimate: Int
    var outline: [String]
    var segments: [StorySegment]
    
    init(totalSegmentsEstimate: Int, outline: [String], segments: [StorySegment] = []) {
        self.totalSegmentsEstimate = totalSegmentsEstimate
        self.outline = outline
        self.segments = segments
    }
}
