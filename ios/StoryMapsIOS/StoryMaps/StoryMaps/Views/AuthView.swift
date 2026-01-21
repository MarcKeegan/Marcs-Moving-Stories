/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var authMode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var currentNonce: String?
    @State private var showResetMessage = false
    
    enum AuthMode {
        case login, signup, reset
    }
    
    var body: some View {
        ZStack {
            Color(red: 34/255, green: 30/255, blue: 35/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Logo
                    
                    
                    
                    VStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 130, height: 40)
                            .foregroundColor(.white)
                        
                        Text("Every journey has a story.")
                            .font(.googleSans(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Sign in to turn every journey into a living story.")
                            .font(.googleSansSubheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Mode Selector
                    HStack(spacing: 0) {
                        Button(action: { authMode = .login }) {
                            Text("Sign in")
                                .font(.googleSansSubheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(authMode == .login ? Color.white : Color.clear)
                                .foregroundColor(authMode == .login ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white.opacity(0.6))
                                .cornerRadius(20)
                        }
                        
                        Button(action: { authMode = .signup }) {
                            Text("Sign up")
                                .font(.googleSansSubheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(authMode == .signup ? Color.white : Color.clear)
                                .foregroundColor(authMode == .signup ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white.opacity(0.6))
                                .cornerRadius(20)
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(24)
                    
                    // Email/Password Form
                    if authMode != .reset {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.googleSansCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                TextField("", text: $email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password")
                                    .font(.googleSansCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                SecureField("", text: $password)
                                    .textContentType(authMode == .signup ? .newPassword : .password)
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                            }
                            
                            if authMode == .signup {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Confirm password")
                                        .font(.googleSansCaption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    SecureField("", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        .padding(12)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.googleSansCaption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Error Message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.googleSansCaption)
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Reset Success Message
                    if showResetMessage {
                        Text("If an account exists for that email, a reset link has been sent.")
                            .font(.googleSansCaption)
                            .foregroundColor(.green)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Submit Button
                    Button(action: handleEmailAuth) {
                        Text(authMode == .signup ? "Create account" : authMode == .reset ? "Send reset link" : "Sign in with email")
                            .font(.googleSansSubheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                    }
                    .disabled(email.isEmpty || (authMode != .reset && password.isEmpty))
                    
                    // Forgot Password / Back to Sign In
                    if authMode == .login {
                        Button("Forgot password?") {
                            authMode = .reset
                        }
                        .font(.googleSansCaption)
                        .foregroundColor(.white.opacity(0.6))
                        .underline()
                    } else if authMode == .reset {
                        Button("Back to sign in") {
                            authMode = .login
                            showResetMessage = false
                        }
                        .font(.googleSansCaption)
                        .foregroundColor(.white.opacity(0.6))
                        .underline()
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.googleSansCaption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // Social Sign-In Buttons
                    VStack(spacing: 12) {
                        Button(action: { Task { await authViewModel.signInWithGoogle() } }) {
                            Text("Sign in with Google")
                                .font(.googleSans(size: 18))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .cornerRadius(30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Sign in with Apple
                        SignInWithAppleButton(
                            onRequest: { request in
                                let nonce = randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.email, .fullName]
                                request.nonce = sha256(nonce)
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                        )
                        .frame(height: 50)
                        .cornerRadius(30)
                        .signInWithAppleButtonStyle(.black)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 40)
                .background(Color(red: 59/255, green: 40/255, blue: 64/255))
                .cornerRadius(32)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark) // Force light mode for consistent UI design
    }
    
    private func handleEmailAuth() {
        Task {
            showResetMessage = false
            
            if authMode == .signup {
                guard password == confirmPassword else {
                    authViewModel.errorMessage = "Passwords don't match"
                    return
                }
                guard password.count >= 6 else {
                    authViewModel.errorMessage = "Password should be at least 6 characters"
                    return
                }
                await authViewModel.registerWithEmail(email: email, password: password)
            } else if authMode == .login {
                await authViewModel.signInWithEmail(email: email, password: password)
            } else if authMode == .reset {
                guard !email.isEmpty else {
                    authViewModel.errorMessage = "Enter your email to reset your password"
                    return
                }
                await authViewModel.resetPassword(email: email)
                showResetMessage = true
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                authViewModel.errorMessage = "Failed to get Apple ID token"
                return
            }
            
            Task {
                await authViewModel.signInWithApple(idTokenString: idTokenString, nonce: nonce)
            }
            
        case .failure(let error):
            authViewModel.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Apple Sign In Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
