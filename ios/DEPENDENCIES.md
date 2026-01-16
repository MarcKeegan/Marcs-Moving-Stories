# iOS Dependencies

This repo includes SwiftUI source that uses these SDKs when present (imports are guarded with `canImport(...)` so the codebase stays readable even before you add them in Xcode).

## Firebase (Swift Package Manager)

- Add package: `https://github.com/firebase/firebase-ios-sdk`
- Products:
  - `FirebaseCore`
  - `FirebaseAuth`

## Google Sign-In (Swift Package Manager)

- Add package: `https://github.com/google/GoogleSignIn-iOS`
- Product:
  - `GoogleSignIn`

## Google Maps + Places (recommended via CocoaPods)

Google’s Maps/Places iOS SDK setup can vary by distribution method. The most consistently supported path is CocoaPods.

Add to `Podfile`:

```ruby
pod 'GoogleMaps'
pod 'GooglePlaces'
```

Then run:

```bash
pod install
```

If you prefer Swift Package Manager for Maps/Places in your Xcode version, use the official Google documentation for the current package URLs and products.

