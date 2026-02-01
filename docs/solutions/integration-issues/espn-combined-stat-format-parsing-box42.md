---
title: ESPN API Stat Format Mismatch - Combined Stats Parser Bug
date: 2026-01-31
category: integration-issues
tags: [espn, api-parsing, player-stats, data-integrity, shooting-stats]
module: gateway/providers
severity: high
symptoms:
  - All shooting statistics (FG, FGA, 3PM, 3PA, FTM, FTA) displaying 0.0 in player profiles
  - Games Started (GS) showing multiplied garbage values (e.g., 4216 instead of 62)
  - Career row GP/GS columns merging visually
root_cause: ESPN API returns combined "made-attempted" format but parser looked for nonexistent separate labels; GS incorrectly multiplied by GP
affected_files:
  - gateway/src/providers/espnPlayerService.ts
  - gateway/src/db/repositories/playerRepository.ts
  - gateway/src/scripts/backfillPlayerSeasons.ts
  - XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift
---

## Problem

After PR #18 expanded the player profile from 6 to 22 stat columns, three bugs caused incorrect data:

1. **All shooting stats showed 0.0** — every season row had FG, FGA, 3PM, 3PA, FT, FTA as zero
2. **GS showed garbage values** — e.g., Devin Vassell 2023-24 showed GS=4216 instead of 62
3. **Backfill returned 0 players** — sport filter used wrong identifier

## Root Cause

### Bug 1: ESPN Combined Stat Format

ESPN's `/athletes/{id}/stats` endpoint returns shooting stats in combined "made-attempted" format:

```
Labels: ["GP", "GS", "MIN", "FG", "FG%", "3PT", "3P%", "FT", "FT%", "OR", "DR", "REB", ...]
Stats:  ["68", "62", "34.5", "6.7-16.1", ".416", "1.8-5.7", ".316", "2.2-2.6", ".846", ...]
```

The code was calling `stat('FGM')`, `stat('FGA')`, `stat('3PM')`, etc. — labels that don't exist in ESPN's response. The lookup returned 0 for every shooting stat.

### Bug 2: Games Started Multiplication

`upsertSeasonSummary` converts per-game averages to totals via a `total()` helper that multiplies by GP. GS was included in this conversion, but ESPN returns GS as a raw count (not per-game). Result: `62 * 68 = 4216`.

### Bug 3: Sport Filter Mismatch

The backfill SQL query used `WHERE p.sport = 'basketball'` but the database stores `'nba'`.

## Solution

### Fix 1: `parseCombinedStat()` Function

Added a parser that splits ESPN's combined format:

```typescript
export function parseCombinedStat(
  indexMap: Map<string, number>, stats: string[], label: string
): [number, number] {
  const idx = indexMap.get(label);
  if (idx === undefined || idx >= stats.length) return [0, 0];
  const val = stats[idx];
  if (!val) return [0, 0];
  const parts = val.split('-');
  if (parts.length !== 2) return [parseStatValue(val), 0];
  return [parseStatValue(parts[0]), parseStatValue(parts[1])];
}
```

Usage (both `fetchESPNDetailedStats` and `fetchSeasonBySeasonStats`):

```typescript
const indexMap = buildIndexMap(averages.labels);
const stat = buildStatLookup(indexMap, stats);
const [fgm, fga] = parseCombinedStat(indexMap, stats, 'FG');
const [fg3m, fg3a] = parseCombinedStat(indexMap, stats, '3PT');
const [ftm, fta] = parseCombinedStat(indexMap, stats, 'FT');
```

The shared `buildIndexMap()` builds the label-to-index map once and reuses it across all lookups.

### Fix 2: GS Direct Pass-Through

```typescript
// Before (wrong): total(data.gamesStarted)  — multiplied by GP
// After (correct): data.gamesStarted         — already a count
[
  data.playerId, data.season, data.teamId, gp,
  data.gamesStarted, // GS is already a count, not per-game
  total(data.minutes),
  // ...
]
```

### Fix 3: Correct Sport Filter

```sql
WHERE p.sport = 'nba'  -- was 'basketball'
```

## Verification

- Backfill re-run: 478 players, 2,574 season rows, 0 errors
- TypeScript type-check passes
- 13 unit tests added covering `parseCombinedStat`, `buildIndexMap`, `parseStatValue`
- PR #19 merged to main

## Prevention

- **Unit test ESPN parsing**: The new test suite (`espnPlayerService.test.ts`) covers combined format, missing labels, out-of-bounds indices, empty values, and single-value fallback. Run these after any ESPN parsing changes.
- **Document ESPN label format**: ESPN uses `FG` (not `FGM`/`FGA`), `3PT` (not `3PM`/`3PA`), `FT` (not `FTM`/`FTA`) with combined "made-attempted" values. This is not documented by ESPN.
- **Validate count vs. per-game fields**: Before applying `total()`, verify the field is actually a per-game average. GS, GP are counts; MIN, PTS, REB, AST are per-game.
- **Use consistent sport identifiers**: The database stores `'nba'`, not `'basketball'`. Any new queries filtering by sport should use the database value.
- **Post-backfill spot-check**: After running backfill, verify a known player's stats against ESPN's website (e.g., Vassell 2023-24: GP=68, GS=62, FG=6.7, FGA=16.1).

## Related Documentation

- [Backfill Write Path Data Gap (BOX-42)](../logic-errors/backfill-write-path-data-gap-box42.md)
- [Gateway Response Double Data Unwrap (BOX-39)](../integration-issues/gateway-response-double-data-unwrap.md)
- [Percentage Scale API Contract Inconsistency (BOX-37)](../integration-issues/percentage-scale-api-contract-inconsistency.md)
- [Player Routes Cleanup (BOX-40)](../refactoring/player-routes-cleanup-service-extraction.md)
