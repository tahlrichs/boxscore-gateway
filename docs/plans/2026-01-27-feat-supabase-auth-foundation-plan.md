---
title: "Auth Foundation: Supabase Auth setup, profiles table, gateway middleware"
type: feat
date: 2026-01-27
linear_issue: BOX-18
status: reviewed
---

# Auth Foundation: Supabase Auth Setup, Profiles Table, Gateway Middleware

## Overview

Set up the authentication foundation for BoxScore using Supabase Auth. This enables Apple, Google, and email sign-in (configured in subsequent issues). The gateway validates Supabase JWTs and provides a single auth endpoint.

**Brainstorm:** [2026-01-27-user-authentication-brainstorm.md](../brainstorms/2026-01-27-user-authentication-brainstorm.md)

## Problem Statement

BoxScore needs user accounts to support:
- Favorite teams (personalized experience)
- Push notifications (per-user preferences)
- Cross-device sync (when web app is added later)

Currently, the app has no user concept — all requests are anonymous.

## Proposed Solution

Use Supabase Auth (already using Supabase for database):

```
iOS App                    Supabase Auth              Gateway
   |                            |                        |
   |-- Sign in (Apple/Google) ->|                        |
   |<---- JWT token ------------|                        |
   |                                                     |
   |------------ API request + JWT -------------------->|
   |                                                     |-- Validate JWT (jose)
   |                                                     |-- Query profiles table
   |<--------------- Response --------------------------|
```

**Key principle:** Gateway does NOT handle login/logout — Supabase does. Gateway only validates tokens and serves profile data.

## Technical Approach

### Phase 1: Supabase Dashboard Setup

Enable authentication in Supabase project:

- [x] Enable Authentication in Supabase dashboard
- [ ] Configure Site URL: `boxscore://` (iOS deep link scheme)
- [ ] Add redirect URLs for OAuth providers (configured in BOX-20, 21, 22)
- [x] Note the project URL and anon key for gateway config

### Phase 2: Profiles Table + RLS

Create a minimal profiles table. Users enter their own first name (not auto-pulled from Google/Apple).

```sql
-- gateway/src/db/migrations/002_create_profiles.sql

-- Profiles table for app-specific user data
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT,
  favorite_teams JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can only read/update their own profile
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Auto-create empty profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

**Note:** Adding fields later (like `last_name` or `username`) is trivial:
```sql
ALTER TABLE profiles ADD COLUMN last_name TEXT;
```

### Phase 3: Gateway Auth Middleware

Install dependencies and create middleware:

```bash
cd gateway && npm install jose
```

**File: `gateway/src/middleware/auth.ts`**

```typescript
import { Request, Response, NextFunction } from 'express';
import { jwtVerify, createRemoteJWKSet, errors } from 'jose';
import { AppError } from './errorHandler';
import { config } from '../config';

// Create JWKS once at startup (jose caches and auto-refreshes)
const JWKS = createRemoteJWKSet(
  new URL(`${config.supabase.url}/auth/v1/.well-known/jwks.json`)
);

// Extend Express Request
declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

/**
 * Require valid Supabase JWT. Returns 401 if missing or invalid.
 */
export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next(new AppError('Authorization header required', 401, 'UNAUTHORIZED'));
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `${config.supabase.url}/auth/v1`,
      audience: 'authenticated',
    });

    if (!payload.sub) {
      return next(new AppError('Invalid token: missing subject', 401, 'TOKEN_INVALID'));
    }

    req.user = {
      id: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
    };

    next();
  } catch (error) {
    if (error instanceof errors.JWTExpired) {
      return next(new AppError('Token expired', 401, 'TOKEN_EXPIRED'));
    }
    if (error instanceof errors.JOSEError) {
      return next(new AppError('Invalid token', 401, 'TOKEN_INVALID'));
    }
    return next(error);
  }
}

/**
 * Attach user to request if valid token provided, but don't require it.
 * Use for routes that work for guests but can personalize for logged-in users.
 */
export async function optionalAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `${config.supabase.url}/auth/v1`,
      audience: 'authenticated',
    });

    if (payload.sub) {
      req.user = {
        id: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : undefined,
      };
    }
  } catch (error) {
    // Only ignore token validation errors, not infrastructure failures
    if (!(error instanceof errors.JOSEError)) {
      console.warn('Auth infrastructure error in optionalAuth:', error);
    }
    // Continue without user for optional auth
  }

  next();
}
```

### Phase 4: Config Updates

**File: `gateway/src/config/index.ts`** (add to existing config)

```typescript
// Add helper function at top of file
function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

// Add to config object
supabase: {
  url: requireEnv('SUPABASE_URL'),
  anonKey: requireEnv('SUPABASE_ANON_KEY'),
},
```

**File: `gateway/.env`** (add)

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Phase 5: Auth Route

Single endpoint for user info and profile updates.

**File: `gateway/src/routes/auth.ts`**

```typescript
import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../middleware/auth';
import { pool } from '../db/pool';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';

const router = Router();

// Types
interface Profile {
  id: string;
  first_name: string | null;
  favorite_teams: string[];
  created_at: string;
}

interface ProfileUpdate {
  first_name?: string | null;
  favorite_teams?: string[];
}

/**
 * GET /v1/auth/me
 * Returns current user info + profile
 */
