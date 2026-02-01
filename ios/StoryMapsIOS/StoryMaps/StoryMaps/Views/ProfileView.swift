/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAccountSettings = false
    @State private var showNotificationSettings = false
    @State private var showTermsPrivacy = false
    
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
                        Text("Back")
                            .font(.googleSansBody)
                    }
                    .foregroundColor(.white)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Settings Header
                Text("Settings")
                    .font(.googleSans(size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 24)
                
                // Settings Options
                VStack(spacing: 0) {
                    // Only show account settings for authenticated users
                    if !authViewModel.isGuest {
                        SettingsRow(title: "Account") {
                            AnalyticsService.shared.logEvent("settings_row_tapped", parameters: ["destination": "account"])
                            showAccountSettings = true
                        }
                        
                        SettingsRow(title: "Notifications") {
                            AnalyticsService.shared.logEvent("settings_row_tapped", parameters: ["destination": "notifications"])
                            showNotificationSettings = true
                        }
                    }
                    
                    SettingsRow(title: "Terms & Privacy") {
                        AnalyticsService.shared.logEvent("settings_row_tapped", parameters: ["destination": "terms_privacy"])
                        showTermsPrivacy = true
                    }
                }
                
                Spacer()
                
                // Sign In / Logout Button
                if authViewModel.isGuest {
                    Button(action: {
                        AnalyticsService.shared.logEvent("guest_sign_in_tapped")
                        authViewModel.signOut() // Exit guest mode
                        dismiss()
                    }) {
                        Text("Sign In")
                            .font(.googleSansBody)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.23, green: 0.16, blue: 0.25))
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 32)
                } else {
                    Button(action: {
                        AnalyticsService.shared.logEvent("logout_tapped")
                        authViewModel.signOut()
                        dismiss()
                    }) {
                        Text("Logout")
                            .font(.googleSansBody)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.23, green: 0.16, blue: 0.25))
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 32)
                }
                
                // Footer
                Text("Made by Marc")
                    .font(.googleSansCaption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .navigationDestination(isPresented: $showAccountSettings) {
            AccountSettingsView()
        }
        .navigationDestination(isPresented: $showNotificationSettings) {
            NotificationSettingsView()
        }
        .navigationDestination(isPresented: $showTermsPrivacy) {
            TermsPrivacyView()
        }
        .onAppear {
            AnalyticsService.shared.logScreenView(screenName: "ProfileView")
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.googleSansBody)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}
