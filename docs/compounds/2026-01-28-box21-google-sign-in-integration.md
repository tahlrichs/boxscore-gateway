---
title: Google Sign In with Supabase — iOS Integration
date_solved: 2026-01-28
category: integration-issues
module: ios-auth
severity: medium
tags: [google-sign-in, supabase, authentication, oauth, ios, nonce-skip]
related_issues: [BOX-21, BOX-20, BOX-19]
---

# Google Sign In with Supabase — iOS Integration

## Problem

BoxScore had Apple Sign In (BOX-20) but needed Google as a second auth provider. The GoogleSignIn-iOS SDK has different requirements from Apple: it needs a presenting view controller, uses both `idToken` and `accessToken`, requires a URL scheme for OAuth callbacks, and doesn't support nonces.

## Solution

Added `GoogleSignIn-iOS` via SPM, replaced the placeholder button with `GoogleSignInButton`, and wired up `handleGoogleSignIn()` following the same pattern as Apple: SDK → extract tokens → `signInWithIdToken` → AuthManager handles the rest.

### Key Code

```swift
// LoginView.swift — Google Sign In handler
private func handleGoogleSignIn() async {
    guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
          let presentingVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController
    else {
        signInError = "Sign in failed. Please try again."
        return
    }

    do {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            signInError = "Sign in failed. Please try again."
            return
        }
        let accessToken = result.user.accessToken.tokenString

        try await SupabaseConfig.client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )
    } catch let error as GIDSignInError where error.code == .canceled {
        return // User cancelled — silently ignore
    } catch {
        signInError = "Sign in failed. Please try again."
    }
}

// BoxScoreApp.swift — URL callback handler
.onOpenURL { url in
    GIDSignIn.sharedInstance.handle(url)
}
```

### Files Changed

| File | Change |
|------|--------|
| `Features/Auth/LoginView.swift` | Official Google button + handler, imports |
| `App/BoxScoreApp.swift` | `import GoogleSignIn` + `.onOpenURL` handler |
| `Info.plist` | `GIDClientID` + `CFBundleURLTypes` (reversed client ID) |
| `project.pbxproj` | GoogleSignIn-iOS SPM package reference |

### What Did NOT Change

- **AuthManager** — existing `authStateChanges` listener handles new sessions automatically
- **Gateway** — already validates any Supabase JWT
- **ProfileView / ProfileButton** — already display auth state

## Key Differences from Apple (BOX-20)

| Aspect | Apple | Google |
|--------|-------|--------|
| SDK | Built-in `AuthenticationServices` | `GoogleSignIn-iOS` via SPM |
| Button | `SignInWithAppleButton` | `GoogleSignInButton` |
| Nonce | Required (SHA256 hash) | Skipped — "Skip nonce check" in Supabase |
| Presenting | Button handles its own sheet | Requires `UIViewController` from window scene |
| URL Scheme | Not needed | Required — reversed client ID in Info.plist |
| Tokens | `idToken` only | `idToken` + `accessToken` (both required) |

## Manual Configuration Required

Google Sign In requires setup outside the codebase:

1. **Google Cloud Console** — Create OAuth 2.0 project with iOS client ID (bundle ID: `com.BoxScore`) + Web client ID (for Supabase)
2. **Supabase Dashboard** — Enable Google provider, add Web Client ID + Secret, add iOS Client ID to the comma-separated Client IDs field, enable "Skip nonce check"
3. **Google Cloud Console** — Add Supabase callback URL (`https://<ref>.supabase.co/auth/v1/callback`) to Web client's Authorized redirect URIs

## Gotcha: "Unacceptable audience in id_token"

The iOS SDK sends an `idToken` with the iOS client ID as its audience. Supabase by default only accepts tokens with the Web client ID as audience. Fix: add the iOS client ID to the **comma-separated Client IDs** field in Supabase's Google provider settings. Both IDs in one field.

## Decisions Made

1. **No new classes** — Same pattern as Apple: private method on LoginView, ~40 lines of actual code.
2. **Nonce skipped** — Google iOS SDK doesn't support nonces. This is the standard approach documented by Supabase. Compensating controls: short-lived tokens, HTTPS, signature validation.
3. **Error handling** — Specific catch for `GIDSignInError.canceled` (silent return), generic catch for everything else (user-facing alert). Consistent with Apple handler.
4. **Official button** — Used `GoogleSignInButton(scheme: .dark, style: .wide)` instead of custom button to avoid App Store review risk.

## Review Findings

Three review agents ran in parallel. Summary:

| Finding | Severity | Action |
|---------|----------|--------|
| Nonce skipped for Google | P2 | Accepted — standard for Google iOS SDK |
| Error message repeated 3x | P3 | Accepted — only ~40 lines of code |
| VC discovery is verbose | P3 | Accepted — follows Google SDK docs |

No P1 findings. Security audit confirmed no critical vulnerabilities.

## Prevention Strategies

### For Future Auth Providers (BOX-22)

1. **Check audience requirements** — If the provider issues tokens with a platform-specific audience (like Google iOS), add that audience to Supabase's client IDs field.
2. **Always test end-to-end** — Dashboard configuration issues (wrong client ID, missing nonce skip) only surface at runtime. Add debug logging during development, remove before commit.
3. **Two client IDs for mobile** — Google requires an iOS client ID (public, in Info.plist) and a Web client ID (secret, in Supabase). The iOS one goes in the app; the Web one goes server-side.
4. **Comma-separated audiences** — Supabase's "Client IDs" field accepts multiple IDs separated by commas. This is how you authorize tokens from both Web and iOS clients.

## Cross-References

- [BOX-20 compound](2026-01-28-box20-apple-sign-in-integration.md) — Apple Sign In pattern (followed here)
- [BOX-21 plan](../plans/2026-01-28-feat-google-sign-in-supabase-ios-plan.md) — This feature's plan
- [BOX-19 plan](../plans/2026-01-27-feat-ios-auth-foundation-supabase-sdk-plan.md) — Auth foundation architecture
