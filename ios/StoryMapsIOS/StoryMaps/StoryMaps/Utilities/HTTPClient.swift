/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import FirebaseAuth

enum HTTPError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
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
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        // Set provided headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add Firebase auth token if user is logged in
        if let user = Auth.auth().currentUser {
            do {
                let idToken = try await user.getIDToken()
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                print("✅ Added auth token to request")
            } catch {
                print("⚠️ Failed to get Firebase ID token: \(error.localizedDescription)")
                // Continue without auth token - let server decide if it's required
            }
        } else {
            print("⚠️ No Firebase user logged in, request will be unauthenticated")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Log the error response for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ HTTP \(httpResponse.statusCode) Error Response:")
                print(errorString)
            }
            throw HTTPError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
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
        
        // Set provided headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add Firebase auth token if user is logged in
        if let user = Auth.auth().currentUser {
            do {
                let idToken = try await user.getIDToken()
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                print("✅ Added auth token to data request")
            } catch {
                print("⚠️ Failed to get Firebase ID token: \(error.localizedDescription)")
            }
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Log the error response for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ HTTP \(httpResponse.statusCode) Data Request Error:")
                print(errorString)
            }
            throw HTTPError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return data
    }
}
