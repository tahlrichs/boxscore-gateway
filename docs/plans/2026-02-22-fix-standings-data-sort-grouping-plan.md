---
title: Fix Standings Data, Sort Order, Conference Grouping
type: fix
date: 2026-02-22
---

# Fix Standings Data, Sort Order, Conference Grouping

## Overview

Three fixes for the Standings tab: deploy the real ESPN standings data, fix the sort order in Conference/Division tabs, and fix ESPN abbreviation mismatches that break division grouping.

## Problem Statement

1. **Data not flowing**: Production gateway still returns "not implemented" for standings. The ESPN integration was built (commit `2b1fcf7`) but lives on the feature branch — not deployed.
2. **Sort order wrong**: Conference/Division tabs show worst teams first. League tab is correct.
3. **Too many sections in Conference tab**: User sees more than 2 conference sections, likely caused by stale cached data or data inconsistencies.

## Proposed Solution

### Fix 1: Normalize ESPN abbreviations in gateway

ESPN uses non-standard abbreviations for 6 NBA teams. Normalize them in `espnAdapter.ts` before sending to iOS. This fixes division lookup AND team logo matching downstream.

| ESPN sends | Normalize to | Team |
|-----------|-------------|------|
| NY        | NYK         | Knicks |
| GS        | GSW         | Warriors |
| SA        | SAS         | Spurs |
| NO        | NOP         | Pelicans |
| UTAH      | UTA         | Jazz |
| WSH       | WAS         | Wizards |

```typescript
// gateway/src/providers/espnAdapter.ts — inside transformStandings()
private static readonly ABBREVIATION_MAP: Record<string, string> = {
  'NY': 'NYK',
  'GS': 'GSW',
  'SA': 'SAS',
  'NO': 'NOP',
  'UTAH': 'UTA',
  'WSH': 'WAS',
};

// In the team mapping:
const rawAbbrev = team.abbreviation || '';
const abbrev = ESPNAdapter.ABBREVIATION_MAP[rawAbbrev] || rawAbbrev;
```

### Fix 2: Change sort to winPct in Conference/Division tabs

Replace `rank`-based ascending sort with `winPct`-based descending sort. This matches the League tab and is reliable regardless of how `rank` is populated.

```swift
// StandingsViewModel.swift — groupByConference()
// BEFORE: grouped[conference] = teams.sorted { $0.rank < $1.rank }
// AFTER:
grouped[conference] = teams.sorted { $0.winPct > $1.winPct }

// StandingsViewModel.swift — groupByDivision()
// BEFORE: teams: divisions[divName]!.sorted { $0.rank < $1.rank }
// AFTER:
teams: divisions[divName]!.sorted { $0.winPct > $1.winPct }
```

### Fix 3: Deploy to production

Merge PR #30 to main → Railway auto-deploys → real ESPN standings data flows to the app. After deployment, user does pull-to-refresh to get fresh data (replacing any stale cache).

## Acceptance Criteria

- [ ] Production gateway returns real NBA standings (30 teams, current records)
- [ ] League tab: teams sorted by win% descending (best first)
- [ ] Conference tab: exactly 2 sections (Eastern Conference, Western Conference), 15 teams each, sorted by win% descending
- [ ] Division tab: 6 divisions across 2 conferences, 5 teams each, sorted by win% descending, no "Other" group
- [ ] Team logos display correctly for all 30 NBA teams
- [ ] ESPN abbreviations (NY, GS, SA, NO, UTAH, WSH) normalized before reaching iOS

## Implementation Steps

- [x] 1. Add abbreviation normalization map to `espnAdapter.ts` `transformStandings()` method
- [x] 2. Change Conference sort from `$0.rank < $1.rank` to `$0.winPct > $1.winPct` in `StandingsViewModel.swift`
- [x] 3. Change Division sort from `$0.rank < $1.rank` to `$0.winPct > $1.winPct` in `StandingsViewModel.swift`
- [x] 4. Test gateway locally: `curl localhost:3001/v1/standings?league=nba` — verify 30 teams, normalized abbreviations
- [ ] 5. Commit changes to feature branch
- [ ] 6. Merge PR #30 to main (triggers Railway deploy)
- [ ] 7. Verify production: `curl https://boxscore-gateway-production.up.railway.app/v1/standings?league=nba`
- [ ] 8. Build and run iOS app — verify all three tabs show correct data

## Files to Change

| File | Change |
|------|--------|
| `gateway/src/providers/espnAdapter.ts` | Add `ABBREVIATION_MAP` + use in `transformStandings()` |
| `XcodProject/BoxScore/BoxScore/Features/Standings/StandingsViewModel.swift` | Lines 206, 236: change sort from rank to winPct |

## References

- Brainstorm: `docs/brainstorms/2026-02-22-standings-data-sort-grouping-fixes-brainstorm.md`
- BOX-55 solution: `docs/solutions/ui-bugs/standings-duplicate-picker-grouping-filter-box55.md`
- ESPN API: `https://site.api.espn.com/apis/v2/sports/basketball/nba/standings`
- PR #30: feature branch `ahlrichstim/box-55-standings-conference-division-filter`
