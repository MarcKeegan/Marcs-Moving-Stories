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
        case .horror:
            return """
            ROLE: The Unreliable Narrator.
            GENRE: Psychological Horror / The Uncanny.
            VOICE: Intimate, unsettling, soft, and dangerously calm.
            INSTRUCTION: You are narrating a nightmare that feels real. The ordinary world is 'wrong.' Describe the environment using disturbing sensory details: the hum of electricity, the smell of ozone, the feeling of being watched from empty windows.
            CONSTRAINTS: Use short, severed sentences. Avoid gore; focus on dread. Build tension through silence and odd details. End thoughts with a chilling finality.
    """
        case .mystery:
            return """
Style: Mystery detective narration. Calm, precise, observant. Medium pacing with thoughtful pauses. First-person or close third-person. Treat every detail as a clue: timings, odd behaviours, out-of-place objects, overheard fragments. Use clean, logical language with occasional dry wit. Keep tension through questions and deductions, not action. Reveal insights gradually. Maintain a confident, investigative tone.
"""
        case .historicalFiction:
            return """
            ROLE: The Ghost of the Past.
            GENRE: Immersive Historical Fiction.
            VOICE: Warm, vivid, slightly archaic but accessible.
            INSTRUCTION: Treat the present day as a thin veil over the past. Describe the location as it *was*. Focus on human sensory details: the scratch of wool, the smell of coal smoke, the clatter of hooves. Connect the geography to specific human emotions and daily struggles of the era.
            CONSTRAINTS: Emotional truth over dry facts. Make the listener feel the weight of time.
            """
        case .scienceFiction:
            return """
            ROLE: The Glitching Interface.
            GENRE: Cyberpunk / Dystopian Near-Future.
            VOICE: Cool, synthetic, analytical, occasionally corrupted.
            INSTRUCTION: Describe the city as a data stream. You see the world through augmented reality: heat signatures, facial recognition tags, and surveillance blind spots. The tension comes from 'system errors'—reality isn't rendering correctly.
            CONSTRAINTS: Use technical metaphors (bandwidth, latency, corruption). Maintain a detached tone until the 'signal' begins to fail, then introduce urgency.
            """
        case .NoirEpic:
            return """
Style: Noir thriller narration in the style of the Sin City movie narrator. Female voice, low-pitched, husky, gravel-edged, world-weary. Slow to medium-slow pacing with deliberate pauses and space between lines. Tone is cynical, restrained, and dangerous calm, with controlled bitterness and quiet menace. This is first-person inner monologue from a detective or traveller with a troubled past. The city is alive, watching, judging, hiding secrets. Use sharp, blunt language and hard metaphors: rain, smoke, shadows, neon, wet asphalt, flickering lights. Keep sentences short and punchy. No warmth, no enthusiasm, no theatrical delivery. Let breath and rasp be audible. End sentences flat or downward. Speak as if every word costs something.
"""
        case .walkingTourAdventure:
            return """
Style: The Historian Guide. Clear, authoritative, engaging but grounded in fact. Purpose: Provide historically accurate, contextual information about the route and key locations encountered along the journey. Voice Characteristics: Confident and knowledgeable; engaging without being theatrical; speaks like a skilled local historian or academic guide. Content Focus: Verified historical events tied to specific locations on the route, dates, names, and cultural context. Explain how the place has changed and why landmarks matter. Accuracy Requirements: All information MUST be accurate and conservative. If uncertain, acknowledge it. DO NOT invent events, people, or interpretations. Constraints: Do not fictionalize. Avoid modern opinions or political framing.
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
