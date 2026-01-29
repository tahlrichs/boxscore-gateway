---
title: Apple Sign In — Supabase Provider + iOS Integration
type: feat
date: 2026-01-28
linear: BOX-20
---

# Apple Sign In — Supabase Provider + iOS Integration

## Overview

Wire up "Sign in with Apple" in the iOS app using Supabase Auth. The auth foundation (BOX-18 gateway, BOX-19 iOS SDK) is complete — this ticket adds the first real login method. Supabase handles token verification; we configure the provider and connect the iOS button.

## Problem Statement

BoxScore currently supports guest-only usage. Users can't save preferences or sync across devices. Apple Sign In is the first login method — it's required by Apple if you offer any third-party login, and it's the most frictionless option for iOS users.

## Proposed Solution

Replace the placeholder Apple button in `LoginView` with Apple's official `SignInWithAppleButton`, wire it to Supabase via `signInWithIdToken`, and let the existing `AuthManager` listener handle the rest.

**No gateway changes needed** — JWT validation already works for any Supabase-issued token.

## Technical Approach

### Phase 1: Apple Developer + Supabase Configuration (Manual)

These are one-time setup steps done outside of code:

**Apple Developer Portal:**
- Enable "Sign in with Apple" capability on the App ID
- Create a Services ID for Supabase callback URL
- Generate a private key for Sign in with Apple

**Supabase Dashboard:**
- Enable Apple provider under Authentication > Providers
- Add: Services ID, Team ID, private key
- Set callback URL: `https://ssbphvkxsxajygivommq.supabase.co/auth/v1/callback`

**Xcode Project:**
- Add "Sign in with Apple" capability in Signing & Capabilities tab
- This modifies `BoxScore.entitlements` and `project.pbxproj`

### Phase 2: iOS Implementation

#### Update: `Features/Auth/LoginView.swift` (lines ~537-553)

Replace the placeholder button with Apple's official `SignInWithAppleButton` and add a private handler. No new files or classes needed — `SignInWithAppleButton` manages the Apple sheet, and `AuthManager`'s existing `authStateChanges` listener handles the session.

```swift
import AuthenticationServices

// In the view body, replace placeholder button:
SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = [.fullName, .email]
} onCompletion: { result in
    Task { await handleAppleSignIn(result) }
}
.signInWithAppleButtonStyle(.black)
.frame(height: 50)
.cornerRadius(12)

// Private method on LoginView:
private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
    guard case .success(let auth) = result,
          let credential = auth.credential as? ASAuthorizationAppleIDCredential,
          let tokenData = credential.identityToken,
          let idToken = String(data: tokenData, encoding: .utf8)
    else { return } // Cancel or missing token — silently ignore

    do {
        try await SupabaseConfig.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        // AuthManager's authStateChanges listener handles the rest
    } catch {
        // Use existing AuthManager error handling
        authManager.error = .unknown("Sign in failed. Please try again.")
    }
}
```

**No changes to `AuthManager.swift`** — existing error cases and auth state listener handle everything.

### Error Handling Matrix

| Scenario | User Sees | App Does |
|----------|-----------|----------|
| User cancels Apple sheet | Nothing | Stay on LoginView silently |
| Network unavailable | "No internet connection. Please try again." | Show alert on LoginView |
| Apple auth fails | "Sign in with Apple failed. Please try again." | Show alert, reset button |
| Supabase unreachable | "Sign in service unavailable. Please try again later." | Show alert, reset button |
| Profile trigger fails | "Account created but profile setup failed. Please try again." | Sign out, show alert |

### State Flow

```
User taps button
    → coordinator.isAuthenticating = true (button disabled)
    → ASAuthorizationController presents Apple sheet
    → User authenticates (Face ID / Touch ID / Passcode)
    → Apple returns credential with identityToken
    → Supabase signInWithIdToken sends token for verification
    → Supabase creates/finds user, returns session
    → AuthManager.authStateChanges fires .signedIn
    → AuthManager.loadUserProfile() fetches from gateway
    → AuthManager.user set → isLoggedIn = true
    → LoginView sheet dismisses (bound to auth state)
    → ProfileButton shows user initial
```

