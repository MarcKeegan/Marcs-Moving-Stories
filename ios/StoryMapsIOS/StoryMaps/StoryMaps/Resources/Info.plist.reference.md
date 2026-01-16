# Info.plist Configuration for Xcode

**Note**: Modern Xcode projects don't use a physical `Info.plist` file in the bundle. Instead, you configure these settings through the Xcode target's **Info** tab.

## How to Configure in Xcode

### 1. Open Target Settings
1. Select the **StoryMaps** project in Xcode
2. Select the **StoryMaps** target
3. Go to the **Info** tab

### 2. Add Custom Keys

Under **Custom Target Properties**, add these keys by clicking the **+** button:

#### Location Permission
- **Key**: `NSLocationWhenInUseUsageDescription`
- **Type**: String
- **Value**: `Your location is used to find your starting point for journey stories.`

#### App Transport Security
- **Key**: `NSAppTransportSecurity`
- **Type**: Dictionary
  - Add child: `NSAllowsArbitraryLoads` = NO (Boolean)
  - Add child: `NSExceptionDomains` (Dictionary)
    - Add child with your server domain (e.g., `your-server.run.app`)
      - Add: `NSIncludesSubdomains` = YES
      - Add: `NSExceptionRequiresForwardSecrecy` = YES
      - Add: `NSExceptionMinimumTLSVersion` = "TLSv1.2"

#### Custom Configuration Variables
These pull from your `Secrets.plist`:

- **Key**: `SERVER_BASE_URL`
- **Type**: String
- **Value**: `$(SERVER_BASE_URL)`

- **Key**: `GOOGLE_MAPS_IOS_API_KEY`
- **Type**: String
- **Value**: `$(GOOGLE_MAPS_IOS_API_KEY)`

- **Key**: `GOOGLE_PLACES_IOS_API_KEY`
- **Type**: String
- **Value**: `$(GOOGLE_PLACES_IOS_API_KEY)`

- **Key**: `GOOGLE_DIRECTIONS_API_KEY`
- **Type**: String
- **Value**: `$(GOOGLE_DIRECTIONS_API_KEY)`

### 3. Configure Build Settings

Go to **Build Settings** tab and search for:

#### "Preprocessor Macros" or "User-Defined Settings"
Add these to make Secrets.plist values available:

1. Search for "User-Defined" in Build Settings
2. Click **+** to add settings:
   - `SERVER_BASE_URL = $(inherited)`
   - `GOOGLE_MAPS_IOS_API_KEY = $(inherited)`
   - `GOOGLE_PLACES_IOS_API_KEY = $(inherited)`
   - `GOOGLE_DIRECTIONS_API_KEY = $(inherited)`

### 4. Capabilities

Go to **Signing & Capabilities** tab and add:

1. **Sign in with Apple** (Required for App Store)
2. **Background Modes**
   - Check: ✅ Audio, AirPlay, and Picture in Picture

### 5. Bundle Identifier

In **General** tab:
- **Bundle Identifier**: `com.yourcompany.storymaps` (or your chosen ID)
- **Version**: `1.0`
- **Build**: `1`

## Alternative: Using xcconfig File

If you prefer configuration files, create a `Config.xcconfig`:

```xcconfig
SERVER_BASE_URL = https://your-server.run.app
GOOGLE_MAPS_IOS_API_KEY = AIza...
GOOGLE_PLACES_IOS_API_KEY = AIza...
GOOGLE_DIRECTIONS_API_KEY = AIza...
```

Then in Xcode:
1. Go to Project → Info → Configurations
2. Set Debug/Release configurations to use `Config.xcconfig`

## Reference: Original Info.plist Content

The file `Info.plist.reference` (renamed from `Info.plist`) contains all the settings that were originally configured. Use it as a reference for what needs to be configured in Xcode's UI.

## Why This Change?

Modern Xcode (14+) auto-generates the Info.plist during build. Having a physical file causes conflicts:
- ❌ "Multiple commands produce Info.plist" error
- ❌ Build system confusion

The new approach:
- ✅ Cleaner project structure
- ✅ No build conflicts
- ✅ Better Xcode integration
- ✅ Easier to manage in version control
