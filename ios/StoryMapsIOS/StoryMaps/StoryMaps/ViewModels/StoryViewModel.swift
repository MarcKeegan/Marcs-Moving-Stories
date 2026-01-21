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
    @Published var bufferingError: String?
    
    private var currentRoute: RouteDetails?
    private var isGenerating = false
    private var failedSegments: Set<Int> = []
    private var retryAttempts: [Int: Int] = [:] // Track retry attempts per segment
    private var lastGenerationTime: Date?
    
    // Configuration
    private let maxRetryAttempts = 3
    private let segmentsToBufferAhead = 2
    private let rateLimitDelay: TimeInterval = 2.0 // 2 seconds between API calls
    
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
        
        lastGenerationTime = Date()
        
        // Step 3: Generate first segment audio
        loadingMessage = "Preparing audio stream...30 seconds"
        
        // Rate limit: wait before next API call
        await applyRateLimit()
        
        let audioData = try await StoryService.shared.generateAudio(for: firstSegment.text, voiceName: route.voiceName)
        firstSegment.audioData = audioData
        
        lastGenerationTime = Date()
        
        // Initialize story
        story = AudioStory(
            totalSegmentsEstimate: totalSegments,
            outline: outline,
            segments: [firstSegment]
        )
    }
    
    func bufferNextSegments() {
        guard let story = story,
              let route = currentRoute else {
            return
        }
        
        // Buffer multiple segments ahead
        for i in 0..<segmentsToBufferAhead {
            let nextIndex = story.segments.count + 1 + i
            
            // Don't generate beyond the estimate
            guard nextIndex <= story.totalSegmentsEstimate else {
                continue
            }
            
            // Skip if already generating or if this segment already exists
            guard !isGenerating else {
                continue
            }
            
            // Check if segment already exists
            if story.segments.count >= nextIndex {
                continue
            }
            
            bufferSegment(index: nextIndex, route: route)
        }
    }
    
    private func bufferSegment(index: Int, route: RouteDetails) {
        Task {
            isGenerating = true
            isBackgroundGenerating = true
            bufferingError = nil
            
            defer {
                Task { @MainActor in
                    self.isGenerating = false
                    self.isBackgroundGenerating = false
                }
            }
            
            // Retry logic
            let maxAttempts = maxRetryAttempts
            var lastError: Error?
            
            for attempt in 1...maxAttempts {
                do {
                    // Rate limit: ensure we don't overwhelm the API
                    await applyRateLimit()
                    
                    guard let currentStory = story else { return }
                    
                    // Get previous context
                    let previousText = currentStory.segments.map { $0.text }.joined(separator: " ")
                    let trimmedContext = String(previousText.suffix(3000))
                    
                    // Get outline beat
                    let outlineBeat = currentStory.outline[index - 1]
                    
                    // Generate text
                    var newSegment = try await StoryService.shared.generateSegment(
                        for: route,
                        segmentIndex: index,
                        totalSegments: currentStory.totalSegmentsEstimate,
                        outlineBeat: outlineBeat,
                        previousContext: trimmedContext
                    )
                    
                    lastGenerationTime = Date()
                    
                    // Rate limit before audio generation
                    await applyRateLimit()
                    
                    // Generate audio
                    let audioData = try await StoryService.shared.generateAudio(for: newSegment.text, voiceName: route.voiceName)
                    newSegment.audioData = audioData
                    
                    lastGenerationTime = Date()
                    
                    // Add to story
                    await MainActor.run {
                        self.story?.segments.append(newSegment)
                        self.failedSegments.remove(index)
                        self.retryAttempts.removeValue(forKey: index)
                    }
                    
                    print("✅ [Buffering] Segment \(index) ready")
                    return // Success!
                    
                } catch {
                    lastError = error
                    let currentAttempt = retryAttempts[index, default: 0] + 1
                    retryAttempts[index] = currentAttempt
                    
                    print("⚠️ [Buffering] Failed to generate segment \(index) (Attempt \(attempt)/\(maxAttempts)): \(error.localizedDescription)")
                    
                    if attempt < maxAttempts {
                        // Exponential backoff: 3s, 6s, 12s
                        let delay = 3.0 * Double(pow(2.0, Double(attempt - 1)))
                        print("⏳ [Buffering] Retrying segment \(index) in \(delay)s...")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }
            
            // All retries failed
            await MainActor.run {
                self.failedSegments.insert(index)
                self.bufferingError = "Failed to generate segment \(index) after \(maxAttempts) attempts"
                print("❌ [Buffering] Segment \(index) failed permanently: \(lastError?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func applyRateLimit() async {
        guard let lastTime = lastGenerationTime else {
            return
        }
        
        let timeSinceLastCall = Date().timeIntervalSince(lastTime)
        if timeSinceLastCall < rateLimitDelay {
            let waitTime = rateLimitDelay - timeSinceLastCall
            print("⏱️ [Rate Limit] Waiting \(String(format: "%.1f", waitTime))s before next API call...")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }
    
    func retryFailedSegments() {
        guard let route = currentRoute else { return }
        
        for segmentIndex in failedSegments {
            bufferSegment(index: segmentIndex, route: route)
        }
    }
    
    func reset() {
        story = nil
        currentRoute = nil
        isGenerating = false
        isBackgroundGenerating = false
        loadingMessage = ""
        bufferingError = nil
        failedSegments.removeAll()
        retryAttempts.removeAll()
        lastGenerationTime = nil
    }
}

