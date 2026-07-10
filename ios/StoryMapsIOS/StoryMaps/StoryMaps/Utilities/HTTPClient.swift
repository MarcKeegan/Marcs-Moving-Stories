/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import FirebaseAuth

enum HTTPError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "Please sign in to continue."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            switch statusCode {
            case 401:
                return "Your session has expired. Please sign in again."
            case 429:
                return "Too many requests. Please wait a moment and try again."
            case 503:
                return "The story service is temporarily unavailable. Please try again shortly."
            default:
                return "HTTP error: \(statusCode)"
            }
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }

    /// The HTTP status code, if this error came from an HTTP response.
    var statusCode: Int? {
        if case .httpError(let statusCode, _) = self { return statusCode }
        return nil
    }
}

class HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> T {
        let data = try await requestData(url: url, method: method, headers: headers, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HTTPError.decodingError(error)
        }
    }

    func requestData(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Every server endpoint requires a verified Firebase ID token, so fail
        // closed here instead of sending a request the server will reject.
        guard let user = Auth.auth().currentUser else {
            Log.network.warning("Blocked request without a signed-in user")
            throw HTTPError.notAuthenticated
        }
        do {
            let idToken = try await user.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        } catch {
            Log.network.error("Failed to get Firebase ID token: \(error.localizedDescription)")
            throw HTTPError.notAuthenticated
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            Log.network.error("HTTP \(httpResponse.statusCode) from \(url.path)")
            throw HTTPError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
