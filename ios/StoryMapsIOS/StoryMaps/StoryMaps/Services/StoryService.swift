/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class StoryService {
    static let shared = StoryService()
    
    private let targetSegmentDurationSec = 60
    private let wordsPerMinute = 145
    private let continuousStorySegmentEstimate = 9_999
    
    private init() {}
    
    var wordsPerSegment: Int {
        (targetSegmentDurationSec / 60) * wordsPerMinute
    }
    
    func calculateTotalSegments(durationSeconds: Int) -> Int {
        max(1, durationSeconds / targetSegmentDurationSec)
    }

    func defaultTotalSegments(for route: RouteDetails) -> Int {
        if route.isFreeRoam {
            return continuousStorySegmentEstimate
        }

        return calculateTotalSegments(durationSeconds: route.durationSeconds)
    }

    func makeFallbackOutline(for route: RouteDetails, totalSegments: Int) -> [String] {
        let openingBeat: String

        switch route.storyStyle {
        case .mystery:
            openingBeat = "Open with an intriguing observation on the road that suggests something is slightly off and worth investigating."
        case .historicalFiction:
            openingBeat = "Open by layering the present-day route with echoes of the past so the journey feels like stepping through living history."
        case .scienceFiction:
            openingBeat = "Open by reframing the route as a near-future system scan, with the traveller moving through a city of signals, glitches, and hidden patterns."
        case .NoirEpic:
            openingBeat = "Open with a hard-boiled inner monologue that introduces the road, the weather, and the sense that the city is hiding something."
        case .walkingTourAdventure:
            openingBeat = "Open with a grounded historical introduction to the route and why the places ahead matter."
        case .horror:
            openingBeat = "Open with a subtle but unsettling detail that makes the route feel wrong before the tension builds."
        }

        guard totalSegments > 1 else {
            return [openingBeat]
        }

        return [openingBeat] + Array(
            repeating: "Continue the journey forward, deepen the atmosphere, and move the traveler toward a satisfying conclusion.",
            count: totalSegments - 1
        )
    }
    
    // Generate story outline
    func generateOutline(for route: RouteDetails) async throws -> [String] {
        guard !route.isFreeRoam else { return [] }

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
            model: "gemini-2.5-flash",
            responseJSON: false
        )
        
        return StorySegment(id: segmentIndex, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func generateContextualSegment(
        for route: RouteDetails,
        liveContext: LiveJourneyContext,
        narrativeState: NarrativeState,
        segmentIndex: Int,
        previousContext: String
    ) async throws -> (segment: StorySegment, narrativeState: NarrativeState) {
        let styleInstruction = getStyleInstruction(for: route.storyStyle)
        let liveLocation = describeLocation(liveContext.currentLocation)
        let snappedLocation = describeLocation(liveContext.snappedLocation)
        let destinationText = route.endCoordinate == nil ? "No fixed destination. The traveler is roaming freely." : "Destination: \(route.endAddress)."
        let poiLines = liveContext.nearbyPOIs.prefix(6).map { poi in
            let address = poi.address.isEmpty ? "address unknown" : poi.address
            let types = poi.types.prefix(3).joined(separator: ", ")
            return "- \(poi.name) (\(address)) [\(types)]"
        }.joined(separator: "\n")

        let previousNarrative = String(previousContext.suffix(1800))
        let rollingSummary = narrativeState.rollingSummary.isEmpty ? "No previous summary yet." : narrativeState.rollingSummary
        let openThreads = narrativeState.openThreads.isEmpty ? "None" : narrativeState.openThreads.joined(separator: "; ")
        let routeModeDescription = route.isFreeRoam ? "FREE ROAMING" : "PLANNED ROUTE"
        let routeSummary = liveContext.routeSummary

        let prompt = """
        You are an AI storytelling engine generating a continuous, immersive audio experience for a traveler moving through the real world.
        Journey Mode: \(routeModeDescription)
        Travel Mode: \(route.travelMode.lowercased())
        Style Instructions:
        \(styleInstruction)

        LOCATION AND ROUTE CONTEXT
        - Current location: \(liveLocation)
        - Snapped route position: \(snappedLocation)
        - Route version: \(max(route.routeVersion, narrativeState.lastRouteVersion))
        - Off route: \(liveContext.isOffRoute ? "yes" : "no")
        - Distance from route in meters: \(formatMeters(liveContext.distanceFromRouteMeters))
        - Heading degrees: \(formatNumber(liveContext.headingDegrees))
        - Speed m/s: \(formatNumber(liveContext.speedMps))
        - Route summary: \(routeSummary)
        - \(destinationText)

        NEARBY POINTS OF INTEREST
        \(poiLines.isEmpty ? "- None supplied. Narrate conservatively from streetscape and movement only." : poiLines)

        STORY MEMORY
        - Rolling summary: \(rollingSummary)
        - Open threads: \(openThreads)
        - Previously referenced POI ids: \(narrativeState.referencedPOIIDs.joined(separator: ", "))
        - Previous narrative excerpt: \(previousNarrative.isEmpty ? "None" : previousNarrative)

        TASK
        Write the next ~\(targetSegmentDurationSec) seconds of narration (about \(wordsPerSegment) words).
        The narration must feel anchored to the current place and recent movement.
        If the route changed, acknowledge it naturally and continue the same story instead of restarting.
        Only mention POIs from the supplied nearby POI list.
        Do not invent exact facts about a POI beyond the supplied name, address, and obvious category.
        Keep continuity with the story so far, but prioritize the current physical context over any old plan.

        OUTPUT
        Return strict JSON with this schema:
        {
          "narration": "string",
          "rollingSummary": "string",
          "openThreads": ["string"],
          "referencedPOIIDs": ["string"]
        }
        """

        let responseText = try await GeminiProxyClient.shared.generateText(
            prompt: prompt,
            model: "gemini-2.5-flash",
            responseJSON: true
        )

        guard let jsonData = responseText.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(ContextualSegmentEnvelope.self, from: jsonData) else {
            throw StoryError.invalidOutlineFormat
        }

        let referencedNames = liveContext.nearbyPOIs
            .filter { envelope.referencedPOIIDs.contains($0.id) }
            .map(\.name)

        let nextNarrativeState = NarrativeState(
            rollingSummary: envelope.rollingSummary,
            openThreads: envelope.openThreads,
            referencedPOIIDs: Array(Set(narrativeState.referencedPOIIDs + envelope.referencedPOIIDs)),
            lastRouteVersion: route.routeVersion
        )

        let segment = StorySegment(
            id: segmentIndex,
            text: envelope.narration.trimmingCharacters(in: .whitespacesAndNewlines),
            generatedFromRouteVersion: route.routeVersion,
            location: liveContext.currentLocation,
            referencedPOIs: referencedNames
        )

        return (segment, nextNarrativeState)
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

    private func describeLocation(_ coordinate: Coordinate?) -> String {
        guard let coordinate else { return "Unknown" }
        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private func formatNumber(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return String(format: "%.1f", value)
    }

    private func formatMeters(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return String(format: "%.0f", value)
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
