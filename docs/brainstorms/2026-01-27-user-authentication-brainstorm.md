# User Authentication Brainstorm

**Date:** 2026-01-27
**Status:** Complete
**Related Issues:** BOX-18, BOX-19, BOX-20, BOX-21, BOX-22

## What We're Building

A user authentication system for BoxScore that supports:
- Sign in with Apple
- Sign in with Google
- Email and password

Users should be able to use the app without logging in (guest mode), with certain features requiring an account later.

## Why Supabase Auth

We evaluated three approaches:

| Approach | Pros | Cons |
|----------|------|------|
| **Build ourselves (raw SQL)** | Full control, consistent with existing code | More code to write/maintain, security responsibility on us |
| **Build ourselves (Prisma ORM)** | Type-safe, migrations | Adds new pattern to codebase |
| **Supabase Auth** | Already use Supabase, handles security, battle-tested | Third-party dependency |

**Decision: Supabase Auth**

Reasons:
1. **Already using Supabase** — database is on Supabase, no new account needed
2. **Data stays in our database** — unlike Clerk/Auth0, user data lives in our Supabase tables
3. **Security handled** — password hashing, token management, rate limiting all built-in
4. **Login flows handled** — Apple, Google, email verification, password reset all included
5. **Cost effective** — 50,000 free monthly users, then ~$0.003/user
6. **Future-proof** — scales to millions of users

## Key Decisions

### 1. Authentication Provider: Supabase Auth
- Handles all three login methods (Apple, Google, email/password)
- iOS app uses Supabase SDK directly
- Gateway validates Supabase JWTs

### 2. User Data Storage
- `auth.users` table (created by Supabase) — stores login credentials
- `profiles` table (we create) — stores app-specific data (favorites, preferences)
- Profiles linked to auth users via foreign key

### 3. How Login Works
```
iOS App                    Supabase Auth              Gateway
   |                            |                        |
   |-- Sign in with Google ---->|                        |
   |                            |-- Verify with Google --|
   |<---- JWT token ------------|                        |
   |                                                     |
   |---------------- API request + JWT ---------------->|
   |                                                     |-- Validate JWT
   |<--------------- Response --------------------------|
```

### 4. Gateway Responsibilities (Simplified)
Original plan had gateway handling auth endpoints. New plan:
- Gateway does NOT handle login/register (Supabase does)
- Gateway validates Supabase JWTs in middleware
- Gateway has `/v1/auth/me` to return current user info
- Gateway has `/v1/profiles` endpoints for user preferences

### 5. Guest Mode
- App works fully without login
- Supabase SDK handles anonymous state
- Features requiring login prompt user to sign in

## Impact on Linear Issues

The switch to Supabase Auth simplifies all five issues:

| Issue | Original Scope | New Scope |
|-------|---------------|-----------|
| BOX-18 | Build users table, JWT system, auth middleware | Enable Supabase Auth, create profiles table, JWT validation middleware |
| BOX-19 | Build iOS auth manager from scratch | Integrate Supabase Swift SDK, profile UI |
| BOX-20 | Build Apple Sign In end-to-end | Configure Apple provider in Supabase, iOS integration |
| BOX-21 | Build Google Sign In end-to-end | Configure Google provider in Supabase, iOS integration |
| BOX-22 | Build email/password with password reset | Configure email provider in Supabase, iOS forms |

**Recommendation:** Update BOX-18 through BOX-22 to reflect Supabase Auth approach. Issues become smaller and more focused.

## Open Questions

1. **Email service for Supabase** — Supabase has built-in email but limited. May want to configure custom SMTP (SendGrid) for branded emails.
2. **Profile fields** — What user preferences to store initially? Suggest: favorite_teams, notification_preferences, theme_preference.
3. **Account linking** — If user signs in with Google, then later tries Apple with same email, should accounts merge? Supabase supports this but needs configuration.

## Next Steps

1. Update BOX-18 through BOX-22 descriptions to reflect Supabase Auth approach
2. Run `/workflows:plan` on updated BOX-18 to create implementation plan
3. Enable Supabase Auth in dashboard and configure providers
