---
title: Deploy Gateway to Railway with Redis
type: feat
date: 2026-01-26
linear: BOX-12
---

# Deploy Gateway to Railway with Redis

## Overview

Deploy the BoxScore gateway to Railway so the app works without your laptop running. Add Redis for caching to improve response times and reduce ESPN API calls.

**Current state:** Gateway runs locally on `localhost:3001`. iOS app can't fetch scores when your laptop is closed.

**Target state:** Gateway runs on Railway 24/7. iOS app connects to `https://boxscore-gateway-production.up.railway.app`.

## Why Railway

- Simple GitHub integration (auto-deploys on push)
- Free Redis add-on via Upstash
- No cold starts on paid tier (~$5/month)
- iOS app already has Railway URL hardcoded

## Technical Context

### What's Already Ready

| Component | Status | Notes |
|-----------|--------|-------|
| Build scripts | ✅ | `npm run build` → `dist/`, `npm start` runs it |
| Environment vars | ✅ | All config via `process.env` in `gateway/src/config/index.ts` |
| Redis code | ✅ | Graceful fallback if Redis unavailable |
| iOS URL | ✅ | `AppConfig.swift` has `boxscore-gateway-production.up.railway.app` |
| Supabase DB | ✅ | Already connected in `.env` |

### What's Been Completed

- ✅ Railway project setup
- ✅ Redis service provisioned (with IPv6 for private networking)
- ✅ Environment variables configured on Railway
- ✅ First deployment triggered and verified

## Acceptance Criteria

- [x] Gateway accessible at `https://boxscore-gateway-production.up.railway.app/v1/health`
- [x] iOS app fetches scores from Railway (not localhost)
- [x] Redis connected and caching responses
- [x] Auto-deploys when pushing to `main` branch

## Implementation Plan

### Phase 1: Railway Project Setup

**Goal:** Get the gateway running on Railway without Redis first.

#### Step 1.1: Check Existing Railway Account

1. Go to [railway.app](https://railway.app) and sign in (or create account)
2. Check your dashboard for existing BoxScore project
3. Note: Railway requires a credit card even for free tier (since 2024)

#### Step 1.2: Create or Configure Project

**If project exists:**
- Open it and skip to Step 1.3

**If creating new:**
1. Click "New Project" → "Deploy from GitHub repo"
2. Authorize Railway to access your GitHub if prompted
3. Select `tahlrichs/boxscore-gateway`
4. **Important:** Set root directory to `gateway` in Settings → General

#### Step 1.3: Configure Service Name for Predictable URL

**Critical:** Railway generates random URLs by default. To get the URL your iOS app expects:

1. Click on the service (not the project)
2. Go to **Settings** → **Networking** → **Public Networking**
3. Set the service domain to: `boxscore-gateway-production.up.railway.app`
   - Or note the generated URL and update `AppConfig.swift` to match

#### Step 1.4: Configure Environment Variables

In Railway dashboard → service → **Variables** tab:

```env
NODE_ENV=production
DATABASE_URL=<copy your Supabase URL from local .env>
CORS_ORIGINS=*
LOG_LEVEL=info
```

**Note:** Do NOT set `PORT` - Railway injects its own `$PORT` automatically. Your code already handles this.

#### Step 1.5: Configure Build Settings

In **Settings** tab:
- Build command: `npm run build`
- Start command: `npm start`
- Watch paths: `/gateway/**`

#### Step 1.6: Deploy and Verify

1. Trigger deploy (or push to main)
2. Wait for build to complete (watch logs)
3. Test:
   ```bash
   curl https://boxscore-gateway-production.up.railway.app/v1/health
   ```
4. Expected response: `{"status":"healthy","timestamp":"..."}`

### Phase 2: Add Redis

**Goal:** Enable caching for faster responses.

1. **Add Redis service** in Railway dashboard
   - Click "New" → "Database" → "Redis" (Upstash)
   - Railway auto-generates `REDIS_URL` variable

2. **Link Redis to gateway**
   - In gateway service settings, add reference to Redis URL
   - Or manually copy `REDIS_URL` to gateway environment variables

3. **Verify Redis connection:**
   - Check Railway logs for "Redis connected" message
   - Make two requests to same endpoint, second should be faster

### Phase 3: iOS App Verification

**Goal:** Confirm the app works with the deployed gateway.

#### The DEBUG vs RELEASE Problem

By default, DEBUG builds (simulator) use `localhost:3001` and RELEASE builds use the Railway URL. This means:
- Running on simulator → hits your local gateway
- Running on physical device → hits Railway

#### Option A: Test with URL Override (Easiest)

1. In `AppConfig.swift`, temporarily set the override:
   ```swift
   private var gatewayBaseURLOverride: String? = "https://boxscore-gateway-production.up.railway.app"
   ```
2. Run on simulator
3. Verify scores load
4. Remove override after testing

#### Option B: Test in RELEASE Mode

1. In Xcode, change scheme to "Release" (Edit Scheme → Run → Build Configuration)
2. Run on simulator
3. Change back to "Debug" after testing

#### Option C: Test on Physical Device

1. Build to your phone
2. Close your laptop / stop local gateway
3. App should fetch scores over cellular/wifi

#### Verification Checklist

- [x] Health check returns 200: `curl https://boxscore-gateway-production.up.railway.app/v1/health`
- [x] Scoreboard returns data: `curl https://boxscore-gateway-production.up.railway.app/v1/scoreboard?league=nba`
- [x] iOS app displays scores with local gateway stopped

## Environment Variables Reference

| Variable | Local Value | Railway Value |
|----------|-------------|---------------|
| `PORT` | 3001 | 3001 (or Railway's `$PORT`) |
| `NODE_ENV` | development | production |
| `DATABASE_URL` | postgresql://... | Same (Supabase) |
| `REDIS_URL` | redis://localhost:6379 | Auto-set by Railway |
| `CORS_ORIGINS` | * | * (or restrict later) |
| `LOG_LEVEL` | debug | info |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Railway URL doesn't match iOS hardcoded URL | Check Railway project settings, can customize domain |
| Redis fails to connect | App continues without caching (graceful degradation) |
| ESPN rate limits hit | Redis caching reduces calls; monitor usage |

## Success Metrics

- App loads scores with laptop closed
- Response times under 500ms for cached requests
- No increase in ESPN API errors

## Cost Estimate

- **Railway Hobby Plan:** ~$5/month (no cold starts)
- **Upstash Redis:** Free tier (10,000 commands/day)
- **Total:** ~$5/month

## References

- [AppConfig.swift:15-25](XcodProject/BoxScore/BoxScore/Core/Config/AppConfig.swift#L15-L25) - Gateway URL configuration
- [gateway/src/config/index.ts](gateway/src/config/index.ts) - Environment variable handling
- [gateway/src/cache/redis.ts](gateway/src/cache/redis.ts) - Redis client with graceful fallback
- Linear ticket: BOX-12
