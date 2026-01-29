//
//  LoginView.swift
//  BoxScore
//
//  Login screen with Apple, Google, and Email sign-in options
//

import AuthenticationServices
import CryptoKit
import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var signInError: String?
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("BoxScore")
                        .font(.largeTitle.bold())

                    Text("Sign in to save your favorite teams\nand sync across devices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sign-in buttons
                VStack(spacing: 12) {
                    // Apple Sign In - uses official Apple button (BOX-20)
                    appleSignInButton

                    // Google Sign In - uses official Google button (BOX-21)
                    googleSignInButton

                    // Divider
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        Text("or")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.vertical, 8)

                    // Email Sign In (BOX-22)
                    emailSignInButton
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue as Guest
                Button("Continue as Guest") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .alert("Sign In Error", isPresented: .init(
                get: { signInError != nil },
                set: { if !$0 { signInError = nil } }
            )) {
                Button("OK") { signInError = nil }
            } message: {
                if let signInError {
                    Text(signInError)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Sign In Buttons

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            Task { await handleAppleSignIn(result) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Apple Sign In Handler

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else { return } // Cancel or missing token — silently ignore

        do {
            try await SupabaseConfig.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: currentNonce)
            )
            // AuthManager's authStateChanges listener handles the rest
        } catch {
            signInError = "Sign in failed. Please try again."
        }
    }

    private var googleSignInButton: some View {
        // Placeholder - BOX-21 will replace with official Google button
        Button {
            // Wired in BOX-21
        } label: {
            HStack {
                Image(systemName: "g.circle.fill")
                Text("Sign in with Google")
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess, "Unable to generate nonce")
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private var emailSignInButton: some View {
        // Placeholder - BOX-22 will navigate to email form
        Button {
            // Wired in BOX-22
        } label: {
            HStack {
                Image(systemName: "envelope.fill")
                Text("Sign in with Email")
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    LoginView()
}
