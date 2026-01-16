# StoryMaps iOS (SwiftUI)

This folder contains a native iOS app implementation of StoryMaps built with **SwiftUI**, intended to match the web app’s capabilities:

- Firebase Authentication (Google + Email/Password + Password reset)
- Google Maps iOS SDK + Google Places SDK (autocomplete) + Google Directions API (routing)
- Story generation + TTS via your existing Node server (Gemini proxy at `/api-proxy/**`)

## What’s included in-repo

- SwiftUI app source (see `ios/StoryMapsIOS/`)
- Example secrets file: `ios/StoryMapsIOS/Resources/Secrets.plist.example`
- Example Firebase file placeholder: `ios/StoryMapsIOS/Resources/GoogleService-Info.plist.example`

## Xcode setup (one-time)

1. Create an Xcode iOS App project and point its sources to `ios/StoryMapsIOS/` (or copy this folder into the project).
2. Add Swift Package dependencies in Xcode:
   - Firebase iOS SDK: `FirebaseAuth`, `FirebaseCore`
   - Google Sign-In: `GoogleSignIn`
   - Google Maps iOS SDK: `GoogleMaps`
   - Google Places iOS SDK: `GooglePlaces`
3. Firebase:
   - In Firebase console, add an **iOS app** to project `storymaps-72782`
   - Download `GoogleService-Info.plist` and add it to the Xcode target (Bundle Resources)
4. Google Maps / Places:
   - Enable **Maps SDK for iOS**, **Places API**, **Directions API** in your GCP project
   - Create an API key and restrict it to your iOS bundle id
5. Secrets:
   - Copy `ios/StoryMapsIOS/Resources/Secrets.plist.example` to `Secrets.plist`
   - Add it to the Xcode target (Bundle Resources)

## Runtime configuration

The app reads values from `Secrets.plist`:

- `SERVER_BASE_URL`: your Cloud Run base URL (e.g. `https://your-service-xyz.a.run.app`)
- `GOOGLE_DIRECTIONS_API_KEY`: key for Directions API requests
- `GOOGLE_MAPS_IOS_API_KEY`: key for Google Maps SDK for iOS
- `GOOGLE_PLACES_IOS_API_KEY`: key for Google Places SDK for iOS

## Notes

- The Node server keeps the Gemini API key server-side. The iOS app calls your server’s `/api-proxy/**` endpoints for story generation and TTS.
- If you later want to avoid shipping a Directions API key in the app, we can move Directions requests to the Node server (optional).

