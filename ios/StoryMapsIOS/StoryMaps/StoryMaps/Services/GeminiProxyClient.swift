/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct GeminiGenerateRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerateConfig?
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct GenerateConfig: Codable {
        let responseMimeType: String?
        let responseModalities: [String]?
        let speechConfig: SpeechConfig?
        
        struct SpeechConfig: Codable {
            let voiceConfig: VoiceConfig
            
            struct VoiceConfig: Codable {
                let prebuiltVoiceConfig: PrebuiltVoiceConfig
                
                struct PrebuiltVoiceConfig: Codable {
                    let voiceName: String
                }
            }
        }
    }
}

struct GeminiGenerateResponse: Codable {
    let text: String?
    let candidates: [Candidate]?
    
    struct Candidate: Codable {
        let content: Content?
        let finishReason: String?
        
        struct Content: Codable {
            let parts: [Part]?
            
            struct Part: Codable {
                let text: String?
                let inlineData: InlineData?
                
                struct InlineData: Codable {
                    let mimeType: String
                    let data: String
                }
            }
        }
    }
}

class GeminiProxyClient {
    static let shared = GeminiProxyClient()
    
    private let baseURL: String
    
    private init() {
        self.baseURL = AppConfig.shared.serverBaseURL
    }
    
    // Generate text using Gemini model
    func generateText(prompt: String, model: String = "gemini-2.5-flash", responseJSON: Bool = false) async throws -> String {
        guard !baseURL.isEmpty else {
            throw GeminiError.missingServerURL
        }
        
        let endpoint = "\(baseURL)/api-proxy/v1beta/models/\(model):generateContent"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var config: GeminiGenerateRequest.GenerateConfig?
        if responseJSON {
            config = GeminiGenerateRequest.GenerateConfig(
                responseMimeType: "application/json",
                responseModalities: nil,
                speechConfig: nil
            )
        }
        
        let content = GeminiGenerateRequest.Content(parts: [
            GeminiGenerateRequest.Part(text: prompt)
        ])
        let request = GeminiGenerateRequest(contents: [content], generationConfig: config)
        let jsonData = try JSONEncoder().encode(request)
        
        
        // Retry loop for empty STOP responses (increased to 5 attempts)
        for attempt in 1...5 {
            do {
                let response: GeminiGenerateResponse = try await performRequestWithRetry(
                    url: url,
                    jsonData: jsonData
                )
                
                if let text = response.text {
                    return text
                } else if let candidate = response.candidates?.first {
                    if let parts = candidate.content?.parts, let part = parts.first, let text = part.text {
                        return text
                    }
                    
                    if let finishReason = candidate.finishReason {
                        if finishReason != "STOP" {
                            print("⚠️ Generation stopped. Reason: \(finishReason)")
                        }
                        
                        // If "STOP" but empty, retry if attempts remain
                        if finishReason == "STOP" && attempt < 5 {
                            // Exponential backoff: 2s, 4s, 8s, 16s
                            let delay = Double(pow(2.0, Double(attempt)))
                            print("⚠️ Received STOP with no content. Retrying in \(delay)s... (Attempt \(attempt))")
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            continue
                        }
                        
                        throw GeminiError.generationStopped(reason: finishReason)
                    }
                }
                
                throw GeminiError.noTextInResponse
            } catch {
                if attempt == 5 { throw error }
                // Let other errors bubble up unless handled (performRequestWithRetry handles network/503)
                throw error
            }
        }
        
        throw GeminiError.noTextInResponse
    }
    
