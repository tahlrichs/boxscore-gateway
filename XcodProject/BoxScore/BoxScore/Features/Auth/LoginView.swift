//
//  LoginView.swift
//  BoxScore
//
//  Login screen with Apple, Google, and Email sign-in options
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

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
        // Placeholder - BOX-20 will replace with ASAuthorizationAppleIDButton
        Button {
            // Wired in BOX-20
        } label: {
            HStack {
                Image(systemName: "apple.logo")
                Text("Sign in with Apple")
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
