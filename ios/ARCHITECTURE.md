# StoryMaps iOS Architecture

## Overview

StoryMaps iOS is a native SwiftUI application that provides feature parity with the web app, leveraging Firebase Authentication, Google Maps APIs, and your existing Node.js backend for AI story generation.

## Technology Stack

### UI Framework
- **SwiftUI**: Modern declarative UI framework (iOS 16+)
- **MVVM Architecture**: Clean separation of concerns
- **Async/Await**: Modern concurrency for API calls

### Authentication
- **Firebase Auth**: Email/password + Google Sign-In
- **Sign in with Apple**: Required for App Store compliance
- **AuthViewModel**: Centralized auth state management

### Maps & Location
- **Google Maps SDK for iOS**: Interactive map visualization with custom styling
- **Google Places SDK**: Autocomplete search for locations
- **Google Directions API**: Route calculation and polyline generation
- **CoreLocation**: "Use Current Location" feature

### Audio & Media
- **AVAudioPlayer**: Audio playback with background support
- **AVAudioSession**: Background audio configuration
- **MediaPlayer**: Lock screen controls and Now Playing info
- **AudioPlayerViewModel**: Playback state management

### Backend Integration
- **Node.js Proxy Server**: Your existing Cloud Run deployment
- **Gemini API**: Story text generation + TTS via proxy
- **HTTPClient**: Reusable HTTP client with timeout handling

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App (SwiftUI)                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   AuthView   │  │ RouteView    │  │ PlayerView   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐      │
│  │  AuthVM      │  │  RouteVM     │  │  StoryVM     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
├─────────┼──────────────────┼──────────────────┼──────────────┤
│         │                  │                  │              │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐      │
│  │  Firebase    │  │ DirectionsAPI│  │ StoryService │      │
│  │    Auth      │  │  Google Maps │  │   (Proxy)    │      │
│  └──────────────┘  └──────────────┘  └──────┬───────┘      │
│                                              │              │
└──────────────────────────────────────────────┼──────────────┘
                                               │
                                               │ HTTPS
                                               ▼
                                    ┌──────────────────┐
                                    │   Node Server    │
                                    │   (Cloud Run)    │
                                    └────────┬─────────┘
                                             │
                                             │ API Key
                                             ▼
                                    ┌──────────────────┐
                                    │   Gemini API     │
                                    │ (Text + Audio)   │
                                    └──────────────────┘
```

## Project Structure

```
StoryMaps/
├── StoryMapsIOSApp.swift         # App entry point, Firebase config
├── ContentView.swift              # Root view with auth state routing
├── StoryMapsMainView.swift       # Main authenticated view
│
├── Views/
│   ├── AuthView.swift             # Sign in/up with Apple/Google/Email
│   ├── RoutePlannerView.swift    # Journey planning interface
│   ├── PlaceAutocompletePicker.swift  # Location search
│   ├── GoogleMapView.swift       # Map visualization wrapper
│   └── StoryPlayerView.swift     # Audio player + story text stream
│
├── ViewModels/
│   ├── AuthViewModel.swift       # Firebase auth logic
│   ├── RoutePlannerViewModel.swift  # Route calculation state
│   ├── StoryViewModel.swift      # Story generation + buffering
│   └── AudioPlayerViewModel.swift   # Playback control + lock screen
│
├── Models/
│   ├── AppState.swift            # App navigation states
│   ├── AuthUser.swift            # User identity model
│   ├── Place.swift               # Location model
│   ├── RouteDetails.swift        # Route data with polyline
│   ├── StoryStyle.swift          # Story genre enum
│   ├── StoryModels.swift         # Segment + AudioStory models
│   └── Coordinate.swift          # Lat/Lng wrapper
│
├── Services/
│   ├── DirectionsClient.swift   # Google Directions API client
│   ├── GeminiProxyClient.swift  # Gemini API proxy wrapper
│   └── StoryService.swift       # Story generation orchestration
│
├── Utilities/
│   ├── AppConfig.swift           # Secrets.plist loader
│   ├── HTTPClient.swift          # Generic HTTP client
│   └── WavEncoder.swift          # PCM → WAV conversion
│
└── Resources/
    ├── Secrets.plist             # API keys (git-ignored)
    ├── Secrets.plist.example     # Template
    ├── GoogleService-Info.plist  # Firebase config (git-ignored)
    ├── GoogleService-Info.plist.example
    ├── Info.plist                # App permissions
    └── PrivacyInfo.xcprivacy     # Privacy manifest