    // Generate audio using TTS model
    func generateAudio(text: String, voiceName: String = "Kore") async throws -> Data {
        guard !baseURL.isEmpty else {
            throw GeminiError.missingServerURL
        }
        
        let model = "gemini-2.5-flash-preview-tts"
        let endpoint = "\(baseURL)/api-proxy/v1beta/models/\(model):generateContent"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        let config = GeminiGenerateRequest.GenerateConfig(
            responseMimeType: nil,
            responseModalities: ["AUDIO"],
            speechConfig: GeminiGenerateRequest.GenerateConfig.SpeechConfig(
                voiceConfig: GeminiGenerateRequest.GenerateConfig.SpeechConfig.VoiceConfig(
                    prebuiltVoiceConfig: GeminiGenerateRequest.GenerateConfig.SpeechConfig.VoiceConfig.PrebuiltVoiceConfig(
                        voiceName: voiceName
                    )
                )
            )
        )
        
        let content = GeminiGenerateRequest.Content(parts: [
            GeminiGenerateRequest.Part(text: text)
        ])
        let request = GeminiGenerateRequest(contents: [content], generationConfig: config)
        let jsonData = try JSONEncoder().encode(request)
        
        
        // Retry loop for empty STOP responses (increased to 5 attempts)
        for attempt in 1...5 {
            do {
                let response: GeminiGenerateResponse = try await performRequestWithRetry(
                    url: url,
                    jsonData: jsonData
                )
                
                guard let candidate = response.candidates?.first else {
                    throw GeminiError.noAudioInResponse
                }

                if let parts = candidate.content?.parts,
                   let part = parts.first,
                   let inlineData = part.inlineData {
                    
                    let mimeType = inlineData.mimeType
                    let base64Audio = inlineData.data
                    
                    // Extract sample rate from mime type (e.g., "audio/pcm;rate=24000")
                    let sampleRate: Int
                    if let rateMatch = mimeType.range(of: "rate=(\\d+)", options: .regularExpression) {
                        let rateString = String(mimeType[rateMatch]).replacingOccurrences(of: "rate=", with: "")
                        sampleRate = Int(rateString) ?? 24000
                    } else {
                        sampleRate = 24000
                    }
                    
                    // Convert base64 PCM to WAV
                    guard let wavData = WavEncoder.pcmToWav(base64PCM: base64Audio, sampleRate: sampleRate) else {
                        throw GeminiError.audioConversionFailed
                    }
                    
                    return wavData
                }
                
                if let finishReason = candidate.finishReason {
                    if finishReason != "STOP" {
                        print("⚠️ Audio generation stopped. Reason: \(finishReason)")
                    }
                    
                    // If "STOP" but empty, retry if attempts remain
                    if finishReason == "STOP" && attempt < 5 {
                         // Exponential backoff: 2s, 4s, 8s, 16s
                         let delay = Double(pow(2.0, Double(attempt)))
                         print("⚠️ Audio received STOP with no content. Retrying in \(delay)s... (Attempt \(attempt))")
                         try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                         continue
                    }
                     
                    throw GeminiError.generationStopped(reason: finishReason)
                }
                
                throw GeminiError.noAudioInResponse
            } catch {
                if attempt == 5 { throw error }
                throw error
            }
        }
        
        throw GeminiError.noAudioInResponse
    }
    
    private func performRequestWithRetry<T: Decodable>(
        url: URL,
        jsonData: Data,
        attempt: Int = 1,
        maxAttempts: Int = 4
    ) async throws -> T {
        do {
            return try await HTTPClient.shared.request(
                url: url,
                method: "POST",
                headers: ["Content-Type": "application/json"],
                body: jsonData
            )
        } catch {
            // Check if error is related to 503 Service Unavailable or "Overloaded"
            // HTTPClient throws HTTPError.httpError(statusCode: Int, data: Data?)
            // localizedDescription for this is "HTTP error: 503"
            
            let isOverloaded = error.localizedDescription.contains("503") || 
                               error.localizedDescription.lowercased().contains("overloaded") ||
                               error.localizedDescription.lowercased().contains("busy")
            
            if isOverloaded && attempt < maxAttempts {
                // Exponential backoff: 1s, 2s, 4s
                let delay = Double(pow(2.0, Double(attempt - 1)))
                print("⚠️ API Overloaded (503). Retrying in \(delay)s (Attempt \(attempt + 1)/\(maxAttempts))...")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                return try await performRequestWithRetry(
                    url: url,
                    jsonData: jsonData,
                    attempt: attempt + 1,
                    maxAttempts: maxAttempts
                )
            }
            throw error
        }
    }
}

enum GeminiError: LocalizedError {
    case missingServerURL
    case invalidURL
    case noTextInResponse
    case noAudioInResponse
    case audioConversionFailed
    case generationStopped(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .missingServerURL:
            return "Server URL not configured"
        case .invalidURL:
            return "Invalid server URL"
        case .noTextInResponse:
            return "No text in Gemini response"
        case .noAudioInResponse:
            return "No audio in Gemini response"
        case .audioConversionFailed:
            return "Failed to convert audio data"
        case .generationStopped(let reason):
            return "Generation stopped: \(reason)"
        }
    }
}
