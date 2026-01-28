---
title: iOS Auth Foundation Code Review Cleanup (BOX-19)
category: code-quality-issues
date: 2026-01-27
status: resolved
tags:
  - ios
  - auth
  - YAGNI
  - code-review
  - actor-isolation
  - state-management
module: ios-auth
priority: P2/P3
related_tickets:
  - BOX-19
symptoms:
  - Auth methods bypassed configured URLSession (used URLSession.shared directly)
  - Unnecessary ~25 lines of user caching code
  - Unused error case in AuthError enum
  - Duplicate loading state in ProfileView
  - Missing updateProfile method (gateway supported but iOS didn't)
---

## Problem

After implementing the Supabase iOS authentication foundation, a code review identified several issues:

**P2 Issues (Important):**
1. Auth methods in `GatewayClient` bypassed configured `URLSession` with timeouts/retry - used `URLSession.shared` directly
2. Missing `updateProfile` method in iOS layer (gateway `PATCH /v1/auth/me` had no iOS caller)

**P3 Issues (Code Quality):**
3. Unnecessary user caching in `AuthManager` (~25 lines) - Supabase SDK already handles session persistence
4. Unused `deletionFailed` error case in `AuthError` enum
5. Duplicate `isDeleting` state in `ProfileView` (redundant with `authManager.isLoading`)
6. Silent error swallowing with `try?` for token fetching

## Root Cause

- **Infrastructure bypass**: Auth methods were added quickly and didn't follow the existing `GatewayClient` pattern
- **Premature optimization**: Caching was added "just in case" without verifying Supabase SDK behavior (YAGNI violation)
- **Dead code**: Error cases created for hypothetical scenarios that never occurred
- **State duplication**: View layer created its own loading state instead of using the manager's
- **Silent failures**: `try?` swallowed errors, making debugging difficult

## Solution

### 1. Refactored GatewayClient Auth Methods (P2)

**File:** `GatewayClient.swift`

```swift
// ❌ Before: Bypassed actor's configured session
nonisolated func fetchMe(token: String) async throws -> MeResponse {
    let url = await config.gatewayBaseURL.appendingPathComponent("v1/auth/me")
    let (data, response) = try await URLSession.shared.data(for: request)  // Wrong!
    // ...
}

// ✅ After: Uses actor's configured session with timeouts
func fetchMe(token: String) async throws -> MeResponse {
    let url = config.gatewayBaseURL.appendingPathComponent("v1/auth/me")
    let (data, _) = try await executeAuthRequest(request)  // Uses session
    // ...
}

/// Centralized auth request execution using configured session
private func executeAuthRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)  // 30s/60s timeouts

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.unknown(NSError(domain: "InvalidResponse", code: 0))
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
    }

    return (data, httpResponse)
}
```

**Benefits:**
- Auth requests now respect 30s request / 60s resource timeouts
- Consistent error handling across all auth methods
- Proper actor isolation (removed `nonisolated`)

### 2. Added updateProfile Method (P2)

**File:** `GatewayClient.swift`

```swift
/// Update current user's profile
func updateProfile(token: String, firstName: String?, favoriteTeams: [String]?) async throws -> MeResponse {
    let url = config.gatewayBaseURL.appendingPathComponent("v1/auth/me")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    var body: [String: Any] = [:]
    if let firstName = firstName { body["first_name"] = firstName }
    if let favoriteTeams = favoriteTeams { body["favorite_teams"] = favoriteTeams }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await executeAuthRequest(request)
    // ...
}
```

**File:** `AuthManager.swift`

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

**Benefits:** iOS now has full API parity with gateway's `PATCH /v1/auth/me` endpoint.

### 3. Removed Unnecessary Caching (P3)

**File:** `AuthManager.swift`

```swift
// ❌ REMOVED: ~25 lines of caching code
private let cache = UserDefaults.standard
private let cacheKey = "cachedAuthUser"

private func loadCachedUser() { ... }
private func cacheUser(_ user: AuthenticatedUser?) { ... }
private func clearCache() { ... }
```

**Why removed:** Supabase SDK already persists sessions securely. Custom caching was redundant and added complexity without benefit.

### 4. Added Token Helper with Proper Error Handling (P3)

**File:** `AuthManager.swift`

```swift
// ❌ Before: Silent error swallowing
guard let token = try? await SupabaseConfig.client.auth.session.accessToken else {
    throw AuthError.notAuthenticated
}

// ✅ After: Proper error propagation
private func getAccessToken() async throws -> String {
    do {
        return try await SupabaseConfig.client.auth.session.accessToken
    } catch {
        throw AuthError.notAuthenticated
    }
}
```

**Benefits:** Errors during token refresh are now visible, not silently converted to "not authenticated".

### 5. Removed Unused Error Case (P3)

**File:** `AuthManager.swift`

```swift
enum AuthError: Error, Equatable {
    case notAuthenticated
    case forbidden
    case offline
    case networkError(String)
    // ❌ REMOVED: case deletionFailed(String) - never thrown
    case unknown(String)
}
```

### 6. Simplified ProfileView State (P3)

**File:** `ProfileView.swift`

```swift
// ❌ Before: Duplicate loading state
@State private var isDeleting = false

.overlay {
    if isDeleting { ... }
}

private func deleteAccount() {
    isDeleting = true
    // ...
    isDeleting = false
}

// ✅ After: Use manager's loading state
.overlay {
    if authManager.isLoading { ... }
}

private func deleteAccount() {
    Task {
        try await authManager.deleteAccount()  // Manager handles isLoading
        dismiss()
    }
}
```

**Benefits:** Single source of truth for loading state; view doesn't duplicate manager's responsibility.

## Impact

| Change | Lines Changed | Impact |
|--------|--------------|--------|
| GatewayClient refactor | +30, -25 | Uses proper session with timeouts |
| Added updateProfile | +25 | Full API parity |
| Removed caching | -25 | Simpler, less redundant |
| Token helper | +6, -4 | Better error visibility |
| Removed deletionFailed | -3 | Less dead code |
| ProfileView simplification | -5 | Single source of truth |
| **Total** | **~10 lines net reduction** | **Cleaner, more consistent** |

## Prevention Checklist

For future code reviews:

- [ ] New network methods use existing infrastructure (session, retry, circuit breaker)?
- [ ] No premature caching or optimization (verify actual need)?
- [ ] All error cases have callers (no dead code)?
- [ ] State not duplicated between manager and view?
- [ ] iOS methods match gateway API capabilities?

## Lessons Learned

1. **Use existing infrastructure**: Don't bypass the actor's configured session with `URLSession.shared`
2. **YAGNI for caching**: Don't add caching until you've verified the underlying library doesn't already handle it
3. **Single source of truth**: If a manager tracks loading state, views should use it, not duplicate it
4. **API parity**: When gateway supports an operation, ensure iOS has a matching method
5. **Avoid try?**: Silent error swallowing makes debugging harder

## Files Changed

- `GatewayClient.swift` - Refactored auth methods, added executeAuthRequest, added updateProfile
- `AuthManager.swift` - Removed caching, added getAccessToken, added updateProfile, removed deletionFailed
- `ProfileView.swift` - Removed isDeleting, simplified deleteAccount

**Build Status:** ✅ Both gateway and iOS builds pass
