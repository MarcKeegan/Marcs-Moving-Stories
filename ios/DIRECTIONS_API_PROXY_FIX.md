# Directions API Proxy Fix

## Problem

When attempting to call Google Directions API directly from the iOS app with an API key restricted to the iOS bundle ID, we received:

```
HTTP 401 UNAUTHENTICATED
"Request had invalid authentication credentials. Expected OAuth 2 access token..."
```

This error occurred because:
1. The Directions API was being called directly from iOS with just an API key
2. Google's servers were expecting OAuth2 authentication for iOS-restricted keys
3. The API key restrictions (iOS bundle ID) were correctly configured, but the authentication method was incompatible

## Solution

**Move Directions API calls to the Node.js proxy server** (similar to Gemini API calls).

### Benefits
✅ API keys stay server-side (better security)  
✅ No iOS bundle ID restrictions needed for Directions  
✅ Consistent authentication flow (Firebase tokens)  
✅ Single source of truth for API key management  
✅ Easier to debug and monitor API usage  

### Changes Made

#### 1. Server-Side (`server/server.js`)

Added a new `/api/directions` proxy endpoint:

```javascript
// Google Directions API Key (used server-side to avoid iOS restrictions)
const googleDirectionsApiKey = process.env.GOOGLE_DIRECTIONS_API_KEY;

// Google Directions API proxy endpoint (server-side API key)
app.get('/api/directions', authenticateProxyRequest, async (req, res) => {
    // ... proxy logic to call Google Directions API ...
});
```

This endpoint:
- Requires Firebase authentication (via `Authorization: Bearer <token>`)
- Uses the server-side `GOOGLE_DIRECTIONS_API_KEY` environment variable
- Accepts `origin`, `destination`, and `mode` query parameters
- Returns the full Directions API response

#### 2. iOS Client (`DirectionsClient.swift`)

Updated to call the proxy instead of Google's API directly:

```swift
func getDirections(from start: Coordinate, to end: Coordinate, travelMode: String) async throws -> DirectionsResult {
    // Use server proxy instead of calling Directions API directly
    guard let serverBaseURL = AppConfig.serverBaseURL else {
        throw DirectionsError.missingServerURL
    }
    
    let endpoint = "\(serverBaseURL)/api/directions"
    
    var components = URLComponents(string: endpoint)
    components?.queryItems = [
        URLQueryItem(name: "origin", value: "\(start.latitude),\(start.longitude)"),
        URLQueryItem(name: "destination", value: "\(end.latitude),\(end.longitude)"),
        URLQueryItem(name: "mode", value: travelMode.lowercased())
    ]
    
    // HTTPClient automatically adds Firebase auth token
    let response: DirectionsResponse = try await HTTPClient.shared.request(url: url)
    // ...
}
```

The `HTTPClient` automatically includes the Firebase ID token in the `Authorization` header (see `HTTP_403_AUTH_FIX.md`).

## Testing

### 1. Server Configuration

Ensure your Node.js server has the Directions API key configured:

**Render.com (Production):**
```bash
# In Render.com dashboard, add environment variable:
GOOGLE_DIRECTIONS_API_KEY=<your-api-key>
```

**Local Development:**
```bash
# In /server/.env
GOOGLE_DIRECTIONS_API_KEY=<your-api-key>
```

### 2. API Key Restrictions

For the Directions API key used **server-side**, you can:
- **Option A (Recommended)**: Remove all restrictions (server IP is dynamic)
- **Option B**: Add IP restrictions if you have static server IPs

The key no longer needs iOS bundle ID restrictions since it's called from the server.

### 3. iOS Configuration

**Remove** `GOOGLE_DIRECTIONS_API_KEY` from `Secrets.plist` (no longer needed):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SERVER_BASE_URL</key>
    <string>https://storymode-1024844710120.us-west1.run.app</string>
    <key>GOOGLE_MAPS_IOS_API_KEY</key>
    <string>AIzaSy...</string>
    <key>GOOGLE_PLACES_IOS_API_KEY</key>
    <string>AIzaSy...</string>
    <!-- REMOVED: GOOGLE_DIRECTIONS_API_KEY -->
</dict>
</plist>
```

### 4. Test the Fix

1. **In Xcode**: Clean & Rebuild (`Shift+Cmd+K`, then `Cmd+R`)
2. **Select locations** in the app (start and destination)
3. **Tap "Create your story"**
4. **Expected result**: Route calculation succeeds, story generation begins

**Server logs should show:**
```
✅ Auth token present for proxy request
🗺️  Directions API request: -33.8137,...→151.1713,... (walking)
✅ Directions API success
```

## Rollout Checklist

- [x] Add `GOOGLE_DIRECTIONS_API_KEY` to server environment variables
- [x] Deploy updated `server.js` to production
- [x] Update iOS `DirectionsClient.swift`
- [x] Remove iOS API key restrictions for Directions (no longer needed)
- [x] Test route calculation from iOS app
- [ ] Update `Secrets.plist` to remove `GOOGLE_DIRECTIONS_API_KEY` (optional cleanup)

## Security Notes

### Before (Direct API Calls)
❌ API key embedded in iOS app  
❌ Requires iOS bundle ID restrictions  
❌ OAuth2 authentication issues with restrictions  
❌ Key visible in network requests  

### After (Proxy)
✅ API key stays server-side  
✅ Firebase authentication required  
✅ No iOS bundle ID restrictions needed  
✅ Key never exposed to client  

## Related Documentation

- `HTTP_403_AUTH_FIX.md` - How Firebase tokens are added to requests
- `PLACES_API_KEY_TROUBLESHOOTING.md` - API key restriction issues
- `ARCHITECTURE.md` - Overall system architecture

## Troubleshooting

### Still getting 401 errors?

1. **Check server logs** for authentication errors
2. **Verify** `GOOGLE_DIRECTIONS_API_KEY` is set on the server
3. **Ensure** user is signed in (Firebase token is required)
4. **Test** the endpoint directly:
   ```bash
   # Get Firebase token from Xcode console logs
   curl -H "Authorization: Bearer <firebase-token>" \
     "https://your-server.com/api/directions?origin=37.7749,-122.4194&destination=37.3382,-121.8863&mode=walking"
   ```

### Server returns "Directions API key not configured"?

Add the environment variable to your server:
```bash
# Render.com dashboard or .env file
GOOGLE_DIRECTIONS_API_KEY=<your-key>
```

Then restart the server.

### Directions API returns "REQUEST_DENIED"?

1. Ensure **Directions API is enabled** in Google Cloud Console
2. Wait 2-3 minutes after enabling
3. Check API key has no restrictive API limitations

---

**Status**: ✅ Implemented  
**Date**: January 17, 2026  
**Impact**: Fixes route calculation, improves security
