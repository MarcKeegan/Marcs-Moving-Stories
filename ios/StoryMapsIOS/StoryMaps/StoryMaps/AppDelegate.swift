/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

#if canImport(FirebaseInAppMessaging)
import FirebaseInAppMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        #if canImport(FirebaseMessaging)
        // Set messaging delegate
        Messaging.messaging().delegate = self
        Log.app.info("Firebase Messaging configured")
        #endif
        
        #if canImport(FirebaseInAppMessaging)
        // In-App Messaging is automatically initialized when Firebase is configured
        // You can customize display behavior if needed:
        // InAppMessaging.inAppMessaging().messageDisplaySuppressed = false
        Log.app.info("Firebase In-App Messaging configured")
        #endif
        
        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // MARK: - APNs Token Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        // Pass device token to Firebase
        Messaging.messaging().apnsToken = deviceToken
        Log.app.info("APNs token registered with Firebase")
        #endif
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.app.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Remote Notification Handling
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if canImport(FirebaseMessaging)
        // Let Firebase handle the message
        Messaging.messaging().appDidReceiveMessage(userInfo)
        Log.app.debug("Firebase handled remote notification")
        #endif
        
        completionHandler(.newData)
    }
}

// MARK: - MessagingDelegate

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            Log.app.warning("FCM token is nil")
            return
        }
        
        // Never log the FCM token itself - it is a device credential.
        Log.app.info("FCM token received")
        
        // Post notification so other parts of the app can access the token
        NotificationCenter.default.post(
            name: Notification.Name("FCMTokenReceived"),
            object: nil,
            userInfo: ["token": token]
        )
    }
}
#endif

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Log.app.debug("Notification received in foreground")
                                
        #if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif
        
        // Handle notification action here (e.g., navigate to specific screen)
        Log.app.debug("Notification tapped")
        
        completionHandler()
    }
}
