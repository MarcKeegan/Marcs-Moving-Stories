# Xcode Build Error Fix: "Multiple commands produce Info.plist"

## Problem
Modern Xcode (14+) auto-generates `Info.plist` during build. Having a physical `Info.plist` file in the Resources folder causes this error:

```
Multiple commands produce '/Users/.../Build/Products/Debug-iphoneos/StoryMaps.app/Info.plist'
```

## Solution Applied ✅

1. **Renamed physical Info.plist** → `Info.plist.reference`
2. **Created reference guide** → `Info.plist.reference.md`
3. **Updated SETUP.md** with proper configuration steps

## Next Steps (Do This Now)

### Step 1: Clean Xcode Build
In Xcode:
1. **Product** → **Clean Build Folder** (or press **Shift+Cmd+K**)
2. Close Xcode completely
3. Reopen the project

### Step 2: Verify Project Structure
Your `Resources/` folder should now have:
- ✅ `Secrets.plist` (your actual secrets, git-ignored)
- ✅ `Secrets.plist.example` (template)
- ✅ `GoogleService-Info.plist` (your Firebase config)
- ✅ `GoogleService-Info.plist.example` (template)
- ✅ `PrivacyInfo.xcprivacy` (privacy manifest)
- ✅ `Info.plist.reference` (renamed, for reference only)
- ✅ `Info.plist.reference.md` (configuration guide)
- ❌ ~~`Info.plist`~~ (removed to fix build error)

### Step 3: Configure Info Settings in Xcode

Since we removed the physical file, you need to configure these settings through Xcode's UI:

#### A. Select Target → Info Tab
1. Open Xcode
2. Click on **StoryMaps** project in navigator
3. Select **StoryMaps** target
4. Click the **Info** tab

#### B. Add Required Custom Properties
Click the **+** button to add these keys:

##### Location Permission (Required)
```
Key: NSLocationWhenInUseUsageDescription
Type: String
Value: Your location is used to find your starting point for journey stories.
```

##### URL Types for Google Sign-In (Required)
```
Key: CFBundleURLTypes
Type: Array
  └─ Item 0 (Dictionary)
      └─ CFBundleURLSchemes (Array)
          └─ Item 0 (String): com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID
```
*Get `YOUR_REVERSED_CLIENT_ID` from your `GoogleService-Info.plist`*

##### Configuration Variables (Optional but Recommended)
These pull values from `Secrets.plist`:
```
Key: SERVER_BASE_URL
Value: $(SERVER_BASE_URL)

Key: GOOGLE_MAPS_IOS_API_KEY
Value: $(GOOGLE_MAPS_IOS_API_KEY)

Key: GOOGLE_PLACES_IOS_API_KEY
Value: $(GOOGLE_PLACES_IOS_API_KEY)

Key: GOOGLE_DIRECTIONS_API_KEY
Value: $(GOOGLE_DIRECTIONS_API_KEY)
```

### Step 4: Verify Capabilities

#### Signing & Capabilities Tab
Ensure you have:
- ✅ **Sign in with Apple** capability
- ✅ **Background Modes** capability
  - ✅ Audio, AirPlay, and Picture in Picture (checked)

### Step 5: Build Again
1. Select a simulator (e.g., iPhone 15 Pro)
2. Click **▶️** or press **Cmd+R**
3. Build should succeed! ✅

## If Build Still Fails

### Error: "No such module 'FirebaseCore'"
**Fix:** Ensure Firebase added via Swift Package Manager
1. File → Add Package Dependencies
2. Search for: `https://github.com/firebase/firebase-ios-sdk`
3. Add: `FirebaseAuth`, `FirebaseCore`

### Error: "No such module 'GoogleMaps'"
**Fix:** Ensure CocoaPods installed
```bash
cd ios/StoryMapsIOS/StoryMaps
pod install
# Then open StoryMaps.xcworkspace (not .xcodeproj)
```

### Error: "Missing GoogleService-Info.plist"
**Fix:** Ensure file added to target
1. Drag `GoogleService-Info.plist` into Xcode
2. Check "Copy items if needed"
3. Ensure **StoryMaps** target is checked

### Error: Maps not loading at runtime
**Fix:** Check Console logs for API errors
- Verify API keys in `Secrets.plist`
- Verify API key restrictions match bundle ID
- Ensure Maps SDK for iOS is enabled in GCP

## Alternative: Manual Info.plist (Not Recommended)

If you **really** need a physical Info.plist:

1. Rename `Info.plist.reference` back to `Info.plist`
2. In Xcode target **Build Settings**:
   - Search for "Info.plist File"
   - Set to: `StoryMaps/Resources/Info.plist`
3. Remove from "Copy Bundle Resources" phase

But this is **not recommended** for modern Xcode projects.

## Reference Files

- **Info.plist.reference** - Original content for reference
- **Info.plist.reference.md** - Detailed configuration guide
- **SETUP.md** - Updated with Info tab configuration steps

## Summary

✅ **Fixed:** Removed conflicting physical Info.plist  
✅ **Created:** Reference docs for configuration  
✅ **Updated:** SETUP.md with correct steps  
🎯 **Next:** Clean build → Configure Info tab → Build again  

The error should now be resolved! 🎉
