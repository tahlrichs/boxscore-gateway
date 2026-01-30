---
title: "Centralize Auth Sign-In Calls Through AuthManager (BOX-25)"
category: code-quality-issues
date: 2026-01-29
status: resolved
tags:
  - ios
  - auth
  - refactor
  - single-source-of-truth
  - facade-pattern
module: ios-auth
priority: P3
related_tickets:
  - BOX-25
  - BOX-19
  - BOX-22
symptoms:
  - Sign-in calls (Apple, Google, Email) bypassed AuthManager, calling SupabaseConfig.client.auth directly
  - AuthManager owned sign-out, delete, profile updates but not sign-in — inconsistent abstraction boundary
  - firstName trimming logic duplicated in view layer instead of service layer
---

# Centralize Auth Sign-In Calls Through AuthManager (BOX-25)

## Problem

`AuthManager` owned every auth operation (sign-out, delete account, profile updates) except sign-in. Views called `SupabaseConfig.client.auth` directly for:

| Flow | View | Direct Call |
|------|------|-------------|
| Apple Sign-In | `LoginView` | `signInWithIdToken(provider: .apple)` |
| Google Sign-In | `LoginView` | `signInWithIdToken(provider: .google)` |
| Email Sign-In | `EmailAuthView` | `signIn(email:password:)` |
| Email Sign-Up | `EmailAuthView` | `signUp(email:password:data:)` |

This created an inconsistent facade — some auth went through the manager, some didn't.

## Root Cause

The original `AuthManager` was built incrementally. Sign-out and account management were added first with proper centralization. Sign-in views were written separately and called Supabase directly because the manager didn't have sign-in methods yet.

## Solution

Added 4 methods to `AuthManager`. Views call these instead of `SupabaseConfig.client.auth` directly.

```swift
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

## Key Design Decisions

1. **Methods throw errors directly** — Views already have their own error handling. No wrapping needed.
2. **No `@MainActor`** — Unlike `signOut`/`deleteAccount`/`updateProfile` which mutate `@Observable` state, these methods don't touch AuthManager state. They're pure async wrappers.
3. **No `isLoading` in AuthManager for sign-in** — Views manage their own loading state. AuthManager.isLoading stays reserved for post-auth operations.
4. **firstName trimming moved to `signUpWithEmail`** — Centralizes the 40-char cap so any future caller gets consistent behavior.

## Files Changed

- `AuthManager.swift` — Added 4 new methods
- `LoginView.swift` — Replaced 2 direct Supabase calls
- `EmailAuthView.swift` — Replaced 2 direct Supabase calls, removed local firstName trimming

## Prevention

When adding new auth operations in the future, always add the method to `AuthManager` first. Views should never call `SupabaseConfig.client.auth` directly.

## Related Documentation

- [BOX-19 Auth Review Cleanup](../integration-issues/box-19-auth-review-findings.md) — Single source of truth principle
- [BOX-22 Email Auth Review](../security-issues/box-22-email-auth-review-findings.md) — firstName 40-char cap, typed Auth.AuthError
- [PR #8](https://github.com/tahlrichs/boxscore-gateway/pull/8)
