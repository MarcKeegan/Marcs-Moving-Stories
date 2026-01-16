# TestFlight checklist (StoryMaps iOS)

## Apple / Xcode

- Bundle ID finalized (matches Firebase iOS app registration)
- Signing team selected, automatic signing working
- App icon + display name set

## Firebase

- `GoogleService-Info.plist` included in target
- Firebase Auth providers enabled in Firebase console:
  - Email/Password
  - Google
- (Optional) Authorized domains updated if needed

## Google Cloud / Maps

- APIs enabled:
  - Maps SDK for iOS
  - Places API
  - Directions API
- API keys restricted:
  - iOS key restricted by bundle id
  - Directions key restricted appropriately

## App config

- `Secrets.plist` included in target
- `SERVER_BASE_URL` points to production Cloud Run base URL

## Smoke test (release build)

- Auth: sign in/out works
- Places autocomplete works
- Directions works and draws polyline
- Story generation + audio works end-to-end

