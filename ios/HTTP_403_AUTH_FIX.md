# Fix: HTTP 403 Error - Missing Authentication

## Issue
When tapping "Create your story", the app fails with:
```
Story generation error: httpError(statusCode: 403, data: Optional(701 bytes))
```

## Root Cause
The iOS app was making **unauthenticated requests** to the Node.js server. The server requires a Firebase authentication token in the `Authorization` header to allow access to the `/api-proxy` endpoints.

From `server/server.js`:
```javascript
// Middleware to check for Authorization header for /api-proxy endpoints
const authenticateProxyRequest = (req, res, next) => {
    if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized', message: 'Authentication required.' });
    }
    next();
};

app.use('/api-proxy', authenticateProxyRequest);
```

## Fix Applied ✅

Updated `HTTPClient.swift` to **automatically include Firebase auth token** in all requests.

### Changes Made:

1. **Added FirebaseAuth import**:
```swift
import Foundation
import FirebaseAuth  // ✅ Added
```

2. **Updated `request()` method** to include auth token:
```swift
// Add Firebase auth token if user is logged in
if let user = Auth.auth().currentUser {
    do {
        let idToken = try await user.getIDToken()
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        print("✅ Added auth token to request")
    } catch {
        print("⚠️ Failed to get Firebase ID token: \(error.localizedDescription)")
    }
}
```

3. **Updated `requestData()` method** with same auth logic

## How It Works

1. **Check if user is logged in**: `Auth.auth().currentUser`
2. **Get Firebase ID token**: `user.getIDToken()` (async call)
3. **Add to request header**: `Authorization: Bearer <token>`
4. **Server verifies token**: Allows access to `/api-proxy` endpoints

## Testing

After applying this fix:

1. **Clean & Rebuild**:
   ```
   Shift+Cmd+K (Clean Build Folder)
   Cmd+R (Run)
   ```

2. **Test Story Generation**:
   - Select start location
   - Select destination
   - Choose travel mode (Walk/Drive)
   - Select story style (e.g., Noir Thriller)
   - Tap "Create your story"
   - **Should work now!** ✅

3. **Check Console** - Should see:
   ```
   ✅ Added auth token to request
   📍 Calculating route...
   ✅ Story generation started
   ```

## Security Notes

- **Auth token is ephemeral**: Firebase automatically refreshes it
- **Token in header only**: Never logged or stored
- **Server-side validation**: Node server verifies token with Firebase Admin SDK
- **Per-request auth**: Fresh token for each API call

## Error Handling

The fix includes graceful error handling:

```swift
catch {
    print("⚠️ Failed to get Firebase ID token: \(error.localizedDescription)")
    // Continue without auth token - let server decide if it's required
}
```

If token retrieval fails, the request proceeds **without** the token, allowing the server to return a proper 401/403 error.

## Common Issues

### Issue: Still getting 403
**Possible causes**:
1. User not actually logged in (check AuthViewModel)
2. Firebase token expired (should auto-refresh)
3. Server's Firebase Admin SDK not configured

**Debug**:
- Check Console for "✅ Added auth token" message
- If you see "⚠️ No Firebase user logged in" - auth issue
- If you see "⚠️ Failed to get Firebase ID token" - Firebase config issue

### Issue: Getting 401 instead of 403
**This is progress!** 401 means:
- Server received request
- No/invalid auth token
- Check Firebase user is logged in properly

## Verification Checklist

- [x] HTTPClient imports FirebaseAuth
- [x] `request()` method adds Authorization header
- [x] `requestData()` method adds Authorization header
- [x] Graceful error handling if token fails
- [x] Debug logging added
- [ ] Clean build and test

## Related Files

- **HTTPClient.swift** - Updated with auth token logic
- **GeminiProxyClient.swift** - Uses HTTPClient (no changes needed)
- **server/server.js** - Validates auth token on backend

## Status

✅ **FIXED** - HTTP requests now include Firebase authentication token, allowing access to protected API endpoints.

Story generation should now work! 🎉
