# StoryMaps iOS (SwiftUI)

A native iOS app implementation of StoryMaps built with **SwiftUI**, providing full feature parity with the web app.

## ✅ Implementation Status: COMPLETE

All features are implemented and ready for deployment:

- ✅ Firebase Authentication (Email/Password + Google + **Sign in with Apple**)
- ✅ Google Maps iOS SDK with custom styling
- ✅ Google Places SDK (autocomplete + "Use Current Location")
- ✅ Google Directions API (route calculation with polylines via Node proxy)
- ✅ AI Story generation via Node backend (Gemini proxy)
- ✅ TTS audio with background playback and lock screen controls
- ✅ Continuous buffering (2-3 segments ahead of playback)
- ✅ All 5 story styles: Noir, Children's, Historical, Fantasy, Historian Guide
- ✅ Privacy manifest and App Store compliance
- ✅ Security hardening (sanitized logs, rate limiting, HTTPS-only)

## 📁 What's Included

### Source Code (27 Swift files)
```
StoryMapsIOS/StoryMaps/StoryMaps/
├── StoryMapsIOSApp.swift          # App entry point
├── ContentView.swift               # Root view
├── StoryMapsMainView.swift        # Main authenticated view
├── Views/                          # 5 SwiftUI views
├── ViewModels/                     # 4 MVVM view models
├── Models/                         # 7 data models
├── Services/                       # 3 API clients
├── Utilities/                      # 3 helper classes
└── Resources/                      # Config files
```

### Configuration Files
- `Secrets.plist.example` - Template for API keys
- `GoogleService-Info.plist.example` - Firebase config template
- `Info.plist` - App permissions (location, background audio)
- `PrivacyInfo.xcprivacy` - Privacy manifest for App Store
- `.gitignore` - Protects actual secrets from being committed

### Documentation (13 guides)

**Setup & Architecture:**
- **[SETUP.md](SETUP.md)** - Complete setup instructions (START HERE)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture and data flow
- **[DEPENDENCIES.md](DEPENDENCIES.md)** - SDK installation details
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Project overview

**Testing & Deployment:**
- **[QA_CHECKLIST.md](QA_CHECKLIST.md)** - Quality assurance testing
- **[TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md)** - Beta deployment
- **[APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md)** - Submission requirements

**Troubleshooting Guides:**
- **[XCODE_BUILD_FIX.md](XCODE_BUILD_FIX.md)** - Xcode build errors
- **[UI_COLOR_FIX.md](UI_COLOR_FIX.md)** - Dark mode UI issues
- **[GOOGLE_PLACES_CRASH_FIX.md](GOOGLE_PLACES_CRASH_FIX.md)** - Places SDK initialization
- **[PLACES_SELECTION_FIX.md](PLACES_SELECTION_FIX.md)** - Autocomplete selection issues
- **[HTTP_403_AUTH_FIX.md](HTTP_403_AUTH_FIX.md)** - Firebase authentication
- **[DIRECTIONS_API_PROXY_FIX.md](DIRECTIONS_API_PROXY_FIX.md)** - Directions API proxy setup

## 🚀 Quick Start

### 1. Prerequisites
- macOS with Xcode 15.0+
- Apple Developer Account
- CocoaPods installed: `sudo gem install cocoapods`
- Your Node.js backend deployed

### 2. Open Project
```bash
cd ios/StoryMapsIOS/StoryMaps
open StoryMaps.xcodeproj
```

### 3. Install Dependencies

**Swift Package Manager** (in Xcode):
- File → Add Package Dependencies
- Add Firebase iOS SDK (`FirebaseCore`, `FirebaseAuth`)
- Add Google Sign-In (`GoogleSignIn`)

**CocoaPods** (in terminal):
```bash
cd ios/StoryMapsIOS/StoryMaps
# Create Podfile with GoogleMaps and GooglePlaces
pod install
# Then open StoryMaps.xcworkspace (not .xcodeproj)
```

### 4. Configure Secrets
```bash
cd StoryMaps/Resources
cp Secrets.plist.example Secrets.plist
# Edit Secrets.plist with your actual keys
```

### 5. Add Firebase Config
1. Go to Firebase Console
2. Add iOS app to your project
3. Download `GoogleService-Info.plist`
4. Drag into Xcode under `Resources/`

### 6. Run
- Select simulator or device
- Click ▶️ Run (Cmd+R)

**For complete step-by-step instructions, see [SETUP.md](SETUP.md)**

## 🔑 Required Configuration

