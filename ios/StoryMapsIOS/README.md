# StoryPath iOS Application

## Overview

**StoryPath** (formerly StoryMaps) is an iOS application that transforms travel journeys into immersive, AI-generated audio stories. Users plan a route between two locations, select a narrative style, and the app generates a personalized story with professional-quality narration that plays during their journey.

**App Name**: StoryPath  
**Platform**: iOS (iPhone and iPad)  
**Minimum iOS Version**: iOS 17+  
**Distribution**: Apple App Store

---

## Core Features

### 1. Route Planning
Users can plan journeys by specifying:
- **Start Location**: Selected via search or using current GPS location
- **End Location**: Selected via place search with autocomplete
- **Travel Mode**: Walking or Driving
- **Story Style**: Choose from multiple narrative genres

**Supported Story Styles:**
| Style | Description |
|-------|-------------|
| Walking Tour | Bright, conversational, and knowledgeable guide |
| Horror Narration | Intimate, slow, and building dread |
| Mystery Detective | Calm, precise, and observant investigation |
| Historical Fiction | Warm, vivid, and immersive period narrative |
| Science Fiction | Clean, cool, and focused futuristic tale |
| Noir Adventure | Hard-boiled noir storytelling |

### 2. AI-Powered Story Generation
- Stories are generated using **Google Gemini AI** (gemini-3-flash-preview model)
- Each story is segmented based on route duration (~60 seconds per segment)
- The AI creates a narrative outline first, then generates each segment with context continuity
- Stories incorporate real location names from the route

### 3. Text-to-Speech Audio Narration
- Audio is generated using **Google Gemini TTS** (gemini-2.5-flash-preview-tts model)
- Professional voice synthesis with the "Kore" voice
- Audio is delivered in WAV format for high-quality playback
- Supports background audio playback while device is locked

### 4. Interactive Map Display
- Real-time map visualization using **Google Maps SDK**
- Route polyline overlay showing the planned journey
- Current location tracking during the journey
- Segment markers indicating story progression

### 5. Audio Player
- Full-featured audio player with play/pause controls
- Segment-by-segment navigation (next/previous)
- Background playback support
- Lock screen controls via **MPRemoteCommandCenter**
- Now Playing information integration

### 6. User Profile Management
- Profile settings including first name and last name
- Notification preferences (push, email, marketing opt-in)
- Account deletion capability

---

## Authentication Methods

The app supports multiple authentication pathways:

### 1. Email/Password Authentication
- Standard email registration with password
- Password reset via email link
- Secure password storage via Firebase Authentication

### 2. Google Sign-In
- OAuth 2.0 authentication with Google accounts
- Seamless integration with Firebase Authentication

### 3. Apple Sign-In
- Native Sign in with Apple support
- Privacy-preserving authentication
- Complies with Apple App Store requirements

### 4. Guest Mode
- Browse and explore the app without creating an account
- Limited functionality (cannot generate stories)
- Clear prompts to sign in when attempting protected actions

---

## Data Collection & Storage

### Data Collected

#### Account Information
| Data Type | Purpose | Storage Location |
|-----------|---------|------------------|
| Email Address | Account identification and communication | Firebase Authentication |
| First Name | Personalization | Firestore `/users/{userId}` |
| Last Name | Personalization | Firestore `/users/{userId}` |
| Profile Created Date | Account management | Firestore `/users/{userId}` |
| Profile Updated Date | Account management | Firestore `/users/{userId}` |

#### Preferences & Settings
| Data Type | Purpose | Storage Location |
|-----------|---------|------------------|
| Push Notification Preference | Control notification delivery | Firestore `/users/{userId}` |
| Email Notification Preference | Control email delivery | Firestore `/users/{userId}` |
| Marketing Opt-In | Marketing communications consent | Firestore `/users/{userId}` |
| FCM Token | Push notification delivery | Firestore `/users/{userId}` |

#### Location Data
| Data Type | Purpose | Retention |
|-----------|---------|-----------|
| Current GPS Location | Route planning, map display, place search biasing | Session only (not stored) |
| Route Start/End Locations | Story generation context | Session only (not stored) |

#### Usage Analytics
| Event Type | Data Captured |
|------------|---------------|
| Screen Views | Screen name, screen class |
| Story Generated | Story style, generation duration |
| Route Created | Start location, end location, waypoint count |
| Playback Started | Story identifier |
| Playback Completed | Story identifier, completion percentage |
| Authentication Events | Auth mode (login/signup), method used |
| Feature Interactions | Button taps, settings changes |

### Data Storage Infrastructure

#### Firebase Services Used
1. **Firebase Authentication**: User identity management
2. **Cloud Firestore**: User profile and preferences storage
3. **Firebase Analytics**: Anonymous usage analytics
4. **Firebase Cloud Messaging (FCM)**: Push notification delivery
5. **Firebase In-App Messaging**: In-app promotional messages

#### Third-Party APIs
1. **Google Maps SDK for iOS**: Map rendering
2. **Google Places SDK for iOS**: Location search and autocomplete
3. **Google Directions API**: Route calculation
4. **Google Gemini API**: AI story and audio generation (via backend proxy)

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS Application                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  User Input ──► Authentication ──► Firebase Auth                 │
│                                                                  │
│  Location ──► Google Places API ──► Route Selection              │
│                                                                  │
│  Route ──► Backend Proxy ──► Gemini API ──► Story + Audio        │
│                                                                  │
│  User Actions ──► Firebase Analytics (anonymous)                 │
│                                                                  │
│  Preferences ──► Firestore (authenticated users only)           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Data Retention

