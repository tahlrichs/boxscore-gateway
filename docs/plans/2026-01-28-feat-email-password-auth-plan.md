---
title: "Email/Password Auth: Supabase email provider + iOS forms"
type: feat
date: 2026-01-28
linear: BOX-22
brainstorm: docs/brainstorms/2026-01-28-email-auth-brainstorm.md
---

# Email/Password Auth (BOX-22)

## Overview

Add email and password authentication to BoxScore using Supabase Auth. Users can create an account (name, email, password) or sign in with email and password. Supabase handles all password security.

## Scope

**In scope:**
- Single email auth view with sign-in / sign-up mode toggle, presented as a navigation push from LoginView
- Client-side validation (email format, password length, matching passwords)
- Supabase `signUp` and `signIn` calls
- Error handling with user-friendly messages
- Name passed via Supabase `user_metadata` on sign-up

**Out of scope (deferred):**
- Forgot password flow (BOX-23)
- Email verification (BOX-24)

## Proposed Solution

### UI Architecture

A single `EmailAuthView` with a `.signIn` / `.signUp` mode handles both flows. This avoids duplicating form boilerplate and eliminates the risk of an infinite navigation stack (which would happen if two separate views cross-linked to each other via NavigationLinks).

LoginView has two buttons that both push `EmailAuthView`, just with a different initial mode:

```
LoginView (existing sheet)
  ├── Apple Sign In button (existing)
  ├── Google Sign In button (existing)
  ├── "Sign in with Email" → pushes EmailAuthView(mode: .signIn)
  └── "Create Account" → pushes EmailAuthView(mode: .signUp)
```

Inside `EmailAuthView`, a text link at the bottom toggles the mode (e.g., "Don't have an account? Create one" / "Already have an account? Sign in"). This flips the same view — no new screen is pushed.

### New Files

| File | Purpose |
|------|---------|
| `Features/Auth/EmailAuthView.swift` | Email auth form with sign-in / sign-up mode toggle |

### EmailAuthView

**Mode enum:**
```swift
enum EmailAuthMode {
    case signIn
    case signUp
}
```

**Shared fields (both modes):**
- Email text field (`keyboardType: .emailAddress`, `textContentType: .emailAddress`, `autocapitalization: .never`)
- Password field (`SecureField`, `textContentType: .password` for sign-in, `.newPassword` for sign-up)

**Sign-up only fields (hidden in sign-in mode):**
- Name text field (`textContentType: .name`)
- Confirm password field (`SecureField`, `textContentType: .newPassword`)

**Submit button:**
- "Sign In" or "Create Account" depending on mode
- Disabled while `isLoading` is true (prevents double-submit) AND while fields are invalid
- Style: 50pt height, `RoundedRectangle(cornerRadius: 12)`, matches existing buttons

**Loading state:**
- Local `@State private var isLoading = false` — covers only the Supabase auth call
- Once the auth call succeeds, the AuthManager listener fires and takes over (loading the profile, etc.)
- The LoginView sheet dismisses automatically when `authManager.isLoggedIn` becomes true
- Do NOT also observe `authManager.isLoading` in this view — that would cause a flicker

**Loading overlay** while awaiting Supabase response (match ProfileView pattern).

**Error alert** for failures.

**Footer link:** toggles `mode` between `.signIn` and `.signUp` (no navigation push — just flips the state on the same view). Form fields reset when switching modes.

**Keyboard handling:**
- `FocusState` enum to advance fields on Return key (email → password → confirm password → submit)
- Dismiss keyboard on tap outside fields: `.onTapGesture { focusedField = nil }` or wrap in `ScrollView` with `.scrollDismissesKeyboard(.interactively)`

**Client-side validation (sign-up mode):**
- Email matches pattern `something@something.something` (non-empty local part, `@`, domain with at least one dot) — no complex regex, just enough to catch obvious typos
- Password >= 8 characters
- Password == confirm password
- Name is not empty
- Inline validation messages shown below fields, not as alerts

**Sign-in call:**
```swift
try await SupabaseConfig.client.auth.signIn(
    email: email,
    password: password
)
// AuthManager listener handles the rest automatically
```

**Sign-up call:**
```swift
try await SupabaseConfig.client.auth.signUp(
    email: email,
    password: password,
    data: ["first_name": .string(firstName)]
)
// AuthManager listener handles session + profile load
```

### LoginView Changes

Update the existing email placeholder button (currently at lines 186-202) to be two buttons:

1. **"Sign in with Email"** → `NavigationLink` to `EmailAuthView(mode: .signIn)`
2. **"Create Account"** → `NavigationLink` to `EmailAuthView(mode: .signUp)`

