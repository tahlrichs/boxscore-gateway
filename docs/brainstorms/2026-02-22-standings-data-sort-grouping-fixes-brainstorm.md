# Standings Fixes — Real Data, Sort Order, Conference Grouping

**Date**: 2026-02-22
**Linear**: BOX-57 (3 sub-issues)
**Status**: Ready to plan

## What We're Fixing

Three issues with the Standings tab:

1. **Real data not flowing** — The ESPN standings implementation (from last session) lives on the feature branch but was never deployed to production. The production gateway still returns "not implemented," so the app shows stale cached/mock data.

2. **Sort order wrong in Conference/Division tabs** — League tab correctly shows best teams first (sorts by win%). Conference and Division tabs sort by `rank` ascending, which *should* work but the user sees worst teams at top. Switching to win% sort (same as League) is safer and more consistent.

3. **Conference tab showing too many sections** — Should show exactly 2 sections for NBA (Eastern Conference, Western Conference, 15 teams each). User sees more than 2 sections, suggesting the `conference` field has unexpected values in the cached data.

## Why This Matters

The Standings tab UI (from BOX-55) is fully built — logos, segmented picker, League/Conference/Division grouping all look great. But the data powering it is wrong: frozen mock records, backwards sort order, and broken grouping make it unusable.

## Root Cause Analysis

### Issue 1: Data not flowing

- The production gateway at `boxscore-gateway-production.up.railway.app` still throws "Standings not yet implemented"
- The new `fetchStandings()` code in `espnAdapter.ts` was committed to the feature branch but PR #30 hasn't been merged to main → Railway auto-deploys from main
- ESPN API confirmed working: returns 2 conferences, 15 teams each, with wins/losses/winPct/playoffSeed/streak

### Issue 2: Sort order

- League tab: `standings.sorted { $0.winPct > $1.winPct }` → best first ✅
- Conference tab: `teams.sorted { $0.rank < $1.rank }` → ascending by playoffSeed
- Division tab: same rank-based sort
- The rank-based sort depends on `playoffSeed` being populated correctly. With mock data, rank = array index + 1. With real ESPN data, rank = playoffSeed (1 = best). Both should sort correctly, BUT using winPct is more reliable and matches League tab behavior.

### Issue 3: Conference showing too many sections

- `groupByConference()` groups standings by `standing.conference` field
- With mock data: conference = "Eastern" / "Western" → 2 groups
- With real ESPN data: conference = "Eastern Conference" / "Western Conference" → 2 groups
- **Can't reproduce from code alone** — need to check on-device. Possible cause: stale cached data with unexpected conference values from a partial/failed fetch.

### Bonus: ESPN abbreviation mismatches

6 teams have different abbreviations between ESPN and the iOS division lookup table:

| ESPN | iOS Lookup | Team |
|------|-----------|------|
| NY   | NYK       | Knicks |
| GS   | GSW       | Warriors |
| SA   | SAS       | Spurs |
| NO   | NOP       | Pelicans |
| UTAH | UTA       | Jazz |
| WSH  | WAS       | Wizards |

These mismatches mean division lookup fails for 6/30 teams → they'd fall into "Other" division, potentially creating extra sections.

## Chosen Approach

### Fix 1: Deploy gateway

Merge PR #30 to main → Railway auto-deploys → real ESPN standings data flows to the app.

### Fix 2: Sort by winPct everywhere

Change Conference and Division tab sorting from `rank`-based to `winPct`-based (descending). This is consistent with the League tab and doesn't depend on rank being populated.

### Fix 3: Fix abbreviation mismatch

Update the iOS division lookup table to include ESPN's abbreviations as aliases. This ensures all 30 teams get proper division assignments.

### Fix 4: Verify conference grouping on-device

After deploying real data, verify the Conference tab shows exactly 2 sections. If the issue persists, investigate the cached data.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Sort by winPct, not rank | Consistent with League tab, more reliable, doesn't depend on ESPN's playoffSeed |
| Fix abbreviations in iOS lookup | The gateway sends ESPN's abbreviations; iOS should understand them |
| Deploy by merging PR | Railway auto-deploys from main — simplest path |
| Clear app cache after deploy | Ensures stale data doesn't persist |

## Scope

### In scope
- Merge PR #30 to deploy gateway standings code
- Fix Conference/Division sort order in StandingsViewModel.swift
- Fix ESPN abbreviation mismatches in StandingsViewModel.swift division lookup
- Verify conference grouping on-device

### Out of scope
- NFL/NHL/MLB standings (future work)
- `lastTen` stat (not available from ESPN)
- Redesigning the standings UI

### Files to change
- `StandingsViewModel.swift` — sort order + abbreviation lookup table
- No gateway changes needed (already implemented)

## Open Questions

1. Does Railway auto-deploy from main? Need to confirm before merging.
2. Will clearing the iOS simulator's cache resolve the "too many sections" issue?