| Data Category | Retention Period |
|---------------|------------------|
| Account Information | Until account deletion |
| User Preferences | Until account deletion |
| Analytics Data | As per Firebase Analytics defaults (typically 14 months) |
| Generated Stories | Session only (not stored on server) |
| Location Data | Session only (not stored) |
| FCM Token | Until logout or token refresh |

---

## Permissions Required

### Location Services
- **When In Use**: Required for showing current location on map and biasing place search results
- **Always (Optional)**: For background location updates during journey playback

**Usage Description**: "StoryPath needs your location to show your progress on the map during your journey."

### Notifications
- **Push Notifications**: For story updates, trip reminders, and promotional content
- **Permission is requested explicitly** via in-app prompt

### Background Modes
- **Audio**: For continued story playback when app is backgrounded
- **Remote Notifications**: For receiving push notifications

---

## Security Measures

### Authentication Security
- Firebase Authentication with industry-standard security
- Apple Sign-In with privacy-focused authentication flow
- Secure token management for API calls
- No passwords stored locally on device

### Data Transmission
- All API calls use HTTPS encryption
- Bearer token authentication for backend API calls
- Firebase SDK uses secure Google infrastructure

### API Key Management
- Sensitive configuration stored in `Secrets.plist` (not in version control)
- Server-side proxy for Gemini API calls (API key not exposed to client)

---

## Advertising

The app includes **Google AdMob** integration:
- **Ad Unit ID**: `ca-app-pub-5422665078059042~2131515255`
- Banner advertisements displayed within the app
- Follows Google AdMob policies for data collection and user consent

---

## Account Management

### Account Deletion
Users can delete their account at any time via:
1. Navigate to Settings → Account
2. Scroll to "Close Account" section
3. Tap "Delete Account"
4. Confirm deletion

**Deletion removes:**
- Firebase Authentication account
- Firestore user profile document
- All associated preferences and settings

**Note**: Analytics data that has already been collected is not retroactively deleted due to its anonymous nature.

---

## Third-Party Services Summary

| Service | Provider | Purpose | Data Shared |
|---------|----------|---------|-------------|
| Firebase Authentication | Google | User authentication | Email, OAuth tokens |
| Cloud Firestore | Google | Profile storage | User preferences |
| Firebase Analytics | Google | Usage analytics | Anonymous events |
| Firebase Cloud Messaging | Google | Push notifications | FCM tokens |
| Google Maps SDK | Google | Map display | None |
| Google Places SDK | Google | Location search | Search queries, location bias |
| Google Directions API | Google | Route calculation | Start/end coordinates |
| Google Gemini API | Google | AI story generation | Route details (via backend) |
| Google AdMob | Google | Advertising | Device advertising ID |

---

## For Marketing Content

### Key Value Propositions
1. **Personalized Audio Stories**: Every journey becomes a unique narrative adventure
2. **Multiple Story Genres**: Horror, mystery, historical fiction, sci-fi, and more
3. **AI-Powered Creation**: Cutting-edge Google Gemini AI technology
4. **Professional Narration**: High-quality text-to-speech voice acting
5. **Works While You Travel**: Background playback with lock screen controls
6. **Privacy-First Design**: Minimal data collection, clear user controls

### Target Audience
- Commuters seeking entertainment during daily travel
- Tourists wanting immersive location-based experiences
- Runners and walkers looking for engaging audio content
- Road trippers wanting to enhance long drives
- Fiction enthusiasts who enjoy audio storytelling

### App Store Keywords (Suggestions)
- AI storytelling, audio stories, travel companion, walking tour, road trip app, location-based audio, immersive narration, GPS stories, journey entertainment

---

## For Terms & Conditions

### Key Terms to Address
1. User must be 13+ years old to create an account
2. Users are responsible for safe device usage during travel
3. Generated stories are AI content and may contain inaccuracies
4. Route information is for entertainment, not navigation purposes
5. Account termination rights for Terms violations
6. Intellectual property of generated content (user receives license to personal use)
7. Service availability not guaranteed
8. Changes to service with notice

### Liability Disclaimers
- App is for entertainment purposes only
- Do not use while operating a vehicle unless using hands-free mode
- Route suggestions are for story generation, not navigation
- AI-generated content may occasionally contain errors or inappropriate content

---

## For Privacy Policy

### Required Disclosures
1. **What data is collected**: See "Data Collection & Storage" section above
2. **How data is used**: Personalization, notifications, analytics, advertising
3. **Third-party sharing**: Firebase services, Google APIs (see Third-Party Services table)
4. **User rights**: Access, deletion, opt-out of marketing
5. **Data security**: HTTPS encryption, secure Firebase infrastructure
6. **Children's privacy**: Not intended for children under 13
7. **International transfers**: Data processed on Google Cloud infrastructure
8. **Policy updates**: Users notified via app or email

### Contact Information
- Privacy inquiries: [Insert email]
- Data deletion requests: Via in-app account settings or email
- Website: https://storypath.app

### Policy Links (configured in app)
- Terms of Service: https://storypath.app/terms
- Privacy Policy: https://storypath.app/privacy

---

## Technical Specifications

| Specification | Value |
|---------------|-------|
| Bundle Identifier | (Check your project settings) |
| Minimum iOS Version | iOS 17.0+ |
| Swift Version | Swift 5.9+ |
| Architecture | SwiftUI + MVVM |
| Dependencies | Firebase SDK, Google Maps SDK, Google Places SDK |
| Background Modes | Audio, Remote Notifications |

---

*Document generated for StoryPath iOS Application v1.0*
