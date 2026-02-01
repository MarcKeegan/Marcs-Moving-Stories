/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pushService = PushNotificationService.shared
    
    @State private var pushNotificationsEnabled = true
    @State private var emailNotificationsEnabled = true
    @State private var marketingOptIn = false
    @State private var isSaving = false
    @State private var hasChanges = false
    @State private var showPermissionDeniedAlert = false
    
    var body: some View {
        ZStack {
            Color(red: 34/255, green: 30/255, blue: 35/255)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Notifications")
                            .font(.googleSansBody)
                    }
                    .foregroundColor(.white)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Header
                Text("Notification Settings")
                    .font(.googleSans(size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.bottom, 24)
                
                // Notification Toggles
                VStack(spacing: 0) {
                    NotificationToggleRow(
                        title: "Push Notifications",
                        subtitle: pushNotificationSubtitle,
                        isOn: $pushNotificationsEnabled
                    )
                    .onChange(of: pushNotificationsEnabled) { _, newValue in
                        handlePushToggleChange(newValue)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    NotificationToggleRow(
                        title: "Email Notifications",
                        subtitle: "Get updates about new features",
                        isOn: $emailNotificationsEnabled
                    )
                    .onChange(of: emailNotificationsEnabled) { _, newValue in
                        hasChanges = true
                        AnalyticsService.shared.logEvent("notification_toggle_changed", parameters: ["type": "email", "enabled": newValue])
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    NotificationToggleRow(
                        title: "Marketing",
                        subtitle: "Promotional content and offers",
                        isOn: $marketingOptIn
                    )
                    .onChange(of: marketingOptIn) { _, newValue in
                        hasChanges = true
                        AnalyticsService.shared.logEvent("notification_toggle_changed", parameters: ["type": "marketing", "enabled": newValue])
                    }
                }
                
                // Save Button
                if hasChanges {
                    HStack {
                        Spacer()
                        Button(action: saveSettings) {
                            Text(isSaving ? "Saving..." : "Save")
                                .font(.googleSansBody)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.23, green: 0.16, blue: 0.25))
                                .cornerRadius(8)
                        }
                        .disabled(isSaving)
                    }
                    .padding(.top, 24)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadSettings()
            pushService.checkAuthorizationStatus()
        }
        .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {
                // Revert toggle since permission was denied
                pushNotificationsEnabled = false
            }
        } message: {
            Text("Push notifications are disabled. Please enable them in Settings to receive updates.")
        }
    }
    
    private var pushNotificationSubtitle: String {
        switch pushService.authorizationStatus {
        case .authorized:
            return "Receive story updates and trip reminders"
        case .denied:
            return "Disabled in system settings"
        case .notDetermined:
            return "Tap to enable notifications"
        case .provisional:
            return "Provisional notifications enabled"
        case .ephemeral:
            return "Temporary notifications enabled"
        @unknown default:
            return "Receive story updates and trip reminders"
        }
    }
    
    private func handlePushToggleChange(_ newValue: Bool) {
        hasChanges = true
        AnalyticsService.shared.logEvent("notification_toggle_changed", parameters: ["type": "push", "enabled": newValue])
        
        if newValue {
            // User wants to enable push notifications
            Task {
                // Check current system permission status
                if pushService.authorizationStatus == .denied {
                    // Permission was previously denied, show alert to open settings
                    showPermissionDeniedAlert = true
                } else if pushService.authorizationStatus == .notDetermined {
                    // Request permission for the first time
                    let granted = await pushService.requestPermission()
                    if !granted {
                        await MainActor.run {
                            pushNotificationsEnabled = false
                        }
                    }
                } else {
                    // Permission already granted, just register
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }
    
    private func loadSettings() {
        if let profile = authViewModel.userProfile {
            pushNotificationsEnabled = profile.pushNotificationsEnabled
            emailNotificationsEnabled = profile.emailNotificationsEnabled
            marketingOptIn = profile.marketingOptIn
        }
        hasChanges = false
    }
    
    private func saveSettings() {
        AnalyticsService.shared.logEvent("notification_settings_saved", parameters: [
            "push": pushNotificationsEnabled,
            "email": emailNotificationsEnabled,
            "marketing": marketingOptIn
        ])
        isSaving = true
        Task {
            let profile = authViewModel.userProfile ?? UserProfile()
            await authViewModel.updateUserProfile(
                firstName: profile.firstName,
                lastName: profile.lastName,
                pushNotificationsEnabled: pushNotificationsEnabled,
                emailNotificationsEnabled: emailNotificationsEnabled,
                marketingOptIn: marketingOptIn
            )
            hasChanges = false
            isSaving = false
        }
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.googleSansBody)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.googleSansCaption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Color(red: 0.23, green: 0.16, blue: 0.25))
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(AuthViewModel())
    }
}
