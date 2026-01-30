---
title: "Refactor: Centralize all auth calls through AuthManager"
type: refactor
date: 2026-01-29
linear: BOX-25
---

# Refactor: Centralize Auth Calls Through AuthManager

## Overview

Move all direct `SupabaseConfig.client.auth` calls out of views (`LoginView`, `EmailAuthView`) and into `AuthManager`. This gives us a single place to add logging, analytics, or error normalization in the future — without duplicating logic across views.

## Problem Statement

Currently, three auth flows bypass `AuthManager`:

| Flow | View | Direct Call |
|------|------|-------------|
| Apple Sign-In | `LoginView:125-127` | `signInWithIdToken(provider: .apple)` |
| Google Sign-In | `LoginView:162-164` | `signInWithIdToken(provider: .google)` |
| Email Sign-In | `EmailAuthView:216-219` | `signIn(email:password:)` |
| Email Sign-Up | `EmailAuthView:222-226` | `signUp(email:password:data:)` |

`AuthManager` already handles sign-out, delete account, and profile updates. Sign-in is the gap.

## Proposed Solution

Add four methods to `AuthManager`. Views call these instead of `SupabaseConfig.client.auth` directly. **No behavior changes** — just moving the Supabase calls behind AuthManager's interface.

### New AuthManager Methods

```swift
// AuthManager.swift

// MARK: - Sign In (errors thrown directly to callers — views handle mapping)

func signInWithApple(idToken: String, nonce: String?) async throws {
    try await SupabaseConfig.client.auth.signInWithIdToken(
        credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
    )
}

func signInWithGoogle(idToken: String, accessToken: String) async throws {
    try await SupabaseConfig.client.auth.signInWithIdToken(
        credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
    )
}

func signInWithEmail(email: String, password: String) async throws {
    try await SupabaseConfig.client.auth.signIn(email: email, password: password)
}

func signUpWithEmail(email: String, password: String, firstName: String) async throws {
    let trimmedName = String(firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    try await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: ["first_name": .string(trimmedName)]
    )
}
```

### View Changes

**LoginView.swift** — Replace direct Supabase calls with AuthManager calls:

```swift
// Before (line 125-127)
try await SupabaseConfig.client.auth.signInWithIdToken(
    credentials: .init(provider: .apple, idToken: idToken, nonce: currentNonce)
)

// After
try await AuthManager.shared.signInWithApple(idToken: idToken, nonce: currentNonce)
```

```swift
// Before (line 162-164)
try await SupabaseConfig.client.auth.signInWithIdToken(
    credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
)

// After
try await AuthManager.shared.signInWithGoogle(idToken: idToken, accessToken: accessToken)
```

**EmailAuthView.swift** — Replace direct Supabase calls:

```swift
// Before (line 216-219)
try await SupabaseConfig.client.auth.signIn(email: email, password: password)

// After
try await AuthManager.shared.signInWithEmail(email: email, password: password)
```

```swift
// Before (line 222-226)
try await SupabaseConfig.client.auth.signUp(
    email: email, password: password,
    data: ["first_name": .string(trimmedName)]
)

// After
try await AuthManager.shared.signUpWithEmail(email: email, password: password, firstName: firstName)
```

## Key Design Decisions

1. **Methods throw errors directly** — Views already have their own error handling (LoginView shows alerts, EmailAuthView maps error codes). AuthManager just passes through Supabase errors. No wrapping needed.

2. **No loading state changes in AuthManager** — Views already manage their own `isLoading` state for sign-in flows. AuthManager.isLoading stays reserved for post-auth operations (profile load, sign out, etc.).

3. **firstName trimming moves to AuthManager.signUpWithEmail** — Currently in EmailAuthView. Moving it to AuthManager means any future caller gets consistent behavior (per documented learning from BOX-22).

4. **No `@MainActor` on new methods** — Unlike `signOut`/`deleteAccount`/`updateProfile` which mutate `@Observable` state (`isLoading`, `user`, `error`), these methods don't touch AuthManager state. They're pure async wrappers. No reason to force a main-thread hop.

5. **No other behavior changes** — Error handling, cancellation handling, loading states, view dismissal all stay exactly as they are. This is a pure move refactor.

## Acceptance Criteria

- [x] `AuthManager` has `signInWithApple(idToken:nonce:)` method
- [x] `AuthManager` has `signInWithGoogle(idToken:accessToken:)` method
- [x] `AuthManager` has `signInWithEmail(email:password:)` method
- [x] `AuthManager` has `signUpWithEmail(email:password:firstName:)` method
- [x] `LoginView` calls `AuthManager.shared.signInWithApple()` instead of `SupabaseConfig.client.auth`
- [x] `LoginView` calls `AuthManager.shared.signInWithGoogle()` instead of `SupabaseConfig.client.auth`
- [x] `EmailAuthView` calls `AuthManager.shared.signInWithEmail()` instead of `SupabaseConfig.client.auth`
- [x] `EmailAuthView` calls `AuthManager.shared.signUpWithEmail()` instead of `SupabaseConfig.client.auth`
- [x] New methods have `// MARK: - Sign In` comment documenting the error contract
- [x] No view imports or references `SupabaseConfig.client.auth` for sign-in/sign-up
- [x] Remove unused Supabase import from `LoginView` if possible
- [x] All three providers (Apple, Google, Email) are updated together
- [x] Existing error handling in views is unchanged
- [x] App builds and all auth flows work as before

## Files to Change

| File | Change |
|------|--------|
| [AuthManager.swift](XcodProject/BoxScore/BoxScore/Core/Auth/AuthManager.swift) | Add 4 new methods |
| [LoginView.swift](XcodProject/BoxScore/Features/Auth/LoginView.swift) | Replace 2 direct Supabase calls |
| [EmailAuthView.swift](XcodProject/BoxScore/Features/Auth/EmailAuthView.swift) | Replace 2 direct Supabase calls, remove firstName trimming |

## Documented Learnings Applied

- **BOX-22**: Use typed `Auth.AuthError` with `errorCode` — views already do this, no change needed
- **BOX-22**: Use `defer { isLoading = false }` — views already do this, no change needed
- **BOX-22**: Cap firstName to 40 chars — moved into `signUpWithEmail`
- **BOX-19**: Single source of truth: manager owns state — this refactor moves auth calls to the manager

## References

- Linear: [BOX-25](https://linear.app/boxscores/issue/BOX-25)
- Related learnings: `docs/solutions/security-issues/box-22-email-auth-review-findings.md`
- Related learnings: `docs/solutions/code-quality-issues/ios-auth-review-cleanup.md`
