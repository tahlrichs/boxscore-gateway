---
title: "Percentage Scale Inconsistency Across API Endpoints and iOS App"
category: "integration-issues"
tags: ["API-contracts", "data-transformation", "scale-normalization", "stat-central", "player-stats"]
module: "stat-central-endpoint"
symptoms: ["Percentage values displayed incorrectly", "Inconsistent percentage scales between DB (0-1), API (mixed), and iOS (0-100)", "New endpoint returns different scale than existing endpoint"]
severity: "P1"
date_resolved: "2026-01-31"
linear: "BOX-37"
---

# Percentage Scale Inconsistency Across API Endpoints and iOS App

## Problem

When building the `stat-central` endpoint (BOX-37), we discovered the percentage scale was inconsistent across layers:

| Layer | FG% for 47% shooting | Scale |
|-------|----------------------|-------|
| Database (`nba_player_season_summary`) | `0.47` | 0-1 |
| Old `GET /:id` endpoint (before fix) | `0.47 / 100 = 0.0047` | Bug — divided already-decimal values |
| iOS `PlayerProfileView` | `value * 100` | Compensated for the bug |

The old endpoint had `fgPct: espnStats.currentSeasonStats.fgPct / 100` — but ESPN already returns 0-100 scale values like `47.0`. Dividing by 100 gave `0.47`, and the iOS app then multiplied by 100 to display `47.0%`. Two wrongs making a right.

## Root Cause

No documented convention for percentage scale at the API boundary. Each layer independently chose how to handle percentages, and the iOS app compensated for the gateway's incorrect transformation.

## Solution

Standardized on **0-100 scale for all API responses**:

1. **Gateway `/:id` endpoint** — removed the `/ 100` division (lines 292-297 of `playerRoutes.ts`)
2. **Gateway `stat-central` endpoint** — DB values converted with `* 100` at the gateway layer (line 166-167)
3. **iOS `PlayerProfileView`** — removed the `* 100` compensation (lines 214-216)
4. **Database** — unchanged, continues storing 0-1 decimal (DB convention is fine, conversion happens at gateway)

### Convention established

```
DB: 0-1 decimal (0.47)
  → Gateway converts: * 100
API response: 0-100 (47.0)
  → iOS displays directly: "47.0%"
```

## Prevention

- Document percentage scale convention in API response types with comments: `fgPct: number; // 0-100 scale`
- When adding new stat endpoints, check existing endpoints for scale conventions before choosing
- Add inline comments on any conversion: `// DB stores 0-1, API returns 0-100`

## Related

- [dark-mode-card-contrast.md](../ui-bugs/dark-mode-card-contrast.md) — another case where Theme conventions prevented inconsistency
- BOX-40 — follow-up refactoring issue from code review
