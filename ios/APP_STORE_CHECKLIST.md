# App Store Submission Checklist

Complete this checklist before submitting to the App Store.

## Pre-Submission Requirements

### 1. Apple Developer Account Setup
- [ ] Enrolled in Apple Developer Program ($99/year)
- [ ] Team role is Admin or Account Holder
- [ ] Certificates and provisioning profiles configured
- [ ] App Store Connect access confirmed

### 2. App Configuration

#### Bundle & Version
- [ ] Unique bundle identifier set (e.g., `com.yourcompany.storymaps`)
- [ ] Version number follows semantic versioning (e.g., `1.0.0`)
- [ ] Build number incremented for each upload (e.g., `1`, `2`, `3`)
- [ ] Display name set to "StoryMaps" or your chosen name

#### Signing
- [ ] Signing certificate valid and not expired
- [ ] Provisioning profile is Distribution (not Development)
- [ ] Automatic signing enabled OR manual profiles correctly configured
- [ ] All capabilities match between Xcode and App Store Connect

#### Capabilities
- [ ] Sign in with Apple enabled (REQUIRED when offering Google)
- [ ] Background Modes → Audio enabled (for background playback)
- [ ] Push Notifications (if adding in future)

### 3. Firebase & Backend

#### Firebase Console
- [ ] iOS app registered with production bundle ID
- [ ] `GoogleService-Info.plist` from production Firebase project
- [ ] Email/Password authentication enabled
- [ ] Google Sign-In enabled and configured
- [ ] Apple Sign-In enabled
- [ ] OAuth redirect URIs configured for production

#### Node Server
- [ ] Deployed to Cloud Run (or equivalent)
- [ ] HTTPS enabled (ATS requirement)
- [ ] Rate limiting configured (100 req/15min)
- [ ] Logging sanitized (no sensitive data)
- [ ] Gemini API key environment variable set
- [ ] Server responding to health checks

### 4. Google Cloud Configuration

#### API Keys
- [ ] Maps SDK for iOS enabled
- [ ] Places API enabled
- [ ] Directions API enabled
- [ ] All keys have iOS bundle ID restrictions
- [ ] Keys tested and working in production
- [ ] Billing enabled with alerts configured

#### API Restrictions
- [ ] Maps iOS key: Restricted to iOS bundle ID
- [ ] Places iOS key: Restricted to iOS bundle ID
- [ ] Directions key: Restricted appropriately (iOS or server-side)

### 5. App Assets

#### App Icon
- [ ] All required icon sizes provided (App Store, 1024x1024 required)
- [ ] Icon meets Apple guidelines (no transparency, no rounded corners in source)
- [ ] Icon uploaded in App Store Connect

#### Screenshots
Required for iPhone (at least one device size):
- [ ] 6.7" Display (iPhone 14 Pro Max, 15 Pro Max): 1290 x 2796 pixels
- [ ] 6.5" Display (iPhone 11 Pro Max, XS Max): 1242 x 2688 pixels
- [ ] 5.5" Display (iPhone 8 Plus, 7 Plus): 1242 x 2208 pixels

Optional but recommended:
- [ ] iPad screenshots (if supporting iPad)

Screenshots should show:
- [ ] Auth screen (with Sign in with Apple button visible)
- [ ] Route planning interface
- [ ] Map with route
- [ ] Story player with text
- [ ] Story style selection

#### App Preview Video (Optional but recommended)
- [ ] 15-30 second video demo
- [ ] Landscape orientation
- [ ] Shows key features: auth, planning, story playback

### 6. Privacy & Compliance

#### Privacy Policy
- [ ] Privacy policy URL created and hosted
- [ ] Policy covers: Email, location, authentication
- [ ] Policy states data is NOT sold or shared with third parties
- [ ] Policy explains Firebase, Google Maps, Gemini usage

#### App Privacy Details (App Store Connect)
- [ ] Data collection declared:
  - [ ] Email Address (for authentication)
  - [ ] Precise Location (for "Use Current Location" feature)
- [ ] Data usage explained (App Functionality)
- [ ] Data linked to user identity: Email (Yes)
- [ ] Data used for tracking: None
- [ ] Third-party SDKs disclosed: Firebase, Google Maps, Google Places

#### Privacy Manifest (`PrivacyInfo.xcprivacy`)
- [ ] File included in Xcode project
- [ ] Lists all data collection types
- [ ] Declares API usage (UserDefaults, etc.)

### 7. App Store Listing

