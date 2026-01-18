/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(GoogleMaps)
import GoogleMaps
#endif

#if canImport(GooglePlaces)
import GooglePlaces
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct StoryMapsIOSApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Initialize Firebase
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        print("✅ Firebase configured")
        #endif
        
        // Initialize Google Maps SDK
        #if canImport(GoogleMaps)
        if let mapsKey = AppConfig.googleMapsAPIKey {
            GMSServices.provideAPIKey(mapsKey)
            print("✅ Google Maps SDK initialized with key: \(String(mapsKey.prefix(10)))...")
        } else {
            print("❌ Google Maps API key is missing!")
        }
        #endif
        
        // Initialize Google Places SDK
        #if canImport(GooglePlaces)
        if let placesKey = AppConfig.googlePlacesAPIKey {
            GMSPlacesClient.provideAPIKey(placesKey)
            print("✅ Google Places SDK initialized with key: \(String(placesKey.prefix(10)))...")
            print("📍 If autocomplete fails, check:")
            print("   1. Places API is enabled in Google Cloud Console")
            print("   2. API key is restricted to your iOS bundle ID")
            print("   3. API key has 'Places API' permission")
        } else {
            print("❌ Google Places API key is missing!")
        }
        #endif
        
        // Initialize Google Mobile Ads SDK
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        print("✅ Google Mobile Ads SDK initialized")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
    }
}