```

## Data Flow

### 1. Authentication Flow

```
User taps "Continue with Google"
    ↓
AuthViewModel.signInWithGoogle()
    ↓
GIDSignIn presents Google UI
    ↓
User authorizes
    ↓
Exchange Google credential for Firebase token
    ↓
Firebase Auth state listener updates AuthViewModel.currentUser
    ↓
ContentView observes change → shows StoryMapsMainView
```

### 2. Route Planning Flow

```
User searches locations via PlaceAutocompletePicker
    ↓
GMSAutocompleteViewController returns GMSPlace
    ↓
Convert to Place model, store in RoutePlannerViewModel
    ↓
User taps "Create your story"
    ↓
RoutePlannerViewModel.calculateRoute()
    ↓
DirectionsClient calls Google Directions API
    ↓
Parse response, decode polyline, create RouteDetails
    ↓
Validate duration < 4 hours
    ↓
Return RouteDetails to StoryMapsMainView
    ↓
Trigger story generation
```

### 3. Story Generation Flow

```
StoryViewModel.generateInitialStory(route)
    ↓
1. Calculate total segments (~60s each)
    ↓
2. Generate outline (fiercefalcon model, JSON response)
    ↓
3. Generate first segment text (gemini-3-flash-preview)
    ↓
4. Generate first segment audio (gemini-2.5-flash-preview-tts)
    ↓
5. Convert base64 PCM → WAV
    ↓
Create AudioStory with first segment
    ↓
Update StoryViewModel.story
    ↓
StoryMapsMainView → AppState.readyToPlay
    ↓
Show StoryPlayerView
```

### 4. Continuous Buffering Flow

```
AudioPlayerViewModel plays segment N
    ↓
On segment change, StoryPlayerView checks buffer
    ↓
If segments.count < currentIndex + 3:
    ↓
StoryViewModel.bufferNextSegment()
    ↓
Generate text for segment N+1
    ↓
Generate audio for segment N+1
    ↓
Append to story.segments
    ↓
AudioPlayerViewModel.updateSegments() resumes if buffering
```

### 5. Audio Playback Flow

```
User taps Play button
    ↓
AudioPlayerViewModel.play()
    ↓
Create AVAudioPlayer with segment.audioData
    ↓
Setup audio session for spoken audio + background
    ↓
Play audio
    ↓
Update Now Playing info (lock screen)
    ↓
On audio end → AVAudioPlayerDelegate
    ↓
Automatically advance to next segment
```

## Security & Privacy

### API Key Management
- **Client-side keys** stored in `Secrets.plist` (git-ignored)
- **iOS restrictions** on Google Maps/Places keys (bundle ID)
- **Server-side key** for Gemini API (never exposed to client)

### Network Security
- All external requests use **HTTPS** (ATS compliant)
- Server proxy sanitizes logs (no sensitive data in production)
- Rate limiting: 100 requests per 15 minutes per IP

### Privacy Compliance
- **Location**: Only requested when user taps "Use Current Location"
- **PrivacyInfo.xcprivacy**: Declares data collection types
- **Privacy Policy**: Required for App Store submission
- **Sign in with Apple**: Required when offering Google Sign-In

### Data Handling
- **Email**: Used for authentication only, linked to user
- **Location**: Ephemeral, not stored or transmitted except for route calculation
- **Story content**: Generated server-side, not persisted
- **Audio**: Streamed to device, not stored server-side

## Performance Optimizations

### Buffering Strategy
- Maintain **2-3 segments ahead** of playback
- Generate segments **asynchronously** in background
- **Retry logic** for transient network failures

### Audio Streaming
- Convert PCM to WAV **on-device** (no server round-trip)
- Use **AVAudioPlayer** for efficient playback
- **Background audio** mode for continuous playback

### Map Rendering
- Custom **map style** (embedded JSON)
- **Fit bounds** to show entire route
- **Progress marker** updates smoothly based on segment index

## Testing Strategy

### Unit Tests (Future)
- Model serialization/deserialization
- WavEncoder PCM conversion
- Polyline decoding accuracy
- Story segment calculation

### Integration Tests (Future)
- End-to-end auth flow
- Route calculation with mock API
- Story generation with mock backend

### Manual Testing (Current)
- See [QA_CHECKLIST.md](QA_CHECKLIST.md)
- Auth scenarios (email, Google, Apple, reset password)
- Route planning (autocomplete, current location, various travel modes)
- Story generation (all styles, buffering, error handling)
- Audio playback (background, lock screen controls)

## Deployment Architecture

```
┌─────────────────┐
│   App Store     │  ← iOS App (Distribution signed)
└────────┬────────┘
         │
         │ Downloads
         ▼
