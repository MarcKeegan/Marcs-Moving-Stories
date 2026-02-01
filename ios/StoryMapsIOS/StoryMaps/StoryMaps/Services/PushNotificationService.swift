/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import UserNotifications
import Combine

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Service to manage push notification permissions, FCM tokens, and topic subscriptions
@MainActor
class PushNotificationService: ObservableObject {
    
    static let shared = PushNotificationService()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var fcmToken: String?
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    private init() {
        checkAuthorizationStatus()
        setupTokenRefreshObserver()
    }
    
    // MARK: - Permission Management
    
    /// Check current notification authorization status
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    /// Request notification permissions from the user
    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            
            if granted {
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
            
            checkAuthorizationStatus()
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - FCM Token Management
    
    /// Setup observer for FCM token refresh
    private func setupTokenRefreshObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTokenRefresh(_:)),
            name: Notification.Name("FCMTokenReceived"),
            object: nil
        )
    }
    
    @objc private func handleTokenRefresh(_ notification: Notification) {
        guard let token = notification.userInfo?["token"] as? String else { return }
        Task { @MainActor in
            self.fcmToken = token
            await self.saveTokenToFirestore(token)
        }
    }
    
    /// Get the current FCM token
    func getCurrentToken() async -> String? {
        #if canImport(FirebaseMessaging)
        do {
            let token = try await Messaging.messaging().token()
            self.fcmToken = token
            return token
        } catch {
            print("❌ Error fetching FCM token: \(error.localizedDescription)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    /// Save FCM token to Firestore user document
    private func saveTokenToFirestore(_ token: String) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ Cannot save FCM token: No authenticated user")
            return
        }
        
        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            print("✅ FCM token saved to Firestore")
        } catch {
            print("❌ Error saving FCM token: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Remove FCM token from Firestore (call on sign out)
    func removeTokenFromFirestore() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete(),
                "fcmTokenUpdatedAt": FieldValue.delete()
            ])
            print("✅ FCM token removed from Firestore")
        } catch {
            print("❌ Error removing FCM token: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Topic Subscriptions
    
    /// Subscribe to a topic for targeted notifications
    func subscribeToTopic(_ topic: String) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("❌ Error subscribing to topic '\(topic)': \(error.localizedDescription)")
            } else {
                print("✅ Subscribed to topic: \(topic)")
            }
        }
        #endif
    }
    
    /// Unsubscribe from a topic
    func unsubscribeFromTopic(_ topic: String) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("❌ Error unsubscribing from topic '\(topic)': \(error.localizedDescription)")
            } else {
                print("✅ Unsubscribed from topic: \(topic)")
            }
        }
        #endif
    }
}