### Key Decisions

1. **Use `SignInWithAppleButton` (not custom button)** — Apple HIG requirement, App Store rejection risk otherwise
2. **No new coordinator class** — `SignInWithAppleButton` handles the Apple sheet; a private method on `LoginView` handles the result. ~15 lines total.
3. **No new error cases** — Existing `AuthError` cases cover all scenarios. Cancellation is silently ignored (standard iOS pattern).
4. **Button type: `.signIn`** — Standard for apps offering multiple login methods
5. **Button style: `.black`** — Matches existing LoginView design
6. **Dismiss on auth state change** — LoginView already dismisses when `isLoggedIn` becomes true via existing sheet binding

### Files Changed

| File | Change |
|------|--------|
| `Features/Auth/LoginView.swift` | Replace placeholder with `SignInWithAppleButton` + handler |
| `BoxScore.entitlements` | Add Sign in with Apple capability |
| `project.pbxproj` | Capability + entitlements reference |

### What Does NOT Change

- **AuthManager** — authStateChanges listener already handles new sessions, error enum unchanged
- **ProfileView** — already displays user data from AuthManager
- **ProfileButton** — already shows initial when logged in
- **Gateway** — already validates any Supabase JWT
- **Navigation flow** — sheet binding already toggles Login vs Profile

## Acceptance Criteria

- [ ] Can tap "Sign in with Apple" and complete full auth flow (requires device testing)
- [ ] User is logged in and ProfileButton shows initial (requires device testing)
- [ ] Tapping ProfileButton shows ProfileView (not LoginView) (requires device testing)
- [ ] User appears in Supabase `auth.users` table (requires device testing)
- [ ] Profile auto-created in `profiles` table via trigger (requires device testing)
- [x] Cancelling Apple sheet returns silently to LoginView (guard clause returns early)
- [x] Network error shows user-friendly alert (signInError state + alert modifier)
- [x] Button is disabled during authentication (Apple's sheet covers screen)
- [ ] Returning user recognized (no duplicate accounts) (requires device testing)
- [ ] Private relay email works (no crashes or validation errors) (requires device testing)

## Known Limitations (Out of Scope)

- **Simulator testing**: Apple Sign In requires a real device or Xcode test account
- **Account linking**: If same email exists via Google/email, Supabase handles merge by default — no custom logic needed
- **Apple credential revocation**: Handled by Supabase session expiry — user simply signs in again
- **Analytics**: No sign-in event tracking in this ticket

## Prevention Checklist (from BOX-19 learnings)

- [x] Uses existing GatewayClient / Supabase SDK (no custom fetch)
- [x] No speculative caching (YAGNI)
- [x] All error cases both thrown AND caught
- [x] No duplicate state — LoginView defers to AuthManager for auth state
- [x] iOS methods match gateway endpoint capabilities

## References

- [LoginView.swift](XcodProject/BoxScore/BoxScore/Features/Auth/LoginView.swift) — placeholder button to replace
- [AuthManager.swift](XcodProject/BoxScore/BoxScore/Core/Auth/AuthManager.swift) — auth state management
- [SupabaseConfig.swift](XcodProject/BoxScore/BoxScore/Core/Config/SupabaseConfig.swift) — Supabase client
- [BOX-19 plan](docs/plans/2026-01-27-feat-ios-auth-foundation-supabase-sdk-plan.md) — auth foundation architecture
- [BOX-19 review findings](docs/solutions/integration-issues/box-19-auth-review-findings.md) — prevention strategies
- [Auth brainstorm](docs/brainstorms/2026-01-27-user-authentication-brainstorm.md) — decision rationale
