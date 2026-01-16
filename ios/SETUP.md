# StoryMaps iOS Setup Guide

This guide walks you through setting up the native iOS app from scratch.

## Prerequisites

- **macOS** with Xcode 15.0+ installed
- **Apple Developer Account** (for device testing and App Store submission)
- **CocoaPods** installed: `sudo gem install cocoapods`
- **Node.js** server deployed (your existing Cloud Run instance)

## 1. Open the Xcode Project

1. Navigate to `ios/StoryMapsIOS/StoryMaps/`
2. Open `StoryMaps.xcodeproj` in Xcode

The source files are already in place in the `StoryMaps/` directory:
- `StoryMapsIOSApp.swift` - App entry point
- `Views/` - SwiftUI views
- `ViewModels/` - MVVM view models
- `Models/` - Data models
- `Services/` - API clients
- `Utilities/` - Helper functions
- `Resources/` - Config files and assets

## 2. Add Swift Package Dependencies

In Xcode, go to **File → Add Package Dependencies** and add:

### Firebase iOS SDK
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Products to add:
  - `FirebaseCore`
  - `FirebaseAuth`

### Google Sign-In
- URL: `https://github.com/google/GoogleSignIn-iOS`
- Product: `GoogleSignIn`

## 3. Add Google Maps & Places via CocoaPods

Create a `Podfile` in `ios/StoryMapsIOS/StoryMaps/`:

```ruby
platform :ios, '16.0'
use_frameworks!

target 'StoryMaps' do
  pod 'GoogleMaps'
  pod 'GooglePlaces'
end
```

Then run:
```bash
cd ios/StoryMapsIOS/StoryMaps
pod install
```

**Important:** After running `pod install`, close the `.xcodeproj` and open `StoryMaps.xcworkspace` instead.

## 4. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (e.g., `storymaps-72782`)
3. Click **Add app** → **iOS**
4. Enter your bundle ID (e.g., `com.yourcompany.storymaps`)
5. Download `GoogleService-Info.plist`
6. Drag it into Xcode under `StoryMaps/Resources/` (make sure "Copy items if needed" is checked and target is selected)

### Enable Auth Providers in Firebase Console
- **Email/Password**: Authentication → Sign-in method → Email/Password → Enable
- **Google**: Authentication → Sign-in method → Google → Enable
- **Apple**: Authentication → Sign-in method → Apple → Enable (required for App Store)

## 5. Configure Google Cloud APIs

