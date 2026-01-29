---
title: "feat: Google Sign In with Supabase Auth (iOS)"
type: feat
date: 2026-01-28
linear: BOX-21
---

# Google Sign In with Supabase Auth (iOS)

## Overview

Add Google Sign In to BoxScore iOS app. Follow BOX-20 (Apple Sign In) pattern: SDK button → extract token → pass to Supabase `signInWithIdToken` → AuthManager listener handles everything downstream.

## Key Differences from Apple (BOX-20)

| Aspect | Apple | Google |
|--------|-------|--------|
| SDK | Built-in `AuthenticationServices` | `GoogleSignIn-iOS` via SPM |
| Button | `SignInWithAppleButton` | `GoogleSignInButton` (from `GoogleSignInSwift`) |
| Nonce | Required (SHA256 hash) | Skipped — enable "Skip nonce check" in Supabase (standard for Google iOS) |
| Presenting | Button handles its own sheet | Requires `UIViewController` reference from window scene |
| URL Scheme | Not needed | Required — reversed client ID in Info.plist |
| Tokens | `idToken` only | `idToken` + `accessToken` (both required, both optional) |

## Implementation

### Phase 1: Manual Configuration (not code)

- [x] **Google Cloud Console**: Create OAuth 2.0 iOS client ID + Web client ID (for Supabase)
- [x] **Supabase Dashboard**: Enable Google provider → add Web Client ID + Secret → enable "Skip nonce check"

### Phase 2: iOS Implementation

#### 2a. Add GoogleSignIn-iOS SDK

- [ ] Add `https://github.com/google/GoogleSignIn-iOS` via Xcode SPM
- [ ] Include both `GoogleSignIn` and `GoogleSignInSwift` products

#### 2b. Configure Info.plist

- [x] Add `GIDClientID` with iOS client ID
- [x] Add `CFBundleURLTypes` with reversed client ID as URL scheme
- [ ] See [Google iOS SDK setup docs](https://developers.google.com/identity/sign-in/ios/start-integrating) for exact format

#### 2c. Update LoginView.swift

- [x] Import `GoogleSignIn` and `GoogleSignInSwift`
- [x] Replace `googleSignInButton` placeholder with `GoogleSignInButton(scheme: .dark, style: .wide)`
- [x] Add `handleGoogleSignIn()` method following `handleAppleSignIn` pattern
- [x] Reuse existing `@State signInError` and alert for error display

Key implementation notes (from code review):
- **Both tokens are optional**: Guard-unwrap both `idToken` and `accessToken` — don't force-unwrap `accessToken`
- **ViewController access**: Get from window scene; show error (not silent return) if unavailable
- **Error handling**: Catch `GIDSignInError` with `.canceled` → silent return, all other cases → show alert
- **MARK comment**: Add `// MARK: - Google Sign In Handler` for consistency with Apple section

```swift
// MARK: - Google Sign In Handler

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

        // Nonce skipped — Google iOS SDK doesn't support nonces by default.
        // "Skip nonce check" enabled in Supabase dashboard (standard approach).
        try await SupabaseConfig.client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )
        // AuthManager's authStateChanges listener handles the rest
    } catch let error as GIDSignInError where error.code == .canceled {
        return // User cancelled — silently ignore (same as Apple)
    } catch {
        signInError = "Sign in failed. Please try again."
    }
}
```

#### 2d. Handle URL Callback in BoxScoreApp.swift

- [x] Add `import GoogleSignIn`
- [x] Add `.onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }` to WindowGroup

## What Does NOT Change

- **AuthManager** — authStateChanges listener already handles new sessions
- **ProfileView / ProfileButton** — already display auth state from AuthManager
- **Gateway** — already validates any Supabase JWT

## Acceptance Criteria

- [ ] Can tap "Sign in with Google" and complete full auth flow
- [ ] User is logged in and ProfileButton shows initial
- [ ] User appears in Supabase `auth.users` table
- [ ] Profile auto-created in `profiles` table via trigger
- [ ] Cancelling Google sheet returns silently to LoginView
- [ ] Network error shows user-friendly alert
- [ ] Returning user recognized (no duplicate accounts)

## Prevention Checklist (from BOX-19/20 learnings)

- [ ] Uses existing Supabase SDK (no custom fetch)
- [ ] No speculative caching (YAGNI)
- [ ] All error cases both thrown AND caught
- [ ] No duplicate state — LoginView defers to AuthManager for auth state
- [ ] Uses official Google button (not custom — avoids review risk)

## References

- [LoginView.swift](XcodProject/BoxScore/BoxScore/Features/Auth/LoginView.swift) — placeholder button to replace
- [BOX-20 compound](docs/compounds/2026-01-28-box20-apple-sign-in-integration.md) — Apple Sign In pattern to follow
