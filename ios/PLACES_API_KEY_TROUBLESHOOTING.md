# Google Places API Key Troubleshooting

## Current Issue
Getting "Autocomplete error: Internal Error" when selecting a place from the autocomplete list.

## Your Current Setup
- **API Key**: `AIzaSyANwdUer4vuMh4xilyROQlYZyProyrZ7VI` (same key for Maps, Places, and Directions)
- **Error**: "Internal Error" suggests API key restrictions or permissions issue

## Most Common Causes

### 1. Bundle ID Restriction Mismatch ⚠️
The API key is restricted to specific iOS bundle IDs, but your app's bundle ID doesn't match.

### 2. Places API Not Enabled
The Places API might not be enabled in Google Cloud Console for this project.

### 3. API Key Restrictions Too Strict
The API key might be restricted in a way that blocks the autocomplete requests.

## Step-by-Step Fix

### Step 1: Find Your Bundle ID

1. **In Xcode:**
   - Open the StoryMaps project
   - Click on "StoryMaps" (blue project icon) in the navigator
   - Select the "StoryMaps" target
   - Go to the "General" tab
   - Look for **Bundle Identifier** (e.g., `com.yourcompany.storymaps`)
   - **Write it down!**

### Step 2: Check Google Cloud Console

1. **Go to**: https://console.cloud.google.com
2. **Select your project**: `storymaps-72782` (or your project)

### Step 3: Verify API is Enabled

1. **APIs & Services** → **Enabled APIs & services**
2. Ensure these are **ENABLED**:
   - ✅ **Places API** (NEW)
   - ✅ **Maps SDK for iOS**
   - ✅ **Directions API**

**If "Places API" is not in the list:**
- Click **+ ENABLE APIS AND SERVICES**
- Search for "Places API"
- Click it and press **ENABLE**

### Step 4: Check API Key Restrictions

1. **APIs & Services** → **Credentials**
2. Find your API key: `AIzaSyANwdUer4vuMh4xilyROQlYZyProyrZ7VI`
3. Click the **Edit** (pencil) icon

#### Check Application Restrictions:
- Should be set to **iOS apps**
- Under "Accept requests from iOS apps with these bundle identifiers":
  - **Add your bundle ID** (from Step 1)
  - Example: `com.yourcompany.storymaps`
  - Click **Done**, then click **Add an item** if you need to add it

#### Check API Restrictions:
Option 1 (Recommended): **Don't restrict key**
- This allows the key to work with all Google APIs

Option 2: **Restrict key** to specific APIs:
- Check these APIs are selected:
  - ✅ Maps SDK for iOS
  - ✅ Places API
  - ✅ Directions API

**SAVE** your changes!

### Step 5: Wait for Propagation
API key changes can take **5-10 minutes** to propagate. After saving:
- Wait 5 minutes
- Rebuild your app
- Test again

## Quick Test: Try Unrestricted Key (Temporary)

To quickly verify if it's a restriction issue:

1. **In Google Cloud Console**, edit your API key
2. **Temporarily** set Application restrictions to **None**
3. **Temporarily** set API restrictions to **Don't restrict key**
4. **Save**
5. Wait 2-3 minutes
6. Rebuild and test your app

**If it works now**: The issue is with your restrictions. Go back and properly configure them.

**If it still fails**: The issue is something else (see below).

## Alternative: Create a New Unrestricted Key

If you want to test quickly:

1. **APIs & Services** → **Credentials**
2. **+ CREATE CREDENTIALS** → **API key**
3. Copy the new key
4. **Don't restrict it yet**
5. Update `Secrets.plist` with the new key
6. Rebuild and test

Once it works, add proper restrictions:
- Application restriction: iOS apps with your bundle ID
- API restriction: Maps SDK for iOS, Places API, Directions API

## Check API Quotas

1. **APIs & Services** → **Enabled APIs & services**
2. Click **Places API**
3. Check **Quotas**
4. Ensure you haven't exceeded free tier limits:
   - Autocomplete requests: 2,500/day free, then $2.83 per 1,000

## Verify API Key in Code

Add this to `StoryMapsIOSApp.swift` init to debug:

```swift
init() {
    FirebaseApp.configure()
    
    // Debug API key
    if let placesKey = AppConfig.googlePlacesAPIKey {
        print("🔑 Places API Key: \(placesKey.prefix(10))...")
        GMSPlacesClient.provideAPIKey(placesKey)
    } else {
        print("❌ Places API Key is NIL!")
    }
}
```

Look for the output in Console when app launches.

## Common Bundle ID Issues

### Wrong Bundle ID in Xcode
Your app bundle ID: `_________________` (fill in from Step 1)

Common mistakes:
- ❌ Using example ID: `com.example.app`
- ❌ Using default: `com.yourcompany.storymaps`
- ✅ Using your actual ID from Apple Developer account

### Multiple Targets
If you have multiple targets (app, widget, extension):
- You may need to add **all** bundle IDs to the API key
- Format: 
  - `com.yourcompany.storymaps` (main app)
  - `com.yourcompany.storymaps.widget` (if you have one)

## Testing Without Autocomplete (Temporary Workaround)

While you're fixing the API key, you can test the app by manually entering coordinates:

1. Modify `PlaceAutocompletePicker` to allow manual text entry
2. Or create test places in code

But this is not a real solution - you need to fix the API key!

## Final Checklist

- [ ] Found bundle ID in Xcode (General tab)
- [ ] Verified **Places API** is enabled in GCP
- [ ] Edited API key in GCP Credentials
- [ ] Set restriction to **iOS apps**
- [ ] Added correct **bundle identifier**
- [ ] Included **Places API** in API restrictions
- [ ] Saved changes and waited 5 minutes
- [ ] Rebuilt app (Clean + Run)
- [ ] Tested autocomplete again

## Expected Behavior After Fix

When you tap on "Destination" and type:
1. ✅ Autocomplete modal opens
2. ✅ Suggestions appear as you type
3. ✅ Can select a suggestion
4. ✅ Field populates with selected location
5. ✅ No "Internal Error" in console

## Still Not Working?

If after all this it still fails:

1. **Check Console output** for the API key debug line
2. **Try a completely new unrestricted API key**
3. **Verify your Google Cloud project has billing enabled** (required for Places API after free tier)
4. **Contact me with**:
   - Your bundle ID
   - Screenshot of API key restrictions
   - Full Console log output

## Status

🔧 **Action Required**: Configure API key restrictions in Google Cloud Console to match your app's bundle ID.