### API Keys (in Secrets.plist)
- `SERVER_BASE_URL` - Your Cloud Run URL
- `GOOGLE_MAPS_IOS_API_KEY` - Restricted to iOS bundle ID
- `GOOGLE_PLACES_IOS_API_KEY` - Restricted to iOS bundle ID
- `GOOGLE_DIRECTIONS_API_KEY` - For route calculation

### Firebase Console
- Enable Email/Password authentication
- Enable Google Sign-In
- Enable Apple Sign-In (required for App Store)
- Add iOS app with your bundle ID

### Xcode Capabilities
- Sign in with Apple (REQUIRED for App Store)
- Background Modes → Audio

## 📱 App Store Readiness

The app includes all requirements for App Store submission:

✅ **Sign in with Apple** - Required when offering Google Sign-In  
✅ **Privacy Manifest** - Declares data collection  
✅ **Location Permissions** - Only requested when needed  
✅ **Background Audio** - Properly configured  
✅ **Security** - API keys protected, HTTPS-only  
✅ **Documentation** - Complete submission checklist  

**Next Steps**: Follow [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md)

## 🏗️ Architecture

```
iOS App (SwiftUI + MVVM)
    ↓
Firebase Auth (Email, Google, Apple)
    ↓
Google Maps/Places/Directions
    ↓
Your Node Server (/api-proxy)
    ↓
Gemini API (Story + TTS)
```

## 🎯 Key Features

### Authentication
- Email/password signup and login
- Google Sign-In integration
- Sign in with Apple (App Store requirement)
- Password reset via email

### Journey Planning
- Places autocomplete search
- "Use Current Location" feature
- Walking and driving modes
- 5 story style options
- 4-hour journey limit

### Story Generation
- AI-powered outline creation
- Streaming segment generation
- High-quality TTS audio
- Continuous buffering (2-3 segments ahead)
- Automatic segment advancement

### Audio Playback
- Background audio support
- Lock screen controls
- Now Playing info display
- Smooth segment transitions

### Maps
- Interactive Google Maps
- Custom map styling
- Route polylines
- Progress marker that moves along route

## 🔒 Security & Privacy

- API keys stored in git-ignored `Secrets.plist`
- Google Cloud keys restricted by iOS bundle ID
- Gemini API key kept server-side only
- HTTPS-only network requests (ATS compliant)
- Rate limiting: 100 requests per 15 minutes
- Sanitized server logs (no sensitive data in production)
- Privacy manifest included
- Location only requested when user taps "Use Current Location"

## 🧪 Testing

**Simulator Testing**:
```bash
# Select any iOS simulator (iPhone 15 Pro recommended)
# Run in Xcode (Cmd+R)
```

**Device Testing**:
1. Connect iPhone via USB
2. Trust developer certificate on device
3. Run in Xcode (Cmd+R)

**What to Test**:
- [ ] All auth methods (Email, Google, Apple)
- [ ] Places search and autocomplete
- [ ] Route calculation
- [ ] Story generation end-to-end
- [ ] Audio playback with background/lock screen
- [ ] Error handling (no network, location denied, etc.)

See [QA_CHECKLIST.md](QA_CHECKLIST.md) for complete test plan.

## 📊 Project Stats

- **27 Swift source files** (~3,500 lines of code)
- **iOS 16.0+** deployment target
- **SwiftUI** 100% (modern, declarative UI)
- **MVVM architecture** (clean, maintainable)
- **100% feature parity** with web app
- **App Store compliant** (all requirements met)

## 🆘 Troubleshooting

**"No such module 'FirebaseCore'"**
- Ensure Firebase package added via Swift Package Manager
- Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)

**"No such module 'GoogleMaps'"**
- Ensure you ran `pod install`
- Open `.xcworkspace`, not `.xcodeproj`

**Maps not loading**
- Check API key restrictions match bundle ID
- Check Console logs for API errors

**Story generation fails**
- Verify `SERVER_BASE_URL` is correct and uses HTTPS
- Check Node server logs for Gemini API errors

See [SETUP.md](SETUP.md) for more troubleshooting tips.

## 🎓 Learn More

- **[SETUP.md](SETUP.md)** - Detailed setup walkthrough
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical deep dive
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Project overview

## 📝 License

Apache-2.0 (same as web app)

## 🎉 Ready to Launch

The iOS app is **production-ready** with all features implemented. Estimated time from setup to App Store: **1-2 weeks**.

**Start here**: [SETUP.md](SETUP.md)

