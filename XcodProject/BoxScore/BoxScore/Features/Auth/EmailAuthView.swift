//
//  EmailAuthView.swift
//  BoxScore
//
//  Email authentication form with sign-in / sign-up mode toggle (BOX-22)
//

import Auth
import SwiftUI

enum EmailAuthMode {
    case signIn
    case signUp
}

struct EmailAuthView: View {
    @State var mode: EmailAuthMode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password, confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(mode == .signIn ? "Sign In" : "Create Account")
                        .font(.title.bold())
                    Text(mode == .signIn
                         ? "Welcome back!"
                         : "Create your BoxScore account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Form fields
                VStack(spacing: 16) {
                    if mode == .signUp {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Name", text: $firstName)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .name)
                                .onSubmit { focusedField = .email }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if mode == .signUp && firstName.isEmpty && focusedField != .name && !email.isEmpty {
                                Text("Name is required")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .password }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !email.isEmpty && !isValidEmail(email) {
                            Text("Enter a valid email address")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                if mode == .signUp {
                                    focusedField = .confirmPassword
                                } else {
                                    submit()
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if mode == .signUp && !password.isEmpty && password.count < 8 {
                            Text("Password must be at least 8 characters")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if mode == .signUp {
                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .onSubmit { submit() }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords do not match")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                // Submit button
                Button(action: submit) {
                    Text(mode == .signIn ? "Sign In" : "Create Account")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!isFormValid || isLoading)

                // Mode toggle
                Button {
                    withAnimation(Theme.standardAnimation) {
                        mode = (mode == .signIn) ? .signUp : .signIn
                        resetFields()
                    }
                } label: {
                    if mode == .signIn {
                        Text("Don't have an account? ") +
                        Text("Create one").bold()
                    } else {
                        Text("Already have an account? ") +
                        Text("Sign in").bold()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let emailValid = isValidEmail(email)
        let passwordValid = password.count >= 8

        if mode == .signIn {
            return emailValid && !password.isEmpty
        } else {
            return emailValid && passwordValid
                && password == confirmPassword
                && !firstName.isEmpty
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        // something@something.something
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    // MARK: - Actions

    private func submit() {
        guard isFormValid, !isLoading else { return }
        focusedField = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                if mode == .signIn {
                    try await AuthManager.shared.signInWithEmail(email: email, password: password)
                } else {
                    try await AuthManager.shared.signUpWithEmail(email: email, password: password, firstName: firstName)
                }
                // AuthManager listener handles the rest automatically
            } catch {
                errorMessage = mapError(error)
            }
        }
    }

    private func mapError(_ error: Error) -> String {
        if let authError = error as? Auth.AuthError {
            switch authError.errorCode {
            case .userAlreadyExists, .emailExists:
                return "An account with this email already exists. Try signing in, or use Apple or Google."
            case .invalidCredentials:
                return "Incorrect email or password. Please try again."
            case .weakPassword:
                return "Password must be at least 8 characters."
            case .overRequestRateLimit, .overEmailSendRateLimit:
                return "Too many attempts. Please wait a moment and try again."
            default:
                break
            }
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Unable to connect. Check your internet and try again."
        }
        return "Something went wrong. Please try again."
    }

    private func resetFields() {
        email = ""
        password = ""
        confirmPassword = ""
        firstName = ""
        errorMessage = nil
        focusedField = nil
    }
}

#Preview("Sign In") {
    NavigationStack {
        EmailAuthView(mode: .signIn)
    }
}

#Preview("Sign Up") {
    NavigationStack {
        EmailAuthView(mode: .signUp)
    }
}