Go to [Google Cloud Console](https://console.cloud.google.com/):

### Enable APIs
- Maps SDK for iOS
- Places API
- Directions API

### Create API Keys

Create **three separate API keys** with appropriate restrictions:

#### 1. Google Maps iOS Key
- Restrict to **iOS apps**
- Bundle ID: `com.yourcompany.storymaps` (your actual bundle ID)

#### 2. Google Places iOS Key
- Restrict to **iOS apps**
- Bundle ID: `com.yourcompany.storymaps`

#### 3. Directions API Key (Server-Side)
- **Location**: Used by Node.js server, NOT in iOS app
- **Restriction**: None (or IP address if you have static IPs)
- **Why**: The iOS app calls `/api/directions` on your server, which then calls Google's Directions API
- **Security**: API key never exposed to client, requires Firebase auth

## 6. Create Secrets.plist

1. Copy `StoryMaps/Resources/Secrets.plist.example` to `Secrets.plist`
2. Fill in your actual values:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SERVER_BASE_URL</key>
    <string>https://your-actual-server.a.run.app</string>
    <key>GOOGLE_MAPS_IOS_API_KEY</key>
    <string>YOUR_ACTUAL_MAPS_KEY</string>
    <key>GOOGLE_PLACES_IOS_API_KEY</key>
    <string>YOUR_ACTUAL_PLACES_KEY</string>
</dict>
</plist>
```

**Note:** `GOOGLE_DIRECTIONS_API_KEY` is **not needed** in iOS `Secrets.plist` because Directions API calls are proxied through your Node.js server (see `DIRECTIONS_API_PROXY_FIX.md`).

3. Add `Secrets.plist` to Xcode target (drag into Xcode, ensure target is checked)

**Important:** `Secrets.plist` is git-ignored and should never be committed.

## 7. Configure Xcode Project Settings

### General
- **Bundle Identifier**: Set your unique ID (e.g., `com.yourcompany.storymaps`)
- **Team**: Select your Apple Developer team
- **Deployment Target**: iOS 16.0 or higher

### Signing & Capabilities
- Enable **Automatic Signing**
- Add Capability: **Sign in with Apple**
- Add Capability: **Background Modes** → Check "Audio, AirPlay, and Picture in Picture"

### Info Tab (Custom Properties)

Modern Xcode auto-generates Info.plist. Configure these in Xcode's **Info** tab:

#### Required Custom Keys
1. Select **StoryMaps** target → **Info** tab
2. Click **+** under **Custom Target Properties** to add:

**Location Permission:**
- Key: `NSLocationWhenInUseUsageDescription`
- Value: `Your location is used to find your starting point for journey stories.`

**URL Types (for Google Sign-In):**
- Key: `CFBundleURLTypes` (Array)
  - Item 0 (Dictionary):
    - `CFBundleURLSchemes` (Array):
      - Item 0: `com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID`
      
Get `YOUR_REVERSED_CLIENT_ID` from your `GoogleService-Info.plist`.

**Configuration Variables (from Secrets.plist):**
- Key: `SERVER_BASE_URL`, Value: `$(SERVER_BASE_URL)`
- Key: `GOOGLE_MAPS_IOS_API_KEY`, Value: `$(GOOGLE_MAPS_IOS_API_KEY)`
- Key: `GOOGLE_PLACES_IOS_API_KEY`, Value: `$(GOOGLE_PLACES_IOS_API_KEY)`
- Key: `GOOGLE_DIRECTIONS_API_KEY`, Value: `$(GOOGLE_DIRECTIONS_API_KEY)`

**Note:** For detailed Info.plist configuration, see `Resources/Info.plist.reference.md`

## 8. Test on Simulator

1. Select a simulator (iPhone 15 Pro, iOS 17+)
2. Click ▶️ Run (Cmd+R)
3. Test authentication, places autocomplete, route calculation

**Note:** Some features may not work in simulator:
- Google Maps requires device or special simulator config
- "Use Current Location" requires location simulation
- Background audio works best on device

## 9. Test on Device

1. Connect your iPhone via USB
2. In Xcode, select your device
3. Ensure your device is registered in your Apple Developer account
4. Run on device (Cmd+R)

### Troubleshooting Device Testing

**"Untrusted Developer"**
- Settings → General → VPN & Device Management → Trust your developer certificate

**Location Not Working**
- Settings → Privacy & Security → Location Services → StoryMaps → Allow While Using

**Maps Not Loading**
- Double-check API key restrictions match your bundle ID
- Check Console logs in Xcode for API errors

## 10. Server Configuration

### Required: Add Directions API Key to Server

The Directions API is now called **server-side** for better security (see `DIRECTIONS_API_PROXY_FIX.md`).

**Render.com (Production):**
1. Go to your service dashboard
2. Navigate to **Environment** tab
3. Add environment variable:
   ```
   GOOGLE_DIRECTIONS_API_KEY=<your-server-side-directions-key>
   ```
4. Save changes (service will auto-redeploy)

**Local Development (.env):**
```bash
# In /server/.env
GOOGLE_DIRECTIONS_API_KEY=<your-server-side-directions-key>
```

**Important:** This key should have **NO iOS restrictions** (it's called from the server). Set to "None" or add IP restrictions if you have static IPs.

### Security Features

Your Node server (`server/server.js`) has these security improvements:
- ✅ Sanitized logging (no full request bodies in prod)
- ✅ Rate limiting (100 req/15min per IP)
- ✅ HTTPS-only (ATS compliant)
- ✅ Firebase auth required for `/api-proxy` and `/api/directions`
- ✅ API keys never exposed to client

## 11. App Store Preparation

See [TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md) for complete checklist.

### Quick Summary
- [ ] Bundle ID finalized and matches Firebase/Google Cloud configs
- [ ] All API keys restricted and tested
- [ ] App icon and display name set
- [ ] Screenshots prepared (all required sizes)
- [ ] Privacy policy URL ready
- [ ] TestFlight build uploaded and tested
- [ ] App Store listing complete

## Troubleshooting

### "No such module 'FirebaseCore'"
- Ensure Firebase package is added via SPM
- Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)

### "No such module 'GoogleMaps'"
- Ensure you ran `pod install`
- Ensure you're opening `.xcworkspace`, not `.xcodeproj`

### Google Sign-In not working
- Check `GoogleService-Info.plist` is in target
- Check URL scheme is correctly set in Info.plist
- Check Firebase console has iOS app registered

### Server connection fails
- Verify `SERVER_BASE_URL` in `Secrets.plist` is correct and uses HTTPS
- Test the URL in a browser or Postman
- Check Cloud Run logs for errors

### Story generation fails
- Check Node server logs for Gemini API errors
- Verify Gemini API key is set on server
- Check rate limits haven't been exceeded

## Architecture Overview

```
iOS App (SwiftUI)
├── Firebase Auth (Email, Google, Apple)
├── Google Maps SDK (route visualization)
├── Google Places SDK (autocomplete)
├── DirectionsClient (routing via Directions API)
└── Node Server (/api-proxy/*)
    └── Gemini API (story generation + TTS)
```

## Support

For issues specific to:
- **iOS app**: Check Xcode console logs
- **Authentication**: Check Firebase console logs
- **Story generation**: Check Node server logs (Cloud Run)
- **Maps/Places**: Check Google Cloud Console quotas

## Next Steps

After successful testing:
1. Review [QA_CHECKLIST.md](QA_CHECKLIST.md)
2. Upload TestFlight build
3. Submit for App Store review

Congratulations! 🎉 Your StoryMaps iOS app is ready to bring personalized audio stories to travelers.
