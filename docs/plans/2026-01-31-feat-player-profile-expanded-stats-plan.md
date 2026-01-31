---
title: "Player Profile: Hero Banner Stats + Expanded Stat Central Table"
type: feat
date: 2026-01-31
linear: BOX-42
revised: 2026-01-31 (post-review)
---

# Player Profile: Hero Banner Stats + Expanded Stat Central Table

## Overview

Expand the NBA player profile to show comprehensive stats. The hero banner needs to display 5 current-season averages (PTS, REB, AST, FG%, 3PT%), and the Stat Central table needs to expand from 6 columns to all box score stat categories as per-game averages.

## Problem Statement

Currently the hero banner has 3PT% hardcoded to "--" and the Stat Central table only shows GP, PPG, RPG, APG, FG%, FT%. The database and ESPN both have all stats available — the bottleneck is the gateway API only returns 6 stats in the `SeasonRow` type, and the iOS models/views only render those 6.

## Proposed Solution

Thread the full stat set through all three layers: gateway types/providers → iOS models → iOS views. Add horizontal scrolling to the stat table since the columns won't fit on screen.

## Naming Convention

All `SeasonRow` fields are per-game averages. Use raw stat abbreviations without a `pg` suffix — the context (SeasonRow = averages) makes it clear. This avoids the inconsistency of having `ppg` next to `fgm` where one says "per game" and the other doesn't.

**Gateway `SeasonRow` new fields:**
```
gamesStarted: number
minutes: number         // minutes per game
points: number          // points per game
rebounds: number        // rebounds per game
assists: number         // assists per game
steals: number          // steals per game
blocks: number          // blocks per game
turnovers: number       // turnovers per game
personalFouls: number   // personal fouls per game
fgMade: number          // field goals made per game
fgAttempted: number
fg3Made: number         // three-pointers made per game
fg3Attempted: number
fg3Pct: number          // 0-100 scale
ftMade: number          // free throws made per game
ftAttempted: number
offRebounds: number     // offensive rebounds per game
defRebounds: number     // defensive rebounds per game
```

**Existing fields to rename** (breaking change, but we own both sides):
- `ppg` → `points`, `rpg` → `rebounds`, `apg` → `assists`, `spg` → `steals`

This means the iOS `SeasonRow` fields also use the same names, all as `Double?` (optional — see below).

## Implementation Phases

### Phase 1: Gateway — Expand SeasonRow and data pipeline

All gateway changes in one pass across these files:

**`gateway/src/types/statCentral.ts`** — Replace existing `SeasonRow` with expanded field set using new naming convention above.

**`gateway/src/providers/espnPlayerService.ts`** — `fetchSeasonBySeasonStats()` (line 415) currently builds `ESPNSeasonEntry` with only 6 stats. Update to extract all fields from the `ESPNSeasonStats` interface (which already parses everything at line 15).

**`gateway/src/db/repositories/playerRepository.ts`** — `getHistoricalSeasons()` query needs to SELECT additional columns from `nba_player_season_summary` (fg3m, fg3a, fg3_pct, oreb, dreb, blk, tov, pf, minutes_total, games_started, etc.) and map them to the expanded `SeasonRow`.

**`gateway/src/providers/playerStatCentral.ts`** — Update `NumericSeasonField` type and `computeCareerFromSeasons()` (line 42) to compute weighted averages for all new fields. Update season merging logic.

### Phase 2: iOS — Models, hero banner fix, and table expansion

**`StatCentralModels.swift`** — Add new fields to `SeasonRow` as **optionals** (`Double?`) so the iOS decoder doesn't crash if the gateway hasn't been updated yet. Existing fields renamed to match gateway.

**`PlayerProfileView.swift`** — Three changes:
1. **Hero banner**: Replace hardcoded "--" for 3PT% (line 345) with `fg3Pct` from the first season row
2. **Table columns**: Expand to show all stat categories in this order: SEASON (frozen), GP, GS, MIN, PTS, FG, FGA, FG%, 3PM, 3PA, 3P%, FT, FTA, FT%, OREB, DREB, REB, AST, STL, BLK, TO, PF
3. **Horizontal scroll**: Freeze SEASON column on left, wrap stat columns in horizontal `ScrollView`. Follow the existing frozen-column pattern from NBABoxScoreView (BOX-30). Size columns to fit content during implementation — don't hardcode widths upfront.

## Edge Cases

- **3PT% with zero attempts**: Display "--" (not "0.0"). Zero attempts = undefined percentage, not 0%.
- **Rookies**: Single season row + career row (identical). Works with current expand/collapse logic.
- **Traded players**: Per-team splits already supported. New stats flow through same structure.
- **Historical/retired players**: ESPN may return null for current season. Career row computed from DB historical data — ensure new fields included in computation.
- **Optional fields on iOS**: New `Double?` fields default to `nil` gracefully if gateway returns older response shape.

## Acceptance Criteria

- [x] Hero banner shows PTS, REB, AST, FG%, 3PT% with real data (no more "--")
- [x] Stat Central table displays all stat columns as per-game averages
- [x] SEASON column is frozen/pinned on the left while stats scroll horizontally
- [x] Career row includes weighted averages for all expanded stats
- [x] Traded player per-team splits include all expanded stats
- [x] Gateway `/v1/players/:id/stat-central` returns all new fields
- [x] Existing functionality (expand/collapse, 3-season default) unchanged
- [x] 3PT% shows "--" when player has zero three-point attempts

## Key Files

| File | Change |
|------|--------|
| `gateway/src/types/statCentral.ts` | Expand SeasonRow with new naming convention |
| `gateway/src/providers/espnPlayerService.ts` | Extract all stats in fetchSeasonBySeasonStats |
| `gateway/src/providers/playerStatCentral.ts` | Update career computation + merging |
| `gateway/src/db/repositories/playerRepository.ts` | Expand historical seasons query |
| `StatCentralModels.swift` | Add matching optional Swift properties |
| `PlayerProfileView.swift` | Fix 3PT%, expand table, add horizontal scroll |

## Learnings Applied

- **BOX-41**: Hero stats live in main body VStack, not inside tab content (already correct)
- **BOX-39**: Don't double-wrap data — models match gateway response shape directly
- **BOX-30**: Frozen column + scrollable stats pattern works well for wide stat tables
- **BOX-15**: YAGNI — don't add sort/filter/advanced features, just show the data

## References

- Brainstorm: `docs/brainstorms/2026-01-31-player-profile-full-stats-brainstorm.md`
- Linear: [BOX-42](https://linear.app/boxscores/issue/BOX-42)
