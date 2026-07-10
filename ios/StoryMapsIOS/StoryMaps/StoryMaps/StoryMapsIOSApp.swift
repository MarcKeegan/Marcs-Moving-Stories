/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Initialize Firebase
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        Log.app.info("Firebase configured")
        #endif
        
        // Initialize Google Maps SDK
        #if canImport(GoogleMaps)
        if let mapsKey = AppConfig.googleMapsAPIKey {
            GMSServices.provideAPIKey(mapsKey)
            Log.app.info("Google Maps SDK initialized")
        } else {
            Log.app.error("Google Maps API key is missing")
        }
        #endif
        
        // Initialize Google Places SDK
        #if canImport(GooglePlaces)
        if let placesKey = AppConfig.googlePlacesAPIKey {
            GMSPlacesClient.provideAPIKey(placesKey)
            Log.app.info("Google Places SDK initialized")
        } else {
            Log.app.error("Google Places API key is missing")
        }
        #endif
        
        // Initialize Google Mobile Ads SDK
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        Log.app.info("Google Mobile Ads SDK initialized")
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
