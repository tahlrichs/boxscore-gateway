---
title: BOX-19 iOS Auth Code Quality Improvements
description: Code review findings and solutions for iOS authentication architecture
status: solved
date_created: 2026-01-27
date_solved: 2026-01-27
tags: [ios, authentication, architecture, code-review, swift]
related_issues: [BOX-18, BOX-19]
---

# BOX-19 iOS Auth Code Quality Improvements

## Problem Summary

After implementing the Supabase authentication foundation (BOX-18), a code review identified multiple architecture and quality issues in the iOS authentication layer:

1. **Infrastructure Bypass**: Auth methods bypassed the `GatewayClient` pattern, using `URLSession.shared` directly
2. **Premature Caching**: `AuthManager` implemented unnecessary caching that duplicated Supabase SDK functionality
3. **Unused Error Cases**: Auth error enum contained error cases that weren't raised
4. **State Management Duplication**: Both `AuthManager` and views maintained redundant state
5. **API Incompleteness**: Missing `updateProfile` method for complete API parity

## Root Causes

### Infrastructure Bypass
The initial auth implementation took shortcuts and didn't follow the established `GatewayClient` actor pattern used throughout the app. This created:
- Inconsistent error handling between auth and regular API calls
- Missing timeout configurations
- Bypassed circuit breaker and retry logic

### Premature Caching
The Supabase SDK automatically handles session persistence with:
- Local token storage
- Token refresh management
- Session rehydration on app launch

The custom cache layer was redundant and could cause stale data issues.

### State Duplication
Views like `ProfileView` were creating their own state (`isDeleting`) when `AuthManager.isLoading` already tracked loading state. This led to:
- Multiple sources of truth
- Synchronization bugs
- Unnecessary state management code

## Solutions Applied

### 1. GatewayClient Auth Methods Integration

Refactored three auth methods to use the `GatewayClient` actor pattern instead of direct `URLSession` calls.

**Before:**
```swift
extension GatewayClient {
    func fetchMe(token: String) async throws -> MeResponse {
        let url = config.gatewayBaseURL.appendingPathComponent("v1/auth/me")
        var request = URLRequest(url: url)
        // Manual header setup
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Direct URLSession.shared call - bypasses configured timeouts
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "InvalidResponse", code: 0))
        }

        // Manual error handling
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return try decoder.decode(MeResponse.self, from: data)
    }
}
```

**After:**
```swift
extension GatewayClient {
    func fetchMe(token: String) async throws -> MeResponse {
        let url = config.gatewayBaseURL.appendingPathComponent("v1/auth/me")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Uses actor's configured session with timeouts
        let (data, _) = try await executeAuthRequest(request)

        let authDecoder = JSONDecoder()
        authDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return try authDecoder.decode(MeResponse.self, from: data)
    }

    /// Execute an authenticated request using the actor's configured session
    private func executeAuthRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "InvalidResponse", code: 0))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return (data, httpResponse)
    }
}
```

**Benefits:**
- Uses actor's `URLSession` with configured 30s request and 60s resource timeouts
- Consistent error handling with the rest of the app
- Private `executeAuthRequest` helper centralizes auth request logic
- Reusable across `fetchMe`, `deleteAccount`, and `updateProfile`

### 2. Removed Caching from AuthManager

Eliminated the custom cache layer entirely since Supabase SDK handles persistence.

**Before:**
```swift
@Observable
class AuthManager {
    // ... state

    // Unnecessary cache properties
    private var cache: [String: AuthenticatedUser] = [:]
    private let cacheKey = "authenticated_user"

    private func loadCachedUser() -> AuthenticatedUser? {
        if let cached = cache[cacheKey] {
            return cached
        }

        // Try to load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let user = try? JSONDecoder().decode(AuthenticatedUser.self, from: data) {
            cache[cacheKey] = user
            return user
        }

        return nil
    }

    private func cacheUser(_ user: AuthenticatedUser) {
        cache[cacheKey] = user

        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func clearCache() {
        cache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
```

**After:**
```swift
@Observable
class AuthManager {
    // MARK: - State
    private(set) var user: AuthenticatedUser?
    private(set) var isLoading = false
    private(set) var error: AuthError?

    // MARK: - Computed
    var isLoggedIn: Bool { user != nil }

    // No caching - Supabase SDK handles session persistence automatically
}
```

**Rationale:**
- Supabase SDK stores tokens securely in Keychain (iOS)
- SDK automatically handles token refresh and session rehydration
- App detects auth state changes via `SupabaseConfig.client.auth.authStateChanges` stream
- Custom caching added complexity and potential stale data issues

### 3. Added getAccessToken Helper

Centralized token retrieval with consistent error handling.

**Implementation:**
```swift
// MARK: - Token Helper
private func getAccessToken() async throws -> String {
    do {
        return try await SupabaseConfig.client.auth.session.accessToken
    } catch {
        throw AuthError.notAuthenticated
    }
}
```

**Usage in AuthManager methods:**
```swift
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
    } catch {
        self.error = .unknown(error.localizedDescription)
    }
}

@MainActor
func deleteAccount() async throws {
    isLoading = true
    defer { isLoading = false }

    let token = try await getAccessToken()
    try await GatewayClient.shared.deleteAccount(token: token)
    user = nil
}
```

**Benefits:**
- Single source for token access
- Consistent `.notAuthenticated` error when token unavailable
- Easier to add token validation or refresh logic later

### 4. Removed Unused AuthError Cases

