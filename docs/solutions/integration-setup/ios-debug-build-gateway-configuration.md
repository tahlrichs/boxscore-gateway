# iOS DEBUG Build Gateway Configuration

---
title: "App Showing 'No Games' - DEBUG Builds Pointing to Localhost Instead of Railway"
category: integration-setup
tags:
  - iOS
  - configuration
  - debug-builds
  - railway-deployment
  - AppConfig
module: Core/Config
symptoms:
  - "App displays 'No Games' or 'No NBA games on this date'"
  - "Date selector not visible"
  - "App only works when laptop is running local gateway"
severity: critical
date_documented: 2026-01-27
status: resolved
---

## Problem

After deploying the gateway to Railway, the iOS app still showed "No Games" when the user's laptop wasn't running a local gateway server.

**Expected behavior:** App should fetch data from Railway gateway 24/7, regardless of whether local development server is running.

**Actual behavior:** App showed empty state because DEBUG builds were hardcoded to connect to `http://192.168.0.225:3001` (local machine IP).

## Root Cause

`AppConfig.swift` uses Swift compiler directives to determine the gateway URL based on build type:

```swift
var gatewayBaseURL: URL {
    switch environment {
    case .development:
        // This was the problem - pointing to local IP
        return URL(string: "http://192.168.0.225:3001")!
    case .production:
        return URL(string: "https://boxscore-gateway-production.up.railway.app")!
    }
}
```

Since Xcode builds are DEBUG by default, the app always used the development URL—even when installed on a physical device for daily use.

## Solution

Changed the development URL to use Railway instead of localhost:

**File:** [AppConfig.swift](../../../XcodProject/BoxScore/BoxScore/Core/Config/AppConfig.swift)

```swift
case .development:
    // Use Railway for all builds (no local gateway needed)
    return URL(string: gatewayBaseURLOverride ?? "https://boxscore-gateway-production.up.railway.app")!
```

This ensures:
- DEBUG builds work without local gateway running
- App functions on physical devices away from development machine
- Override capability preserved via `gatewayBaseURLOverride` for testing

## Prevention

1. **Default to production URLs** for mobile apps where users expect always-on connectivity
2. **Use environment variables or build configurations** rather than compile-time switches for endpoint URLs
3. **Test on physical device disconnected from development network** before considering deployment complete

## Related Documentation

- [Railway Redis Private Networking](../integration-issues/railway-redis-private-networking-20260127.md) - Redis connection setup
- [Railway Deployment Plan](../../plans/2026-01-26-feat-railway-deployment-redis-plan.md) - Full deployment guide

## Diagnostic Checklist

If you see "No Games" in the app:

1. **Check gateway health:**
   ```bash
   curl https://boxscore-gateway-production.up.railway.app/v1/health
   ```

2. **Verify AppConfig.swift** points to correct URL for your build type

3. **Check for URL override:** App may have a stored override in UserDefaults (`gatewayBaseURLOverride`)

4. **Network connectivity:** Ensure device has internet access to reach Railway
