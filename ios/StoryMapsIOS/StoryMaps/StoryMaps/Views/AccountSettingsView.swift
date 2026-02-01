/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false
    @State private var showSavedMessage = false
    
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
                        Text("Account")
                            .font(.googleSansBody)
                    }
                    .foregroundColor(.white)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Account Details Header
                Text("Account details")
                    .font(.googleSans(size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                // First Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("First")
                        .font(.googleSansCaption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("", text: $firstName, prompt: Text("First Name").foregroundColor(.gray))
                        .font(.googleSansBody)
                        .padding(16)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .tint(.black)
                        .cornerRadius(8)
                }
                .padding(.bottom, 16)
                
                // Last Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last")
                        .font(.googleSansCaption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("", text: $lastName, prompt: Text("Last Name").foregroundColor(.gray))
                        .font(.googleSansBody)
                        .padding(16)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .tint(.black)
                        .cornerRadius(8)
                }
                .padding(.bottom, 24)
                
                // Save Button
                HStack {
                    Spacer()
                    
                    if showSavedMessage {
                        Text("Saved!")
                            .font(.googleSansBody)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                    
                    Button(action: saveProfile) {
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
                
                // Error Message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.googleSansCaption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Close Account Section
                VStack(spacing: 16) {
                    Text("Close Account")
                        .font(.googleSans(size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        AnalyticsService.shared.logEvent("delete_account_initiated")
                        showDeleteConfirmation = true
                    }) {
                        Text("Delete Account")
                            .font(.googleSansBody)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.6, green: 0.2, blue: 0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            loadUserProfile()
        }
        .onChange(of: authViewModel.currentUser) { oldValue, newValue in
            // When user is deleted/logged out, dismiss this view
            if newValue == nil {
                dismiss()
            }
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                AnalyticsService.shared.logEvent("delete_account_confirmed")
                Task {
                    await authViewModel.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
        }
    }
    
    private func loadUserProfile() {
        if let profile = authViewModel.userProfile {
            firstName = profile.firstName
            lastName = profile.lastName
        }
    }
    
    private func saveProfile() {
        AnalyticsService.shared.logEvent("profile_saved")
        isSaving = true
        showSavedMessage = false
        Task {
            let profile = authViewModel.userProfile ?? UserProfile()
            await authViewModel.updateUserProfile(
                firstName: firstName,
                lastName: lastName,
                pushNotificationsEnabled: profile.pushNotificationsEnabled,
                emailNotificationsEnabled: profile.emailNotificationsEnabled,
                marketingOptIn: profile.marketingOptIn
            )
            isSaving = false
            
            // Show success if no error
            if authViewModel.errorMessage == nil {
                withAnimation {
                    showSavedMessage = true
                }
                // Hide after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSavedMessage = false
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
            .environmentObject(AuthViewModel())
    }
}