The auth error enum had cases that were never thrown:

**Before:**
```swift
enum AuthError: Error, Equatable {
    case notAuthenticated
    case forbidden
    case offline
    case cacheMissing  // UNUSED - never thrown anywhere
    case decodingFailed  // UNUSED - never thrown
    case cachingFailed  // UNUSED - never thrown
    case networkError(String)
    case unknown(String)
}
```

**After:**
```swift
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
```

**Benefit:** Lean error enum reflects actual error paths in code.

### 5. Simplified ProfileView State Management

Removed duplicate loading state tracking by using `authManager.isLoading`.

**Before:**
```swift
struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false  // DUPLICATE STATE
    @State private var deleteError: String?

    var body: some View {
        // ...
        .overlay {
            if isDeleting {  // Uses local state
                ProgressView()
            }
        }
    }

    private func deleteAccount() {
        Task {
            isDeleting = true  // Manual state management
            try await authManager.deleteAccount()
            isDeleting = false
            dismiss()
        }
    }
}
```

**After:**
```swift
struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        // ...
        .overlay {
            if authManager.isLoading {  // Uses AuthManager's state
                ProgressView()
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await authManager.deleteAccount()
                dismiss()
            } catch {
                deleteError = "Something went wrong. Please try again."
            }
        }
    }
}
```

**Benefits:**
- AuthManager already manages `isLoading` state
- Removed redundant `@State` variable
- AuthManager's `defer { isLoading = false }` ensures cleanup even on error
- Cleaner, single source of truth

### 6. Added updateProfile Method

Implemented missing `updateProfile` for complete API parity with gateway endpoint.

**GatewayClient:**
```swift
func updateProfile(token: String, firstName: String?, favoriteTeams: [String]?) async throws -> MeResponse {
    let url = config.gatewayBaseURL.appendingPathComponent("v1/auth/me")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    var body: [String: Any] = [:]
    if let firstName = firstName {
        body["first_name"] = firstName
    }
    if let favoriteTeams = favoriteTeams {
        body["favorite_teams"] = favoriteTeams
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await executeAuthRequest(request)

    let authDecoder = JSONDecoder()
    authDecoder.keyDecodingStrategy = .convertFromSnakeCase
    return try authDecoder.decode(MeResponse.self, from: data)
}
```

**AuthManager:**
```swift
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
```

**Benefits:**
- Allows profile updates (name, favorite teams) from ProfileView
- Foundation for future profile editing features
- Maintains pattern of delegating to GatewayClient

## Implementation Details

### Session Configuration in GatewayClient

The actor initializes URLSession with proper timeouts:

```swift
init(config: AppConfig = .shared, session: URLSession? = nil) {
    self.config = config
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601

    // Configure URLSession with timeouts
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 30    // Per-request timeout
    sessionConfig.timeoutIntervalForResource = 60   // Total operation timeout
    sessionConfig.waitsForConnectivity = true       // Don't fail immediately

    self.session = session ?? URLSession(configuration: sessionConfig)
}
```

Auth methods now use this configured session instead of `URLSession.shared`.

### Auth State Management

AuthManager listens to Supabase auth state changes:

```swift
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
        // Token refreshed automatically by SDK
        break

    default:
        break
    }
}
```

This ensures user profile syncs whenever auth state changes, without custom caching.

### Network Error Handling

AuthManager translates network errors to auth errors:

```swift
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
```

## Testing Considerations

### Unit Tests

- Mock `GatewayClient` to verify `AuthManager` calls correct methods
- Mock `SupabaseConfig.client.auth` to simulate auth state changes
- Verify `executeAuthRequest` properly handles HTTP errors
- Confirm `getAccessToken` throws `.notAuthenticated` when no session exists

### Integration Tests

- Sign in flow: Verify `AuthManager` loads user profile after Supabase sign-in
- Token refresh: Confirm `TokenRefreshed` event doesn't reload profile unnecessarily
- Offline: Test `AuthManager.error` is set to `.offline` on network failure
- Delete account: Verify account deletion clears user state and signs out

### Manual Testing

1. **Sign In**: Confirm user profile loads and displays correctly
2. **Sign Out**: Verify all auth state clears
3. **Delete Account**: Test account deletion with confirmation
4. **Network Offline**: Toggle airplane mode and verify `.offline` error displays
5. **Token Expiry**: Wait 1 hour or manually expire token in Supabase console

## Files Changed

| File | Changes |
|------|---------|
| `Core/Auth/AuthManager.swift` | Removed cache properties/methods, added `getAccessToken()`, simplified state |
| `Core/Networking/GatewayClient.swift` | Added `fetchMe()`, `deleteAccount()`, `updateProfile()` methods with `executeAuthRequest()` helper |
| `Features/Auth/ProfileView.swift` | Removed `isDeleting` state, use `authManager.isLoading` instead |

## Key Takeaways

1. **Follow Established Patterns**: Auth methods now use the same `GatewayClient` actor pattern as the rest of the app
2. **Leverage SDK Features**: Don't duplicate functionality (Supabase already handles token persistence)
3. **Single Source of Truth**: One `isLoading` state in `AuthManager`, not scattered across views
4. **Complete APIs**: Implement all required methods (`updateProfile`) not just the minimum
5. **Lean Error Models**: Only include error cases that can actually be thrown

These improvements maintain the same user-facing behavior while making the codebase more maintainable, testable, and consistent with app architecture patterns.
