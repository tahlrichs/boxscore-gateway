---
title: "Supabase Auth Foundation for Express Gateway"
category: integration-issues
tags:
  - supabase
  - auth
  - jwt
  - express
  - middleware
  - rls
  - jose
  - postgres
module: gateway
symptoms:
  - "App has no user concept - all API requests are anonymous"
  - "Need user accounts for favorite teams feature"
  - "Need per-user push notification preferences"
  - "Need cross-device sync for future web app"
root_cause: "No authentication infrastructure existed - needed to integrate Supabase Auth with existing Express gateway"
solution_summary: "JWT validation middleware using jose library with JWKS, /v1/auth/me endpoints for profile management, profiles table with RLS"
date_solved: 2026-01-27
related_issues:
  - BOX-18
---

# Supabase Auth Foundation for Express Gateway

## Problem

The BoxScore iOS app needed user authentication to support personalized features:
- Favorite teams tracking
- Per-user push notification preferences
- Cross-device sync (for future web app)

The gateway was serving anonymous requests with no user identity concept.

## Solution Overview

Implemented a complete authentication foundation using Supabase Auth:
- JWT validation middleware using `jose` library with JWKS auto-caching
- `/v1/auth/me` endpoints for profile management (GET + PATCH)
- PostgreSQL profiles table with Row Level Security (RLS)
- Fail-fast config validation

**Key principle:** Gateway validates JWTs, Supabase handles login/logout.

---

## Implementation Details

### 1. Auth Middleware (`gateway/src/middleware/auth.ts`)

Uses `jose` library for JWT verification with automatic JWKS caching:

```typescript
import { jwtVerify, createRemoteJWKSet, errors } from 'jose';
import { AppError } from './errorHandler';
import { config } from '../config';

// Create JWKS once at startup (jose caches and auto-refreshes)
const JWKS = createRemoteJWKSet(
  new URL(`${config.supabase.url}/auth/v1/.well-known/jwks.json`)
);

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

export async function requireAuth(
  req: Request, res: Response, next: NextFunction
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
```

**Why jose over jsonwebtoken:**
- Modern ES module support with TypeScript types
- Built-in JWKS auto-caching and refresh
- Specific error types for expired vs invalid tokens

### 2. Auth Routes (`gateway/src/routes/auth.ts`)

Profile management with strict input validation:

```typescript
// GET /v1/auth/me - Returns current user info + profile
router.get('/me', requireAuth, async (req, res, next) => {
  const userId = req.user!.id;
  const result = await pool.query<Profile>(
    `SELECT id, first_name, favorite_teams, created_at
     FROM profiles WHERE id = $1`,
    [userId]
  );

  res.json({
    user: { id: req.user!.id, email: req.user!.email },
    profile: result.rows[0] || null,
  });
});

// PATCH /v1/auth/me - Update profile with validation
router.patch('/me', requireAuth, async (req, res, next) => {
  const { first_name, favorite_teams } = req.body;

  // Validate first_name: type + length
  if (first_name !== undefined && first_name !== null) {
    if (typeof first_name !== 'string' || first_name.length > 50) {
      throw new BadRequestError('first_name must be a string under 50 characters');
    }
  }

  // Validate favorite_teams: type + length + format
  if (favorite_teams !== undefined) {
    if (!Array.isArray(favorite_teams) || favorite_teams.length > 30) {
      throw new BadRequestError('favorite_teams must be an array with max 30 items');
    }
    const TEAM_ID_REGEX = /^[a-z]+_[\w-]+$/;
    for (const teamId of favorite_teams) {
      if (typeof teamId !== 'string' || teamId.length > 50 || !TEAM_ID_REGEX.test(teamId)) {
        throw new BadRequestError('Invalid team ID format (expected: league_identifier)');
      }
    }
  }

  // Update with COALESCE for partial updates
  const result = await pool.query<Profile>(
    `UPDATE profiles SET ... WHERE id = $1 RETURNING *`,
    [userId]
  );

  res.json({ profile: result.rows[0] });
});
```

