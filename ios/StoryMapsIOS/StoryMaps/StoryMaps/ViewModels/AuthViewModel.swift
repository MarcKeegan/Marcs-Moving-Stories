/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Combine
import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var userProfile: UserProfile?
    @Published var isLoading = true
    @Published var isProfileLoading = false
    @Published var errorMessage: String?
    
    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    #endif
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    init() {
        #if canImport(FirebaseAuth)
        // Listen to Firebase auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let user = firebaseUser {
                    self?.currentUser = AuthUser(
                        id: user.uid,
                        email: user.email,
                        displayName: user.displayName,
                        photoURL: user.photoURL
                    )
                    // Load user profile from Firestore
                    await self?.loadUserProfile(userId: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.userProfile = nil
                }
                self?.isLoading = false
            }
        }
        #else
        isLoading = false
        #endif
    }
    
    deinit {
        #if canImport(FirebaseAuth)
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        #endif
    }
    
    // MARK: - Firestore Profile Operations
    
    func loadUserProfile(userId: String) async {
        #if canImport(FirebaseFirestore)
        isProfileLoading = true
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists, let data = document.data() {
                self.userProfile = UserProfile(
                    firstName: data["firstName"] as? String ?? "",
                    lastName: data["lastName"] as? String ?? "",
                    email: data["email"] as? String,
                    pushNotificationsEnabled: data["pushNotificationsEnabled"] as? Bool ?? true,
                    emailNotificationsEnabled: data["emailNotificationsEnabled"] as? Bool ?? true,
                    marketingOptIn: data["marketingOptIn"] as? Bool ?? false,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                )
            } else {
                // Create default profile if it doesn't exist
                let newProfile = UserProfile(
                    email: currentUser?.email,
                    createdAt: Date()
                )
                try await saveUserProfile(newProfile)
                self.userProfile = newProfile
            }
        } catch {
            print("Error loading user profile: \(error)")
            errorMessage = "Failed to load profile"
        }
        isProfileLoading = false
        #endif
    }
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        #if canImport(FirebaseFirestore)
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AuthViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        var data: [String: Any] = [
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "pushNotificationsEnabled": profile.pushNotificationsEnabled,
            "emailNotificationsEnabled": profile.emailNotificationsEnabled,
            "marketingOptIn": profile.marketingOptIn,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let email = profile.email {
            data["email"] = email
        }
        
        if profile.createdAt != nil {
            // Don't overwrite createdAt if it already exists
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        try await db.collection("users").document(userId).setData(data, merge: true)
        self.userProfile = profile
        #endif
    }
    
    func updateUserProfile(
        firstName: String,
        lastName: String,
        pushNotificationsEnabled: Bool,
        emailNotificationsEnabled: Bool,
        marketingOptIn: Bool
    ) async {
        #if canImport(FirebaseFirestore)
        errorMessage = nil
        
        var updatedProfile = userProfile ?? UserProfile()
        updatedProfile.firstName = firstName
        updatedProfile.lastName = lastName
        updatedProfile.pushNotificationsEnabled = pushNotificationsEnabled
        updatedProfile.emailNotificationsEnabled = emailNotificationsEnabled
        updatedProfile.marketingOptIn = marketingOptIn
        updatedProfile.updatedAt = Date()
        
        do {
            try await saveUserProfile(updatedProfile)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firestore not configured"
        #endif
    }
    
    private func deleteUserProfile(userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("users").document(userId).delete()
        } catch {
            print("Error deleting user profile: \(error)")
        }
        #endif
    }
    
    // MARK: - Email/Password Auth
    
    func signInWithEmail(email: String, password: String) async {
        #if canImport(FirebaseAuth)
        errorMessage = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase not configured"
        #endif
    }
    
    func registerWithEmail(email: String, password: String) async {
        #if canImport(FirebaseAuth)
        errorMessage = nil
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase not configured"
        #endif
    }
    
    func resetPassword(email: String) async {
        #if canImport(FirebaseAuth)
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase not configured"
        #endif
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() async {
        #if canImport(GoogleSignIn) && canImport(FirebaseAuth)
        errorMessage = nil
        
        guard let clientID = Auth.auth().app?.options.clientID else {
            errorMessage = "Firebase client ID not found"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find root view controller"
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token"
                return
            }
            
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Google Sign-In not configured"
        #endif
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple(idTokenString: String, nonce: String) async {
        #if canImport(FirebaseAuth)
        errorMessage = nil
        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: nil
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase not configured"
        #endif
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif
            self.userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async {
        #if canImport(FirebaseAuth)
        errorMessage = nil
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return
        }
        
        let userId = user.uid
        
        do {
            // Delete Firestore profile first
            await deleteUserProfile(userId: userId)
            
            // Then delete the auth account
            try await user.delete()
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif
            self.currentUser = nil
            self.userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase not configured"
        #endif
    }
}
