/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class StoryService {
    static let shared = StoryService()
    
    private let targetSegmentDurationSec = 60
    private let wordsPerMinute = 145
    
    private init() {}
    
    var wordsPerSegment: Int {
        (targetSegmentDurationSec / 60) * wordsPerMinute
    }
    
    func calculateTotalSegments(durationSeconds: Int) -> Int {
        max(1, durationSeconds / targetSegmentDurationSec)
    }
    
    // Generate story outline
    func generateOutline(for route: RouteDetails) async throws -> [String] {
        let totalSegments = calculateTotalSegments(durationSeconds: route.durationSeconds)
        let styleInstruction = getStyleInstruction(for: route.storyStyle)
        
        let prompt = """
        You are an expert storyteller. Write an outline for a story that is exactly \(totalSegments) chapters long and has a complete cohesive story arc with a clear set up, inciting incident, rising action, climax, success, falling action, and resolution.
        
        Your outline should be tailored to match this journey:
        
        Journey: \(route.startAddress) to \(route.endAddress) by \(route.travelMode.lowercased()).
        Total Duration: Approx \(route.duration).
        Total Narrative Segments needed: \(totalSegments).
        
        \(styleInstruction)
        
        Output strictly valid JSON: An array of \(totalSegments) strings. Example: ["Chapter 1 summary...", "Chapter 2 summary...", ...]
        """
        
        let responseText = try await GeminiProxyClient.shared.generateText(
            prompt: prompt,
            model: "gemini-2.5-flash",
            responseJSON: true
        )
        
        guard let jsonData = responseText.data(using: .utf8),
              let outline = try? JSONDecoder().decode([String].self, from: jsonData) else {
            throw StoryError.invalidOutlineFormat
        }
        
        // Ensure we have the right number of segments
        var finalOutline = outline
        while finalOutline.count < totalSegments {
            finalOutline.append("Continue the journey towards the destination.")
        }
        
        return Array(finalOutline.prefix(totalSegments))
    }
    
    // Generate a single segment
    func generateSegment(
        for route: RouteDetails,
        segmentIndex: Int,
        totalSegments: Int,
        outlineBeat: String,
        previousContext: String
    ) async throws -> StorySegment {
        let isFirst = segmentIndex == 1
        let styleInstruction = getStyleInstruction(for: route.storyStyle)
        
        var contextPrompt = ""
        if !isFirst {
            let trimmedContext = String(previousContext.suffix(1500))
            contextPrompt = """
            
            PREVIOUS NARRATIVE CONTEXT (The story so far):
            ...\(trimmedContext)
            (CONTINUE SEAMLESSLY from the above. Do not repeat it. Do not start with "And so..." or similar connectors every time.)
            """
        }
        
        let prompt = """
        You are an AI storytelling engine generating a continuous, immersive audio stream for a traveler.
        Journey: \(route.startAddress) to \(route.endAddress) by \(route.travelMode.lowercased()).
        Current Status: Segment \(segmentIndex) of approx \(totalSegments).
        
        \(styleInstruction)
        
        CURRENT CHAPTER GOAL: \(outlineBeat)
        \(contextPrompt)
        
        Task: Write the next ~\(targetSegmentDurationSec) seconds of narration (approx \(wordsPerSegment) words) based on the Current Chapter Goal.
        Keep the narrative moving forward. This is a transient segment of a longer journey.
        
        IMPORTANT: Output ONLY the raw narration text for this segment. Do not include titles, chapter headings, or JSON. Just the text to be spoken.
        """
        
        let text = try await GeminiProxyClient.shared.generateText(
            prompt: prompt,
            model: "gemini-3-flash-preview",
            responseJSON: false
        )
        
        return StorySegment(id: segmentIndex, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // Generate audio for a segment
    func generateAudio(for text: String, voiceName: String = "Kore") async throws -> Data {
        return try await GeminiProxyClient.shared.generateAudio(text: text, voiceName: voiceName)
    }
    
    private func getStyleInstruction(for style: StoryStyle) -> String {
        switch style {
        case .noir:
            return "Style: Noir thriller narration in the style of the Sin City movie narrator. Female voice, low-pitched, husky, gravel-edged, world-weary. Slow to medium-slow pacing with deliberate pauses and space between lines. Tone is cynical, restrained, and dangerous calm, with controlled bitterness and quiet menace. This is first-person inner monologue from a detective or traveller with a troubled past. The city is alive, watching, judging, hiding secrets. Use sharp, blunt language and hard metaphors: rain, smoke, shadows, neon, wet asphalt, flickering lights. Keep sentences short and punchy. No warmth, no enthusiasm, no theatrical delivery. Let breath and rasp be audible. End sentences flat or downward. Speak as if every word costs something."
        case .children:
            return "Style: Children's Story. Whimsical, magical, full of wonder and gentle humor. The world is bright and alive; maybe inanimate objects (like traffic lights or trees) have slight personalities. Simple but evocative language. A sense of delightful discovery."
        case .historical:
            return "Style: Historical Epic. Grandiose, dramatic, and timeless. Treat the journey as a significant pilgrimage or quest in a bygone era (even though it's modern day, overlay it with historical grandeur). Use slightly archaic but understandable language. Focus on endurance, destiny, and the weight of history."
        case .fantasy:
            return "Style: Fantasy Adventure. Heroic, mystical, and epic. The real world is just a veil over a magical realm. Streets are ancient paths, buildings are towers or ruins. The traveler is on a vital quest. Use metaphors of magic, mythical creatures (shadows might be lurking beasts), and destiny."
        case .historianGuide:
            return """
            Style: The Historian Guide. Clear, authoritative, engaging but grounded in fact.
            Purpose: Provide historically accurate, contextual information about the route and key locations encountered along the journey.
            Voice Characteristics: Confident and knowledgeable; engaging without being theatrical; speaks like a skilled local historian or academic guide.
            Content Focus: Verified historical events tied to specific locations on the route, dates, names, and cultural context. Explain how the place has changed and why landmarks matter.
            Accuracy Requirements: All information MUST be accurate and conservative. If uncertain, acknowledge it. DO NOT invent events, people, or interpretations.
            Constraints: Do not fictionalize. Avoid modern opinions or political framing.
            """
        }
    }
}

enum StoryError: LocalizedError {
    case invalidOutlineFormat
    case generationFailed
    case audioGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidOutlineFormat:
            return "Failed to parse story outline"
        case .generationFailed:
            return "Story generation failed"
        case .audioGenerationFailed:
            return "Audio generation failed"
        }
    }
}
