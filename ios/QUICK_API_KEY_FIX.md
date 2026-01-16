# Quick Fix: Google Places API Key "Internal Error"

## The Issue
You're getting "Autocomplete error: Internal Error" which is **100% an API key configuration issue** in Google Cloud Console.

## Your Current API Key
```
AIzaSyANwdUer4vuMh4xilyROQlYZyProyrZ7VI
```

## Quick Fix (5 Minutes)

### Step 1: Temporarily Remove All Restrictions (Test Only)

1. Go to: https://console.cloud.google.com/apis/credentials
2. Find your API key: `AIzaSyANwdUer4vuMh4xilyROQlYZyProyrZ7VI`
3. Click the **Edit** (pencil) icon
4. Under **Application restrictions**: Select **"None"**
5. Under **API restrictions**: Select **"Don't restrict key"**
6. Click **SAVE**
7. **Wait 2-3 minutes** for changes to propagate

### Step 2: Test Your App
```bash
# In Xcode:
Shift+Cmd+K (Clean)
Cmd+R (Run)

# Try autocomplete again
```

**If it works now**: Continue to Step 3 to secure your key properly.

**If it still fails**: The issue is something else (see "Still Failing?" below).

### Step 3: Add Proper Restrictions (Secure Your Key)

Once it's working with no restrictions:

1. **Find your bundle ID**:
   - In Xcode: Project → Target → General → Bundle Identifier
   - Example: `com.marckeegan.StoryMaps` or similar
   - **WRITE IT DOWN!**

2. **Go back to API key settings**:
   - Application restrictions: **iOS apps**
   - Click **ADD AN ITEM**
   - Enter your exact bundle ID: `___________________` (fill this in!)
   - Click **Done**

3. **API restrictions**:
   - Select **"Restrict key"**
   - Check these boxes:
     - ✅ **Maps SDK for iOS**
     - ✅ **Places API**
     - ✅ **Directions API**

4. **SAVE** and wait 2 minutes

5. **Test again**

## Most Common Mistakes

### ❌ Wrong Bundle ID
Your bundle ID in Xcode **MUST EXACTLY MATCH** what's in the API key restrictions.

Common errors:
- Xcode: `com.marckeegan.StoryMaps`
- API Key: `com.example.StoryMaps` ← WRONG!

### ❌ Places API Not Enabled
1. Go to: https://console.cloud.google.com/apis/library
2. Search: "Places API"
3. Make sure it says **"API ENABLED"** in green
4. If not, click **ENABLE**

### ❌ Using Wrong Project
Make sure you're in the correct Google Cloud project (should match your Firebase project).

## Still Failing?

### Check 1: Verify API is Enabled
```bash
# Go to Google Cloud Console
# APIs & Services → Dashboard
# Look for "Places API" in the list
# Should say "Enabled"
```

### Check 2: Try Creating a New Key
Sometimes old keys get corrupted:

1. APIs & Services → Credentials
2. **+ CREATE CREDENTIALS** → **API key**
3. Copy the new key
4. Update `Secrets.plist` with new key
5. Test with **no restrictions first**
6. Add restrictions once working

### Check 3: Enable Billing
Places API requires billing to be enabled (even though you get free quota):

1. Go to: https://console.cloud.google.com/billing
2. Make sure a billing account is linked to your project
3. You get $200 free credit per month

### Check 4: Check Quotas
1. APIs & Services → Enabled APIs & services
2. Click **Places API**
3. Click **Quotas**
4. Make sure you haven't exceeded limits

## Test API Key Manually

You can test if your API key works outside the app:

```bash
# Test Places Autocomplete API
curl "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Lane%20Cove&key=AIzaSyANwdUer4vuMh4xilyROQlYZyProyrZ7VI"
```

**If this returns results**: Your API key works, but iOS restrictions are wrong.

**If this returns error**: Your API key is broken or API not enabled.

## Debug: Add More Logging

Add this to `StoryMapsIOSApp.swift` init:

```swift
init() {
    FirebaseApp.configure()
    
    // Test API key is loaded
    let key = AppConfig.shared.googlePlacesIOSAPIKey
    print("🔑 API Key loaded: \(key.isEmpty ? "EMPTY" : "\(key.prefix(20))...")")
    print("🔑 API Key length: \(key.count) characters")
    
    if let placesKey = AppConfig.googlePlacesAPIKey {
        GMSPlacesClient.provideAPIKey(placesKey)
        print("✅ Places SDK initialized")
    } else {
        print("❌ Places API key is NIL or empty!")
    }
}
```

Check Console output when app launches.

## Expected Console Output (When Working)

```
✅ Firebase configured
🔑 API Key loaded: AIzaSyANwdUer4vuMh4x...
🔑 API Key length: 39 characters
✅ Google Maps SDK initialized with key: AIzaSyANwd...
✅ Google Places SDK initialized with key: AIzaSyANwd...
📍 If autocomplete fails, check:
   1. Places API is enabled in Google Cloud Console
   2. API key is restricted to your iOS bundle ID
   3. API key has 'Places API' permission
```

Then when you use autocomplete:
```
✅ Place selected: Lane Cove
   Address: Lane Cove NSW, Australia
   Coordinate: -33.8167, 151.1667
   Created Place: Lane Cove
   ✅ Place binding updated
```

## Nuclear Option: Start Fresh

If nothing works, create a completely new API key:

1. **Create new API key** (no restrictions)
2. **Test it works** (should work immediately)
3. **Add iOS bundle ID restriction**
4. **Add API restriction** (Maps, Places, Directions)
5. **Test again**

## Action Items

**DO THIS NOW:**

- [ ] Go to Google Cloud Console
- [ ] Find your API key
- [ ] Set restrictions to **"None"** and **"Don't restrict key"**
- [ ] Save and wait 2 minutes
- [ ] Clean build and test app
- [ ] If works: Add proper restrictions back
- [ ] If fails: Try creating new API key

## Status

🔧 **Action Required**: Configure API key in Google Cloud Console. The "Internal Error" means Google is rejecting your API requests.

**99% chance this is the bundle ID restriction not matching your Xcode bundle ID.**
