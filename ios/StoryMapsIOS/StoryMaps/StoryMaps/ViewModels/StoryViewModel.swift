/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Combine

@MainActor
class StoryViewModel: ObservableObject {
    @Published var story: AudioStory?
    @Published var loadingMessage = ""
    @Published var isBackgroundGenerating = false
    
    private var currentRoute: RouteDetails?
    private var isGenerating = false
    
    func generateInitialStory(for route: RouteDetails) async throws {
        currentRoute = route
        
        let totalSegments = StoryService.shared.calculateTotalSegments(durationSeconds: route.durationSeconds)
        
        // Step 1: Generate outline
        loadingMessage = "Crafting story arc...1 - 2 minutes"
        let outline = try await StoryService.shared.generateOutline(for: route)
        
        // Step 2: Generate first segment text
        loadingMessage = "Writing first chapter... 1 minute"
        let firstOutlineBeat = outline.first ?? "Begin the journey."
        var firstSegment = try await StoryService.shared.generateSegment(
            for: route,
            segmentIndex: 1,
            totalSegments: totalSegments,
            outlineBeat: firstOutlineBeat,
            previousContext: ""
        )
        
        // Step 3: Generate first segment audio
        loadingMessage = "Preparing audio stream...30 seconds"
        let audioData = try await StoryService.shared.generateAudio(for: firstSegment.text, voiceName: route.voiceName)
        firstSegment.audioData = audioData
        
        // Initialize story
        story = AudioStory(
            totalSegmentsEstimate: totalSegments,
            outline: outline,
            segments: [firstSegment]
        )
    }
    
    func bufferNextSegment() {
        guard let story = story,
              let route = currentRoute,
              !isGenerating else {
            return
        }
        
        let nextIndex = story.segments.count + 1
        
        // Don't generate beyond the estimate
        guard nextIndex <= story.totalSegmentsEstimate else {
            return
        }
        
        Task {
            isGenerating = true
            isBackgroundGenerating = true
            
            defer {
                Task { @MainActor in
                    self.isGenerating = false
                    self.isBackgroundGenerating = false
                }
            }
            
            do {
                // Get previous context
                let previousText = story.segments.map { $0.text }.joined(separator: " ")
                let trimmedContext = String(previousText.suffix(3000))
                
                // Get outline beat
                let outlineBeat = story.outline[nextIndex - 1]
                
                // Generate text
                var newSegment = try await StoryService.shared.generateSegment(
                    for: route,
                    segmentIndex: nextIndex,
                    totalSegments: story.totalSegmentsEstimate,
                    outlineBeat: outlineBeat,
                    previousContext: trimmedContext
                )
                
                // Generate audio
                let audioData = try await StoryService.shared.generateAudio(for: newSegment.text, voiceName: route.voiceName)
                newSegment.audioData = audioData
                
                // Add to story
                await MainActor.run {
                    self.story?.segments.append(newSegment)
                }
                
                print("[Buffering] Segment \(nextIndex) ready")
            } catch {
                print("[Buffering] Failed to generate segment \(nextIndex): \(error)")
            }
        }
    }
    
    func reset() {
        story = nil
        currentRoute = nil
        isGenerating = false
        isBackgroundGenerating = false
        loadingMessage = ""
    }
}