router.get('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;

    const result = await pool.query<Profile>(
      `SELECT id, first_name, favorite_teams, created_at
       FROM profiles WHERE id = $1`,
      [userId]
    );

    const profile = result.rows[0] || null;

    res.json({
      user: {
        id: req.user!.id,
        email: req.user!.email,
      },
      profile,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /v1/auth/me
 * Update current user's profile
 */
router.patch('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const { first_name, favorite_teams }: ProfileUpdate = req.body;

    // Validate input
    if (first_name !== undefined && first_name !== null) {
      if (typeof first_name !== 'string' || first_name.length > 50) {
        throw new BadRequestError('first_name must be a string under 50 characters');
      }
    }

    if (favorite_teams !== undefined) {
      if (!Array.isArray(favorite_teams) || favorite_teams.length > 30) {
        throw new BadRequestError('favorite_teams must be an array with max 30 items');
      }
      if (!favorite_teams.every(t => typeof t === 'string')) {
        throw new BadRequestError('favorite_teams must contain only strings');
      }
    }

    // Check at least one field provided
    if (first_name === undefined && favorite_teams === undefined) {
      throw new BadRequestError('No fields to update');
    }

    // Update with COALESCE to handle partial updates
    const result = await pool.query<Profile>(
      `UPDATE profiles
       SET first_name = COALESCE($1, first_name),
           favorite_teams = COALESCE($2, favorite_teams)
       WHERE id = $3
       RETURNING id, first_name, favorite_teams, created_at`,
      [
        first_name ?? null,
        favorite_teams ? JSON.stringify(favorite_teams) : null,
        userId
      ]
    );

    if (result.rows.length === 0) {
      throw new NotFoundError('Profile not found');
    }

    res.json({ profile: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

export default router;
```

### Phase 6: Mount Routes

**File: `gateway/src/index.ts`** (add to existing routes)

```typescript
import authRouter from './routes/auth';

// Mount routes (after existing routes)
app.use('/v1/auth', authRouter);
```

## Acceptance Criteria

### Supabase Setup
- [x] Authentication enabled in Supabase dashboard
- [ ] Site URL and redirect URLs configured

### Database
- [x] Profiles table created with schema: `id`, `first_name`, `favorite_teams`, `created_at`
- [x] RLS policies active (users can only access own data)
- [x] Trigger auto-creates empty profile on user signup

### Gateway Middleware
- [x] `requireAuth` validates Supabase JWTs
- [x] `requireAuth` returns 401 with `UNAUTHORIZED` when no token
- [x] `requireAuth` returns 401 with `TOKEN_EXPIRED` when token expired
- [x] `requireAuth` returns 401 with `TOKEN_INVALID` when token malformed
- [ ] `optionalAuth` attaches user if valid token, passes through if not (REMOVED: YAGNI - add when needed)

### Endpoints
- [x] `GET /v1/auth/me` returns user info + profile when authenticated
- [x] `GET /v1/auth/me` returns 401 when not authenticated
- [x] `PATCH /v1/auth/me` updates first_name and/or favorite_teams
- [x] `PATCH /v1/auth/me` validates input (string length, array types)
- [x] `PATCH /v1/auth/me` only allows updating own profile (RLS enforced)

### Config
- [x] `SUPABASE_URL` and `SUPABASE_ANON_KEY` required (fails fast if missing)
- [x] Gateway config exports supabase settings

## Testing Plan

### Manual Testing

1. **Get a test JWT:**
   - Create test user in Supabase dashboard
   - Use Supabase client to get JWT

2. **Test auth endpoints:**
   ```bash
   # Without token - should return 401
   curl http://localhost:3001/v1/auth/me

   # With valid token - should return user + profile
   curl -H "Authorization: Bearer <JWT>" http://localhost:3001/v1/auth/me

   # Update profile
   curl -X PATCH -H "Authorization: Bearer <JWT>" \
     -H "Content-Type: application/json" \
     -d '{"first_name": "Tim", "favorite_teams": ["nba_1610612744"]}' \
     http://localhost:3001/v1/auth/me
   ```

3. **Test validation:**
   ```bash
   # Too long first_name - should return 400
   curl -X PATCH -H "Authorization: Bearer <JWT>" \
     -H "Content-Type: application/json" \
     -d '{"first_name": "x]...51 chars..."}' \
     http://localhost:3001/v1/auth/me
   ```

## Dependencies

- **Blocks:** BOX-19 (iOS Auth), BOX-20 (Apple), BOX-21 (Google), BOX-22 (Email)
- **Requires:** Existing Supabase database setup

## Files to Create/Modify

| File | Action |
|------|--------|
| `gateway/src/db/migrations/002_create_profiles.sql` | Create |
| `gateway/src/middleware/auth.ts` | Create |
| `gateway/src/routes/auth.ts` | Create |
| `gateway/src/config/index.ts` | Modify (add supabase config + requireEnv) |
| `gateway/src/index.ts` | Modify (mount auth route) |
| `gateway/.env` | Modify (add supabase vars) |
| `gateway/package.json` | Modify (add jose dependency) |

## Review Feedback Applied

This plan incorporates feedback from DHH, Kieran (TypeScript), and Simplicity reviewers:

- **Merged endpoints** — Single `/v1/auth/me` instead of separate auth and profiles routes
- **Simplified schema** — Only `first_name` and `favorite_teams` (no auto-pulled OAuth data)
- **Fixed type safety** — No `any`, proper jose error types, input validation
- **Simplified SQL** — COALESCE query instead of dynamic SQL builder
- **Fail-fast config** — Throws error if env vars missing
- **Removed `optionalAuth`** — YAGNI; add back when scores personalization is implemented

## References

- **Brainstorm:** [docs/brainstorms/2026-01-27-user-authentication-brainstorm.md](../brainstorms/2026-01-27-user-authentication-brainstorm.md)
- **Supabase Auth Docs:** https://supabase.com/docs/guides/auth
- **Supabase JWT Docs:** https://supabase.com/docs/guides/auth/jwts
- **jose Library:** https://github.com/panva/jose
