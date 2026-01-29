# Email/Password Auth Brainstorm

**Date:** 2026-01-28
**Linear Issue:** BOX-22
**Status:** Ready for planning

## What We're Building

Email and password authentication for BoxScore using Supabase Auth. Users can create an account with their name, email, and password, then sign in with email and password. Supabase handles all password security (hashing, storage).

## Scope for BOX-22

**In scope:**
- "Sign In" button on home screen → bottom sheet with email + password fields
- "Create Account" button on home screen → separate sheet with name, email, password, confirm password
- Call Supabase `signUp` and `signIn` methods
- Error handling for invalid credentials, duplicate emails, etc.
- Integrate with existing AuthManager flow (same as Apple/Google sign-in)

**Deferred:**
- Forgot password flow → BOX-23
- Email verification → BOX-24

## UI Flow

1. **Home screen** has two buttons: "Sign In" and "Create Account"
2. **Sign In** opens a bottom sheet modal with email field, password field, and a Sign In button
3. **Create Account** opens a separate bottom sheet with name, email, password, confirm password, and a Create Account button
4. On success, both flows log the user in and dismiss the sheet (same as Apple/Google)

## Why This Approach

- **Sheet modals** match the existing LoginView pattern (already uses sheets for Apple/Google)
- **No email verification** keeps sign-up frictionless — user creates account and is immediately in the app
- **No forgot password** reduces scope — rarely needed for a new app, and deep link setup adds complexity
- Both deferred items are tracked as separate tickets (BOX-23, BOX-24)

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Form presentation | Bottom sheet modals | Consistent with existing auth UI patterns |
| Email verification | Skip for now (BOX-24) | Low risk for a sports scores app; simplifies sign-up |
| Forgot password | Skip for now (BOX-23) | Requires deep link setup; rarely used on new accounts |
| Password requirements | Minimum 8 characters | Supabase default; simple and reasonable |

## Open Questions

- Custom SMTP for branded emails can wait until verification is enabled (BOX-24)
- Password requirements beyond minimum length (uppercase, special chars?) — defer to Supabase defaults for now

## Related Tickets

- **BOX-22** — This ticket (email sign up + sign in)
- **BOX-23** — Forgot password flow (deferred)
- **BOX-24** — Email verification (deferred)