Both styled consistently with existing Apple/Google buttons.

### Gateway: Profile Trigger Update

The existing profile auto-create trigger (`003_create_profiles.sql`) creates a profile row when a user signs up, but does not read `user_metadata`.

**Important:** Before writing the migration, read the current `handle_new_user()` function definition to ensure the update is additive and does not break Apple/Google sign-up flows.

Update the trigger function to extract `first_name` from `raw_user_meta_data`:

**File:** `gateway/src/db/migrations/` (new migration)

```sql
-- NOTE: Read the current handle_new_user() function first.
-- This should ADD the first_name extraction, not replace unrelated logic.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'first_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
```

Note: `COALESCE(..., '')` means users who sign up without a name (Apple/Google) get an empty string for `first_name`. Verify that the rest of the app handles empty strings the same as NULL for this field.

### Error Handling

Map Supabase errors to user-friendly messages. Keep this as a simple local function (switch statement), not a separate abstraction:

| Supabase Error | User Message |
|----------------|-------------|
| `user_already_exists` | "An account with this email already exists. Try signing in, or use Apple or Google." |
| `invalid_credentials` | "Incorrect email or password. Please try again." |
| `weak_password` | "Password must be at least 8 characters." |
| `over_request_rate_limit` | "Too many attempts. Please wait a moment and try again." |
| Network failure | "Unable to connect. Check your internet and try again." |
| Other | "Something went wrong. Please try again." |

### Supabase Dashboard Configuration

- Verify "Confirm email" is **disabled** (auto-confirm enabled) so `signUp` returns a session immediately
- Password minimum length set to 8 characters (or use Supabase default of 6 and enforce 8 client-side)

## Acceptance Criteria

- [ ] User can create an account with name, email, password
- [ ] User is immediately signed in after creating account (no email verification)
- [ ] User can sign in with email and password
- [ ] Invalid credentials show a clear error message
- [ ] Duplicate email shows helpful error suggesting Apple/Google sign-in
- [ ] Client-side validation prevents submission of invalid forms (email format `x@y.z`, password length, matching passwords)
- [ ] Name is saved to profile on sign-up (visible in ProfileView)
- [ ] Loading state shown during network calls, button disabled immediately to prevent double-submit
- [ ] Mode toggle between sign-in and sign-up works without stacking navigation views
- [ ] Keyboard dismisses when tapping outside fields
- [ ] Navigation back to LoginView works via back button
- [ ] Existing Apple/Google sign-in flows are unaffected

## Implementation Order

1. **Supabase dashboard** — Verify email confirmation is disabled
2. **Read current `handle_new_user()` trigger** — Understand existing logic before modifying
3. **EmailAuthView.swift** — Single view with mode toggle, both sign-in and sign-up flows, validation, error handling
4. **LoginView.swift** — Replace placeholder with two NavigationLinks to EmailAuthView
5. **Gateway migration** — Update profile trigger to read `first_name` from user_metadata (additive change)
6. **Test** — Full sign-up → sign-in → profile check flow

## Key Patterns to Follow

From existing codebase (see `docs/solutions/`):

- Use `@Environment(\.dismiss)` for navigation
- Use `@State` for local form state, not ViewModel (simple forms don't need MVVM)
- Use `SupabaseConfig.client.auth` directly (no gateway for auth calls)
- Local `isLoading` for the auth call; do not mix with `authManager.isLoading`
- Loading overlay pattern from [ProfileView.swift:122-131](XcodProject/BoxScore/BoxScore/Features/Auth/ProfileView.swift#L122-L131)
- Error alert pattern from [LoginView.swift:74-83](XcodProject/BoxScore/BoxScore/Features/Auth/LoginView.swift#L74-L83)
- Button styling from [LoginView.swift:110-111](XcodProject/BoxScore/BoxScore/Features/Auth/LoginView.swift#L110-L111)
- Theme colors: `Theme.text(for:)`, `Theme.cardBackground(for:)`, `Theme.blue`
- Error mapping as a local function (switch statement), not a separate file or abstraction

## References

- Brainstorm: [docs/brainstorms/2026-01-28-email-auth-brainstorm.md](docs/brainstorms/2026-01-28-email-auth-brainstorm.md)
- Related: BOX-23 (Forgot Password), BOX-24 (Email Verification)
- Learnings: [docs/solutions/integration-issues/box-19-auth-review-findings.md](docs/solutions/integration-issues/box-19-auth-review-findings.md)
- Supabase Swift Auth: `signUp(email:password:data:)`, `signIn(email:password:)`
