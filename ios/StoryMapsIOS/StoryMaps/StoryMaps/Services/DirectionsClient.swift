/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import CoreLocation

struct DirectionsResponse: Codable {
    let routes: [Route]
    let status: String
    
    struct Route: Codable {
        let legs: [Leg]
        let overviewPolyline: OverviewPolyline
        
        enum CodingKeys: String, CodingKey {
            case legs
            case overviewPolyline = "overview_polyline"
        }
    }
    
    struct Leg: Codable {
        let distance: TextValue
        let duration: TextValue
        let startAddress: String
        let endAddress: String
        
        enum CodingKeys: String, CodingKey {
            case distance
            case duration
            case startAddress = "start_address"
            case endAddress = "end_address"
        }
    }
    
    struct TextValue: Codable {
        let text: String
        let value: Int
    }
    
    struct OverviewPolyline: Codable {
        let points: String
    }
}

struct DirectionsResult {
    let distance: String
    let duration: String
    let durationSeconds: Int
    let polyline: [Coordinate]
}

class DirectionsClient {
    static let shared = DirectionsClient()
    
    private init() {}
    
    func getDirections(from start: Coordinate, to end: Coordinate, travelMode: String) async throws -> DirectionsResult {
        // Use server proxy instead of calling Directions API directly
        // This avoids iOS bundle ID restrictions and keeps API keys server-side
        guard let serverBaseURL = AppConfig.serverBaseURL else {
            throw DirectionsError.missingServerURL
        }
        
        let endpoint = "\(serverBaseURL)/api/directions"
        
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "origin", value: "\(start.latitude),\(start.longitude)"),
            URLQueryItem(name: "destination", value: "\(end.latitude),\(end.longitude)"),
            URLQueryItem(name: "mode", value: travelMode.lowercased())
        ]
        
        guard let url = components?.url else {
            throw DirectionsError.invalidURL
        }
        
        print("🗺️  Requesting directions via proxy: \(url.absoluteString)")
        
        // HTTPClient automatically adds Firebase auth token
        let response: DirectionsResponse = try await HTTPClient.shared.request(url: url)
        
        guard response.status == "OK" else {
            throw DirectionsError.apiError(status: response.status)
        }
        
        guard let route = response.routes.first,
              let leg = route.legs.first else {
            throw DirectionsError.noRouteFound
        }
        
        let polyline = decodePolyline(route.overviewPolyline.points)
        
        print("✅ Directions received: \(leg.distance.text), \(leg.duration.text)")
        
        return DirectionsResult(
            distance: leg.distance.text,
            duration: leg.duration.text,
            durationSeconds: leg.duration.value,
            polyline: polyline
        )
    }
    
    // Decode Google's encoded polyline format
    private func decodePolyline(_ encoded: String) -> [Coordinate] {
        var coordinates: [Coordinate] = []
        var index = encoded.startIndex
        var lat = 0
        var lng = 0
        
        while index < encoded.endIndex {
            var result = 0
            var shift = 0
            var byte: Int
            
            repeat {
                byte = Int(encoded[index].asciiValue! - 63)
                index = encoded.index(after: index)
                result |= (byte & 0x1f) << shift
                shift += 5
            } while byte >= 0x20
            
            let deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += deltaLat
            
            result = 0
            shift = 0
            
            repeat {
                byte = Int(encoded[index].asciiValue! - 63)
                index = encoded.index(after: index)
                result |= (byte & 0x1f) << shift
                shift += 5
            } while byte >= 0x20
            
            let deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += deltaLng
            
            coordinates.append(Coordinate(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            ))
        }
        
        return coordinates
    }
}

enum DirectionsError: LocalizedError {
    case missingServerURL
    case invalidURL
    case noRouteFound
    case apiError(status: String)
    
    var errorDescription: String? {
        switch self {
        case .missingServerURL:
            return "Server URL not configured in Secrets.plist"
        case .invalidURL:
            return "Invalid request URL"
        case .noRouteFound:
            return "No route found"
        case .apiError(let status):
            return "Directions API error: \(status)"
        }
    }
}