#### Metadata
- [ ] App Name: "StoryMaps" (or your chosen name)
- [ ] Subtitle: "Audio Stories for Your Journey" (max 30 chars)
- [ ] Promotional Text: Compelling 1-2 sentence pitch
- [ ] Description: Full feature list and benefits (max 4000 chars)
- [ ] Keywords: Comma-separated (e.g., "story,audio,travel,navigation,journey")
- [ ] Support URL: Link to support page or email
- [ ] Marketing URL (optional): Your website

#### Categories
- [ ] Primary category: Navigation or Entertainment
- [ ] Secondary category (optional): Travel

#### Age Rating
Answer questionnaire honestly:
- [ ] Unrestricted Web Access: Yes (Firebase Auth)
- [ ] Location Services: Yes
- [ ] Profanity/Mature Content: Based on story styles (likely 9+ or 12+)

### 8. Testing

#### Functionality Testing
- [ ] All auth methods work (Email, Google, Apple)
- [ ] Email password reset sends email
- [ ] Places autocomplete returns results
- [ ] "Use Current Location" requests permission and works
- [ ] Route calculation succeeds for various locations
- [ ] Story generation works end-to-end
- [ ] Audio plays correctly
- [ ] Background audio continues when app backgrounded
- [ ] Lock screen controls work (play/pause/next/prev)
- [ ] App doesn't crash on poor network
- [ ] Error messages are user-friendly

#### Edge Cases
- [ ] No network: Shows clear error
- [ ] Location denied: Shows clear message
- [ ] Server down: Shows clear error
- [ ] Very long route (>4hr): Shows rejection message
- [ ] Sign out works and clears state

#### Performance
- [ ] App launches in < 3 seconds
- [ ] No memory leaks (check Instruments)
- [ ] No crashes in production mode
- [ ] Audio doesn't stutter or lag

### 9. TestFlight Beta Testing

Before final submission:
- [ ] TestFlight build uploaded
- [ ] At least 5-10 external beta testers invited
- [ ] Beta tested for at least 1 week
- [ ] All critical bugs fixed
- [ ] Positive feedback received

### 10. Build & Upload

#### Xcode Archive
- [ ] Build configuration: Release (not Debug)
- [ ] Architecture: Any iOS Device (arm64)
- [ ] Product → Archive creates `.xcarchive`
- [ ] Archive validates successfully (Xcode validation)

#### Upload to App Store Connect
- [ ] Organizer → Distribute App → App Store Connect
- [ ] Upload succeeds
- [ ] Processing completes (check email notification)
- [ ] Build appears in App Store Connect

### 11. App Store Connect Submission

#### Build Selection
- [ ] Latest build selected for this version
- [ ] Export Compliance: Answer questions (likely: No encryption beyond HTTPS)

#### Review Information
- [ ] Demo account credentials provided (if sign-in required)
  - Username: `demo@storymaps.com` (or create one)
  - Password: Secure password
  - Instructions: "Sign in, enter any two locations, select story style, generate story"
- [ ] Contact information: Your email and phone
- [ ] Notes to reviewer: Any special instructions

#### Pricing & Availability
- [ ] Price: Free (or set price)
- [ ] Availability: All territories OR specific countries
- [ ] Release: Manual release (recommended for first version)

### 12. Final Checks Before "Submit for Review"

- [ ] All required fields filled in App Store Connect
- [ ] Screenshots look professional and accurate
- [ ] Privacy policy link works
- [ ] App metadata proofread for typos
- [ ] Age rating appropriate
- [ ] Test build one more time on device

---

## Submission

Once all items are checked:

1. Click **"Submit for Review"** in App Store Connect
2. Estimated review time: 24-48 hours (can be up to 7 days)
3. Monitor App Store Connect for status updates
4. Respond promptly to any rejection reasons

## Post-Approval

- [ ] Marketing plan ready for launch
- [ ] Social media announcements prepared
- [ ] Press release drafted (if applicable)
- [ ] Customer support channels ready
- [ ] Analytics configured to monitor adoption

## Common Rejection Reasons (Avoid These!)

1. **Missing Sign in with Apple**: If you offer Google, you MUST offer Apple
2. **Crashes**: App must not crash during review
3. **Incomplete Functionality**: All advertised features must work
4. **Privacy Policy Missing**: Must have valid, accessible privacy policy
5. **Misleading Screenshots**: Screenshots must accurately represent the app
6. **Demo Account Issues**: If required, demo account must work
7. **Third-Party Terms**: Must have permission to use Firebase, Google services (you do)

## Emergency Contacts

- **Apple Developer Support**: https://developer.apple.com/contact/
- **App Review**: Use "Appeal" button if rejected unfairly
- **Google Cloud Support**: For API issues
- **Firebase Support**: For auth issues

---

Good luck! 🚀 You've got this. Follow this checklist carefully and your app will sail through review.
