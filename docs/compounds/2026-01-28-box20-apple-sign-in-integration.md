---
title: Apple Sign In with Supabase — iOS Integration
date_solved: 2026-01-28
category: integration-issues
module: ios-auth
severity: medium
tags: [apple-sign-in, supabase, authentication, nonce, replay-attack, ios]
related_issues: [BOX-20, BOX-18, BOX-19]
---

# Apple Sign In with Supabase — iOS Integration

## Problem

BoxScore needed its first real login method. The auth foundation (Supabase SDK, AuthManager, gateway JWT validation) was built in BOX-18/19, but LoginView had only placeholder buttons. Users couldn't actually sign in.

## Solution

Replaced the placeholder Apple button with Apple's official `SignInWithAppleButton`, extracted the identity token from the credential, and sent it to Supabase via `signInWithIdToken`. The existing `AuthManager.authStateChanges` listener handles everything downstream (profile loading, UI updates, sheet dismissal).

### Key Code

```swift
// LoginView.swift — Apple Sign In button
SignInWithAppleButton(.signIn) { request in
    let nonce = randomNonceString()
    currentNonce = nonce
    request.requestedScopes = [.fullName, .email]
    request.nonce = sha256(nonce)
} onCompletion: { result in
    Task { await handleAppleSignIn(result) }
}

// Handler — extract token, send to Supabase
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
    } catch {
        signInError = "Sign in failed. Please try again."
    }
}
```

### Files Changed

| File | Change |
|------|--------|
| `Features/Auth/LoginView.swift` | Official Apple button + handler + nonce helpers |
| `BoxScore.entitlements` | New — `com.apple.developer.applesignin` capability |
| `project.pbxproj` | `CODE_SIGN_ENTITLEMENTS` reference in Debug + Release |

### What Did NOT Change

- **AuthManager** — existing `authStateChanges` listener handles new sessions automatically
- **Gateway** — already validates any Supabase JWT
- **ProfileView / ProfileButton** — already display auth state

## Root Cause / Why This Approach

The auth foundation was designed so adding a login provider requires minimal code. `AuthManager` listens to Supabase's `authStateChanges` stream, which fires regardless of how the session was created (Apple, Google, email). This means each new provider only needs to: (1) get a credential from the provider, (2) pass it to Supabase. Everything else is automatic.

## Decisions Made

1. **No new classes** — `SignInWithAppleButton` handles the Apple sheet; a private method on LoginView handles the result. ~30 lines total including nonce helpers.
2. **No new error cases** — Existing `AuthError.unknown` covers sign-in failures. Cancellation silently ignored (standard iOS pattern).
3. **Nonce validation** — Added after code review flagged replay attack risk. Generates 32-byte cryptographic nonce per attempt, hashes with SHA256 for Apple, passes raw nonce to Supabase for server-side verification.
4. **Local error state** — `@State signInError` in LoginView rather than `AuthManager.error` (which is `private(set)`). Acceptable for single provider; documented as tech debt for BOX-22 when three providers makes this pattern unwieldy.

## Review Findings

Code review surfaced 5 findings. Resolution:

| Finding | Severity | Action |
|---------|----------|--------|
| Missing nonce validation | P1 | Fixed — added nonce generation + SHA256 hashing |
| Error state duplication | P2 | Deferred to BOX-22 (comment added to Linear) |
| Alert binding complexity | P2 | Skipped — matches existing ProfileView pattern |
| Missing `.buttonStyle(.plain)` | P3 | Skipped — pre-existing in placeholder code |
| MARK comment granularity | P3 | Skipped — cosmetic |

## Prevention Strategies

### For Future Auth Providers (BOX-21, BOX-22)

1. **Always include nonce** — Any OAuth provider that supports nonce should use one. Check Supabase SDK docs for the `nonce` parameter.
2. **Use official provider buttons** — Apple requires `SignInWithAppleButton`; Google has `GIDSignInButton`. Custom buttons risk App Store rejection.
3. **Don't modify AuthManager for new providers** — The listener pattern means new providers just call Supabase; AuthManager handles the rest.
4. **Unify error state at BOX-22** — When three providers exist, refactor to use `AuthManager.error` (make it settable) or extract a `SignInCoordinator`. See Linear BOX-22 comment.

### Code Review Checklist (from BOX-19, applied here)

- [x] Uses existing infrastructure (Supabase SDK, no custom fetch)
- [x] No speculative caching (YAGNI)
- [x] All error cases both thrown AND caught
- [x] No duplicate state for auth lifecycle (local state only for UI feedback)
- [x] Nonce included for replay attack prevention

## Cross-References

- [Auth brainstorm](../brainstorms/2026-01-27-user-authentication-brainstorm.md) — Why Supabase Auth
- [BOX-19 plan](../plans/2026-01-27-feat-ios-auth-foundation-supabase-sdk-plan.md) — Auth foundation architecture
- [BOX-19 review findings](../solutions/integration-issues/box-19-auth-review-findings.md) — Prevention strategies
- [iOS auth review cleanup](../solutions/code-quality-issues/ios-auth-review-cleanup.md) — Infrastructure patterns
- [BOX-20 plan](../plans/2026-01-28-feat-apple-sign-in-supabase-ios-plan.md) — This feature's plan
