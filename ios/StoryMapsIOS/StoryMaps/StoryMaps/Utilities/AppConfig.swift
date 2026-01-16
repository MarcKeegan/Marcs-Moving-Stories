/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct AppConfig {
    static let shared = AppConfig()
    
    private let secrets: [String: Any]?
    
    private init() {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            self.secrets = dict
        } else {
            print("Warning: Secrets.plist not found. App may not function correctly.")
            self.secrets = nil
        }
    }
    
    var serverBaseURL: String {
        secrets?["SERVER_BASE_URL"] as? String ?? ""
    }
    
    var googleMapsIOSAPIKey: String {
        secrets?["GOOGLE_MAPS_IOS_API_KEY"] as? String ?? ""
    }
    
    var googlePlacesIOSAPIKey: String {
        secrets?["GOOGLE_PLACES_IOS_API_KEY"] as? String ?? ""
    }
    
    var googleDirectionsAPIKey: String {
        secrets?["GOOGLE_DIRECTIONS_API_KEY"] as? String ?? ""
    }
    
    // Static convenience properties for SDK initialization
    static var googleMapsAPIKey: String? {
        let key = shared.googleMapsIOSAPIKey
        return key.isEmpty ? nil : key
    }
    
    static var googlePlacesAPIKey: String? {
        let key = shared.googlePlacesIOSAPIKey
        return key.isEmpty ? nil : key
    }
    
    // Validate all required keys are present
    var isConfigured: Bool {
        !serverBaseURL.isEmpty &&
        !googleMapsIOSAPIKey.isEmpty &&
        !googlePlacesIOSAPIKey.isEmpty
    }
}
