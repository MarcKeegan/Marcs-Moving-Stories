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
        let url = try endpointURL(model: model)

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

        return try await performGeneration(url: url, jsonData: jsonData, emptyResponseError: .noTextInResponse) { response in
            if let text = response.text {
                return .success(text)
            }
            if let candidate = response.candidates?.first {
                if let text = candidate.content?.parts?.first?.text {
                    return .success(text)
                }
                if let finishReason = candidate.finishReason {
                    // A "STOP" with no content is a transient upstream glitch; retry.
                    if finishReason == "STOP" {
                        return .retryEmptyResponse
                    }
                    throw GeminiError.generationStopped(reason: finishReason)
                }
            }
            throw GeminiError.noTextInResponse
        }
    }

    // Generate audio using TTS model
    func generateAudio(text: String, voiceName: String = "Kore") async throws -> Data {
        let url = try endpointURL(model: "gemini-2.5-flash-preview-tts")

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

        return try await performGeneration(url: url, jsonData: jsonData, emptyResponseError: .noAudioInResponse) { response in
            guard let candidate = response.candidates?.first else {
                throw GeminiError.noAudioInResponse
            }

            if let inlineData = candidate.content?.parts?.first?.inlineData {
                // Extract sample rate from mime type (e.g., "audio/pcm;rate=24000")
                let sampleRate: Int
                if let rateMatch = inlineData.mimeType.range(of: "rate=(\\d+)", options: .regularExpression) {
                    let rateString = String(inlineData.mimeType[rateMatch]).replacingOccurrences(of: "rate=", with: "")
                    sampleRate = Int(rateString) ?? 24000
                } else {
                    sampleRate = 24000
                }

                // Convert base64 PCM to WAV
                guard let wavData = WavEncoder.pcmToWav(base64PCM: inlineData.data, sampleRate: sampleRate) else {
                    throw GeminiError.audioConversionFailed
                }
                return .success(wavData)
            }

            if let finishReason = candidate.finishReason {
                if finishReason == "STOP" {
                    return .retryEmptyResponse
                }
                throw GeminiError.generationStopped(reason: finishReason)
            }

            throw GeminiError.noAudioInResponse
        }
    }

    // MARK: - Shared request/retry machinery

    private enum ParseOutcome<T> {
        case success(T)
        /// The model returned finishReason == "STOP" with no content — a
        /// transient upstream glitch worth retrying.
        case retryEmptyResponse
    }

    private func endpointURL(model: String) throws -> URL {
        guard !baseURL.isEmpty else {
            throw GeminiError.missingServerURL
        }
        guard let url = URL(string: "\(baseURL)/api-proxy/v1beta/models/\(model):generateContent") else {
            throw GeminiError.invalidURL
        }
        return url
    }

    /// Runs a generation request, retrying empty-but-successful responses with
    /// exponential backoff. Transient network/HTTP failures are retried one
    /// level down in `performRequestWithRetry`; anything else fails fast.
    private func performGeneration<T>(
        url: URL,
        jsonData: Data,
        emptyResponseError: GeminiError,
        parse: (GeminiGenerateResponse) throws -> ParseOutcome<T>
    ) async throws -> T {
        let maxAttempts = 5
        for attempt in 1...maxAttempts {
            let response: GeminiGenerateResponse = try await performRequestWithRetry(url: url, jsonData: jsonData)

            switch try parse(response) {
            case .success(let value):
                return value
            case .retryEmptyResponse:
                guard attempt < maxAttempts else {
                    throw emptyResponseError
                }
                // Exponential backoff: 2s, 4s, 8s, 16s
                let delay = pow(2.0, Double(attempt))
                Log.network.warning("Empty STOP response; retrying in \(delay)s (attempt \(attempt)/\(maxAttempts))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw emptyResponseError
    }

    /// True for failures worth retrying: server overload/rate-limit statuses
    /// and flaky-connection URLErrors. Auth failures and client errors are not.
    private func isTransient(_ error: Error) -> Bool {
        if let httpError = error as? HTTPError, let status = httpError.statusCode {
            return status == 503 || status == 500 || status == 429
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false
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
            if isTransient(error) && attempt < maxAttempts {
                // Exponential backoff: 1s, 2s, 4s
                let delay = pow(2.0, Double(attempt - 1))
                Log.network.warning("Transient API failure; retrying in \(delay)s (attempt \(attempt + 1)/\(maxAttempts))")

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