### 3. Database Migration (`gateway/src/db/migrations/003_create_profiles.sql`)

PostgreSQL table with RLS and auto-profile creation:

```sql
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT,
  favorite_teams JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;  -- Required for SECURITY DEFINER

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 4. Config (`gateway/src/config/index.ts`)

Fail-fast environment validation:

```typescript
function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  supabase: {
    url: requireEnv('SUPABASE_URL'),
  },
};
```

---

## Code Review Improvements

Issues caught and fixed during review:

| Finding | Fix Applied |
|---------|-------------|
| Missing string length limit for favorite_teams items | Added 50-char max per team ID |
| Missing team ID format validation | Added regex `/^[a-z]+_[\w-]+$/` |
| Unused `optionalAuth` middleware (YAGNI) | Removed - add when actually needed |
| Unused `anonKey` in config (gateway doesn't need it) | Removed from config |
| SECURITY DEFINER without search_path | Added `SET search_path = public` |

---

## Prevention Strategies

### 1. YAGNI - Only Write Code When Needed

**Bad:** Writing `optionalAuth` "because we'll need it for personalized scores"
**Good:** Write it when a route actually imports and uses it

**Checklist before writing new middleware:**
- [ ] Is there a specific route that will use this today?
- [ ] Have I added the import to that route file?
- [ ] Is this middleware called in at least one route?

### 2. Three-Layer Input Validation

Always validate: **Type → Length → Format**

```typescript
// Layer 1: Type check
if (typeof value !== 'string') throw new BadRequestError('must be string');

// Layer 2: Length check
if (value.length > 50) throw new BadRequestError('max 50 chars');

// Layer 3: Format check
if (!REGEX.test(value)) throw new BadRequestError('invalid format');
```

### 3. JWT Error Differentiation

Return specific error codes so clients can respond appropriately:

| Error Code | When | Client Action |
|------------|------|---------------|
| `UNAUTHORIZED` | No token provided | Redirect to login |
| `TOKEN_EXPIRED` | Token past expiration | Refresh token |
| `TOKEN_INVALID` | Token malformed/tampered | Force re-login |

### 4. SECURITY DEFINER Functions

Always add `SET search_path` to prevent search_path attacks:

```sql
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
```

---

## Testing Checklist

```bash
# 1. No token → 401 UNAUTHORIZED
curl http://localhost:3001/v1/auth/me

# 2. Expired token → 401 TOKEN_EXPIRED
curl -H "Authorization: Bearer <expired>" http://localhost:3001/v1/auth/me

# 3. Invalid token → 401 TOKEN_INVALID
curl -H "Authorization: Bearer garbage" http://localhost:3001/v1/auth/me

# 4. Valid token → 200 with user + profile
curl -H "Authorization: Bearer <valid>" http://localhost:3001/v1/auth/me

# 5. Input validation → 400 on invalid data
curl -X PATCH -H "Authorization: Bearer <valid>" \
  -d '{"first_name": "<51+ chars>"}' \
  http://localhost:3001/v1/auth/me
```

---

## Files Changed

| File | Purpose |
|------|---------|
| `gateway/src/middleware/auth.ts` | JWT validation middleware |
| `gateway/src/routes/auth.ts` | Profile management endpoints |
| `gateway/src/db/migrations/003_create_profiles.sql` | Database schema + RLS |
| `gateway/src/config/index.ts` | Supabase URL config |
| `gateway/src/index.ts` | Mount auth routes |
| `gateway/package.json` | Added jose dependency |

---

## Related Documentation

- **Plan:** [docs/plans/2026-01-27-feat-supabase-auth-foundation-plan.md](../../plans/2026-01-27-feat-supabase-auth-foundation-plan.md)
- **Brainstorm:** [docs/brainstorms/2026-01-27-user-authentication-brainstorm.md](../../brainstorms/2026-01-27-user-authentication-brainstorm.md)
- **Supabase Auth Docs:** https://supabase.com/docs/guides/auth
- **jose Library:** https://github.com/panva/jose
