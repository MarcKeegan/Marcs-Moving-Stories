# ✅ Directions API Fix - Quick Summary

## Problem
HTTP 401 "UNAUTHENTICATED" when tapping "Create your story"

## Root Cause
Google Directions API doesn't work well with iOS bundle ID restrictions when called directly from iOS apps. It expects OAuth2 authentication instead of just an API key.

## Solution
**Moved Directions API calls to the Node.js server** (same pattern as Gemini API calls).

## What Changed

### 1. Server (`server.js`)
- ✅ Added new `/api/directions` endpoint
- ✅ Requires Firebase authentication
- ✅ Uses server-side `GOOGLE_DIRECTIONS_API_KEY`

### 2. iOS (`DirectionsClient.swift`)
- ✅ Now calls `/api/directions` on your server
- ✅ Automatically includes Firebase auth token
- ✅ No longer needs `GOOGLE_DIRECTIONS_API_KEY` in `Secrets.plist`

### 3. Security
- ✅ API key stays server-side
- ✅ No iOS bundle ID restrictions needed
- ✅ Firebase authentication required
- ✅ Key never exposed to client

## 🚀 What You Need to Do

### Step 1: Deploy Server Changes

The server code has been updated. Deploy it:

**If using Render.com:**
```bash
cd /Users/marckeegan/Documents/GitHub/Marcs-Moving-Stories
git add .
git commit -m "Add Directions API proxy endpoint"
git push origin main
```

Render will auto-deploy the changes.

### Step 2: Add Environment Variable

In **Render.com dashboard**:
1. Go to your service
2. Click **Environment** tab
3. Add:
   ```
   GOOGLE_DIRECTIONS_API_KEY=YOUR_API_KEY_HERE
   ```
4. Click **Save Changes**

**Important:** Remove iOS bundle ID restrictions from this key in Google Cloud Console:
- Go to Google Cloud Console → APIs & Services → Credentials
- Find the Directions API key
- Edit → Application restrictions → Set to **"None"**
- Save

### Step 3: Test in Xcode

1. **Clean & Rebuild:**
   ```
   Shift+Cmd+K (Clean)
   Cmd+R (Run)
   ```

2. **Test Route Calculation:**
   - Select start location
   - Select destination
   - Tap "Create your story"
   - ✅ Should now work!

### Step 4: Clean Up (Optional)

Remove the unused `GOOGLE_DIRECTIONS_API_KEY` from `Secrets.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SERVER_BASE_URL</key>
    <string>https://storymode-1024844710120.us-west1.run.app</string>
    <key>GOOGLE_MAPS_IOS_API_KEY</key>
    <string>YOUR_API_KEY_HERE</string>
    <key>GOOGLE_PLACES_IOS_API_KEY</key>
    <string>YOUR_API_KEY_HERE</string>
    <!-- REMOVED: GOOGLE_DIRECTIONS_API_KEY (no longer needed) -->
</dict>
</plist>
```

## Expected Server Logs

When you tap "Create your story", you should see:

```
✅ Auth token present for proxy request
🗺️  Directions API request: -33.8137,...→151.1713,... (walking)
✅ Directions API success
```

## Troubleshooting

### Still getting 401?

**Check server logs:**
- Is `GOOGLE_DIRECTIONS_API_KEY` environment variable set?
- Are you signed in to the app (Firebase auth)?

**Test the endpoint directly:**
```bash
# Get a Firebase token from Xcode console logs, then:
curl -H "Authorization: Bearer <YOUR_FIREBASE_TOKEN>" \
  "https://storymode-1024844710120.us-west1.run.app/api/directions?origin=37.7749,-122.4194&destination=37.3382,-121.8863&mode=walking"
```

### Server returns "Directions API key not configured"?

The `GOOGLE_DIRECTIONS_API_KEY` environment variable isn't set on the server. Add it in Render dashboard.

### API returns "REQUEST_DENIED"?

1. Ensure **Directions API is enabled** in Google Cloud Console
2. Wait 2-3 minutes after enabling
3. Check the API key has no restrictive API limitations

---

## Files Modified

- ✅ `server/server.js` - Added `/api/directions` proxy endpoint
- ✅ `ios/.../DirectionsClient.swift` - Updated to use proxy
- ✅ `ios/DIRECTIONS_API_PROXY_FIX.md` - Full technical documentation
- ✅ `ios/README.md` - Updated documentation list
- ✅ `ios/SETUP.md` - Updated configuration instructions

## Benefits

✅ **Better Security**: API key never exposed to client  
✅ **Simpler Setup**: No iOS bundle ID restrictions needed  
✅ **Consistent Pattern**: Same as Gemini API (all proxied)  
✅ **Firebase Protected**: Requires authentication  
✅ **Easier Debugging**: Server logs show API calls  

---

**Status**: ✅ Ready to deploy  
**Next**: Deploy server changes, add env var, test!
