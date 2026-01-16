# Fix: Google Places SDK Crash on Autocomplete

## Error
```
*** Terminating app due to uncaught exception 'GMSPlacesException',
reason: 'Google Places SDK for iOS must be initialized via
[GMSPlacesClient provideAPIKey:...] prior to use'
```

## Problem
The Google Places SDK and Google Maps SDK were not being initialized when the app starts, causing crashes when trying to use Places autocomplete functionality.

## Root Cause
The SDKs require initialization with an API key **before** any UI that uses them is displayed. This was missing from `StoryMapsIOSApp.swift`.

## Fix Applied ✅

### 1. Updated `StoryMapsIOSApp.swift`
Added SDK initialization in the app's `init()` method:

```swift
import GoogleMaps
import GooglePlaces

@main
struct StoryMapsIOSApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize Google Maps SDK ✅
        if let mapsKey = AppConfig.googleMapsAPIKey {
            GMSServices.provideAPIKey(mapsKey)
        }
        
        // Initialize Google Places SDK ✅
        if let placesKey = AppConfig.googlePlacesAPIKey {
            GMSPlacesClient.provideAPIKey(placesKey)
        }
    }
    
    // ... rest of app
}
```

### 2. Updated `AppConfig.swift`
Added static convenience properties for SDK initialization:

```swift
struct AppConfig {
    // ... existing code ...
    
    // Static convenience properties for SDK initialization
    static var googleMapsAPIKey: String? {
        let key = shared.googleMapsIOSAPIKey
        return key.isEmpty ? nil : key
    }
    
    static var googlePlacesAPIKey: String? {
        let key = shared.googlePlacesIOSAPIKey
        return key.isEmpty ? nil : key
    }
}
```

## Verification Steps

1. **Ensure `Secrets.plist` exists** with your actual API keys:
   ```xml
   <key>GOOGLE_MAPS_IOS_API_KEY</key>
   <string>AIza...</string>
   <key>GOOGLE_PLACES_IOS_API_KEY</key>
   <string>AIza...</string>
   ```

2. **Clean and rebuild**:
   - Press **Shift+Cmd+K** (Clean Build Folder)
   - Press **Cmd+R** (Run)

3. **Test autocomplete**:
   - Tap on "Starting Point" or "Destination" field
   - Should open Google Places autocomplete without crashing ✅

## API Key Requirements

### Google Maps iOS API Key
- **Required for**: Map display
- **Restrictions**: iOS apps with your bundle ID
- **Enable in GCP**: Maps SDK for iOS

### Google Places iOS API Key
- **Required for**: Places autocomplete, place details
- **Restrictions**: iOS apps with your bundle ID
- **Enable in GCP**: Places API

**Note**: You can use the same API key for both if you prefer, but separate keys allow better usage tracking and quota management.

## Common Issues

### Issue: "API key is missing"
**Solution**: Check that `Secrets.plist` exists in your Xcode project and is added to the target (Bundle Resources).

### Issue: "API key not valid for this app"
**Solution**: In Google Cloud Console:
1. Go to APIs & Credentials
2. Edit your API key
3. Under "Application restrictions", select "iOS apps"
4. Add your bundle identifier (e.g., `com.yourcompany.storymaps`)

### Issue: Still crashing after fix
**Solution**:
1. Verify imports at top of `StoryMapsIOSApp.swift`:
   ```swift
   import GoogleMaps
   import GooglePlaces
   ```
2. Check Console for initialization logs
3. Ensure CocoaPods or SPM dependencies are properly installed

## SDK Initialization Order

The correct initialization order is:
1. ✅ **Firebase** - First (for authentication)
2. ✅ **Google Maps** - Second (for map display)
3. ✅ **Google Places** - Third (for autocomplete)

All must happen in `init()` before any views are rendered.

## Testing Checklist

After applying the fix:
- [ ] App launches without crashing
- [ ] Tap "Starting Point" field - autocomplete opens
- [ ] Type a location - suggestions appear
- [ ] Select a location - populates field
- [ ] Tap "Destination" field - autocomplete opens
- [ ] No crashes in Console logs

## Status

✅ **FIXED** - Google Places and Maps SDKs now properly initialized at app launch.