┌─────────────────┐
│   User Device   │
│   (iPhone/iPad) │
└────────┬────────┘
         │
         │ HTTPS
         ▼
┌─────────────────┐
│  Firebase Auth  │  ← Email/Google/Apple authentication
└─────────────────┘

         │ HTTPS
         ▼
┌─────────────────┐
│  Google Cloud   │  ← Maps/Places/Directions APIs
└─────────────────┘

         │ HTTPS
         ▼
┌─────────────────┐
│  Cloud Run      │  ← Node.js proxy server
│  (Your Server)  │
└────────┬────────┘
         │
         │ API Key
         ▼
┌─────────────────┐
│   Gemini API    │  ← Story generation + TTS
└─────────────────┘
```

## Future Enhancements

### Phase 2 Features
1. **CarPlay Integration**: Hands-free story playback while driving
2. **Offline Mode**: Download stories for areas with poor connectivity
3. **Story History**: Save and replay past journeys
4. **Voice Controls**: Siri integration for playback
5. **Custom Voices**: Additional TTS voice options
6. **Speed Control**: Adjust narration speed (0.75x - 1.5x)

### Phase 3 Features
1. **Real-time Progress**: GPS-based progress marker (opt-in)
2. **Collaborative Journeys**: Share routes with friends
3. **Story Ratings**: User feedback on story quality
4. **Premium Styles**: Additional genre options for subscribers
5. **Landmarks**: Automatically include famous landmarks in stories

### Technical Debt
- Add comprehensive unit test suite
- Implement proper error recovery (exponential backoff)
- Cache generated stories locally (CoreData/Realm)
- Instrument performance metrics (Firebase Performance)
- Add crash reporting (Firebase Crashlytics)

## Dependencies Version Constraints

```
iOS: 16.0+
Xcode: 15.0+
Swift: 5.9+

Firebase iOS SDK: 10.0+
Google Sign-In: 7.0+
Google Maps: 8.0+ (via CocoaPods)
Google Places: 8.0+ (via CocoaPods)
```

## Support & Maintenance

### Monitoring
- **Firebase Console**: Auth success rates, active users
- **Google Cloud Console**: API quota usage, error rates
- **Cloud Run Logs**: Server errors, rate limit hits
- **App Store Connect**: Crash reports, user reviews

### Updating Dependencies
1. Update Firebase/Google packages via Xcode
2. Run `pod update` for Maps/Places
3. Test thoroughly before release
4. Submit new build to TestFlight first

### Handling Breaking Changes
- Firebase Auth: Minimal breaking changes expected
- Google Maps: May require API version migration
- Gemini API: Monitor Google AI release notes

## Resources

- [iOS Setup Guide](SETUP.md)
- [QA Checklist](QA_CHECKLIST.md)
- [TestFlight Checklist](TESTFLIGHT_CHECKLIST.md)
- [App Store Checklist](APP_STORE_CHECKLIST.md)
- [Dependencies](DEPENDENCIES.md)
- [Main Project README](../README.md)

## License

Apache-2.0 (same as web app)
