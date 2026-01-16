/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct GeminiGenerateRequest: Codable {
    let contents: String
    let config: GenerateConfig?
    
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
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
            
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
    
    // Generate text using fiercefalcon model
    func generateText(prompt: String, model: String = "fiercefalcon", responseJSON: Bool = false) async throws -> String {
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
        
        let request = GeminiGenerateRequest(contents: prompt, config: config)
        let jsonData = try JSONEncoder().encode(request)
        
        let response: GeminiGenerateResponse = try await HTTPClient.shared.request(
            url: url,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: jsonData
        )
        
        if let text = response.text {
            return text
        } else if let candidate = response.candidates?.first,
                  let part = candidate.content.parts.first,
                  let text = part.text {
            return text
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
        
        let request = GeminiGenerateRequest(contents: text, config: config)
        let jsonData = try JSONEncoder().encode(request)
        
        let response: GeminiGenerateResponse = try await HTTPClient.shared.request(
            url: url,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: jsonData
        )
        
        guard let candidate = response.candidates?.first,
              let part = candidate.content.parts.first,
              let inlineData = part.inlineData else {
            throw GeminiError.noAudioInResponse
        }
        
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
}

enum GeminiError: LocalizedError {
    case missingServerURL
    case invalidURL
    case noTextInResponse
    case noAudioInResponse
    case audioConversionFailed
    
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
        }
    }
}
