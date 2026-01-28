//
//  AuthManager.swift
//  BoxScore
//
//  Manages authentication state using Supabase Auth
//

import Foundation
import Supabase

@Observable
class AuthManager {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - State
    private(set) var user: AuthenticatedUser?
    private(set) var isLoading = false
    private(set) var error: AuthError?

    // MARK: - Computed
    var isLoggedIn: Bool { user != nil }

    // MARK: - Private
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization
    private init() {
        listenToAuthChanges()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener
    private func listenToAuthChanges() {
        authStateTask?.cancel()
        authStateTask = Task { [weak self] in
            for await (event, session) in SupabaseConfig.client.auth.authStateChanges {
                await self?.handleAuthChange(event: event, session: session)
            }
        }
    }

    @MainActor
    private func handleAuthChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn:
            guard session != nil else {
                user = nil
                return
            }
            await loadUserProfile()

        case .signedOut:
            user = nil

        case .tokenRefreshed:
            // Token refreshed automatically by SDK - nothing to do
            break

        default:
            break
        }
    }

    // MARK: - Token Helper
    private func getAccessToken() async throws -> String {
        do {
            return try await SupabaseConfig.client.auth.session.accessToken
        } catch {
            throw AuthError.notAuthenticated
        }
    }

    // MARK: - Profile Loading
    @MainActor
    func loadUserProfile() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let token = try await getAccessToken()
            let response = try await GatewayClient.shared.fetchMe(token: token)
            user = response.toAuthenticatedUser()
        } catch let authError as AuthError {
            self.error = authError
        } catch let networkError as NetworkError {
            handleNetworkError(networkError)
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    @MainActor
    private func handleNetworkError(_ error: NetworkError) {
        switch error {
        case .httpError(let statusCode, _) where statusCode == 401:
            // Token invalid/expired and refresh failed - sign out
            Task { await signOut() }
        case .httpError(let statusCode, _) where statusCode == 403:
            self.error = .forbidden
        case .networkUnavailable:
            self.error = .offline
        default:
            self.error = .networkError(error.localizedDescription)
        }
    }

    // MARK: - Sign Out
    @MainActor
    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseConfig.client.auth.signOut()
            // State change handled by listener
        } catch {
            // Sign out locally even if network fails
            user = nil
        }
    }

    // MARK: - Delete Account
    @MainActor
    func deleteAccount() async throws {
        isLoading = true
        defer { isLoading = false }

        let token = try await getAccessToken()

        // Call gateway to delete account (which calls Supabase admin API)
        try await GatewayClient.shared.deleteAccount(token: token)

        // Clear local state
        user = nil
    }

    // MARK: - Update Profile
    @MainActor
    func updateProfile(firstName: String? = nil, favoriteTeams: [String]? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        let token = try await getAccessToken()

        let response = try await GatewayClient.shared.updateProfile(
            token: token,
            firstName: firstName,
            favoriteTeams: favoriteTeams
        )

        user = response.toAuthenticatedUser()
    }
}

// MARK: - Auth Errors
enum AuthError: Error, Equatable {
    case notAuthenticated
    case forbidden
    case offline
    case networkError(String)
    case unknown(String)

    var userMessage: String {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        case .forbidden:
            return "You don't have permission to do that."
        case .offline:
            return "You're offline. Some features may be unavailable."
        case .networkError, .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
