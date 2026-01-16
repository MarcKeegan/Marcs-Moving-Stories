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

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
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
                } else {
                    self?.currentUser = nil
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
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
}

