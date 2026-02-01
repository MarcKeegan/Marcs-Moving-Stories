/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// A centralized service for tracking analytics events throughout the app.
/// Uses Firebase Analytics under the hood.
final class AnalyticsService {
    
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Generic Event Logging
    
    /// Log a custom event with optional parameters
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        print("📊 Analytics: \(name) - \(parameters ?? [:])")
        #endif
    }
    
    // MARK: - Screen Views
    
    /// Log when a user views a specific screen
    func logScreenView(screenName: String, screenClass: String? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
        print("📊 Screen View: \(screenName)")
        #endif
    }
    
    // MARK: - App-Specific Events
    
    /// Log when a user generates a story
    func logStoryGenerated(style: String, duration: TimeInterval? = nil) {
        var params: [String: Any] = ["story_style": style]
        if let duration = duration {
            params["generation_duration_seconds"] = duration
        }
        logEvent("story_generated", parameters: params)
    }
    
    /// Log when a user creates a route
    func logRouteCreated(startLocation: String, endLocation: String, waypointCount: Int = 0) {
        logEvent("route_created", parameters: [
            "start_location": startLocation,
            "end_location": endLocation,
            "waypoint_count": waypointCount
        ])
    }
    
    /// Log when a user starts playback
    func logPlaybackStarted(storyId: String? = nil) {
        logEvent("playback_started", parameters: [
            "story_id": storyId ?? "unknown"
        ])
    }
    
    /// Log when a user completes playback
    func logPlaybackCompleted(storyId: String? = nil, completionPercentage: Double = 100) {
        logEvent("playback_completed", parameters: [
            "story_id": storyId ?? "unknown",
            "completion_percentage": completionPercentage
        ])
    }
    
    // MARK: - User Properties
    
    /// Set a user property for segmentation
    func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        print("📊 User Property: \(name) = \(value ?? "nil")")
        #endif
    }
    
    /// Set the user ID for cross-device tracking
    func setUserId(_ userId: String?) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        print("📊 User ID set: \(userId ?? "nil")")
        #endif
    }
}
