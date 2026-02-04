# Empty Box Scores on Jan 31st

**Date:** 2026-02-03
**Status:** Ready for plan

## What We're Building

A fix for corrupted box score cache files and a guard to prevent this from happening again.

## The Problem

Games from Saturday Jan 31st show "No box score available" even though they display "FINAL" with real scores in the game cards.

### Symptoms
- Tapping to expand box score shows "No box score available" immediately (no loading spinner)
- Affects multiple NBA games on Jan 31st specifically
- Other days work fine

### Root Cause

**Race condition in ESPN API timing:**

1. The gateway fetched box scores when ESPN's API reported `status: "final"`
2. ESPN had not yet populated the player statistics at that moment
3. The gateway's `storeBoxScore()` function only checks `status === "final"` before saving permanently
4. Empty box scores (with `starters: []` and `score: 0`) were permanently stored to `gateway/data/boxscores/`
5. Now the iOS app receives cached empty data immediately on every request

### Evidence

Corrupted files found in `gateway/data/boxscores/`:
- `nba_401810507.json` - stored at 2026-01-26T01:10:12Z with empty starters
- `nba_401810506.json` - stored at 2026-01-26T01:09:28Z with empty starters

Good files for comparison:
- `nba_401810505.json` - stored at 2026-01-26T00:24:03Z with 827 lines (full player data)

## Why This Approach

### Approach A: Delete Corrupted Files
- **Immediate fix** - Games will work again on next request
- Minimal risk - just removing bad cache, fresh data will be fetched from ESPN
- Fast to implement

### Approach B: Add Validation Guard
- **Prevents recurrence** - Empty box scores won't be permanently stored
- Check `starters.length > 0` (for NBA) before calling `storeBoxScore()`
- Could log warnings for observability

### Decision: Both approaches

Fix the current issue AND prevent it from happening again. This is the right long-term choice.

## Key Decisions

1. **Delete strategy:** Remove files where `starters: []` AND `status: "final"` - these are corrupted
2. **Validation location:** Add check in `games.ts` route before calling `storeBoxScore()`
3. **Validation logic:** For NBA, require `homeTeam.starters.length > 0` to be considered valid

## Open Questions

None - approach is clear.

## Next Steps

Run `/workflows:plan` to create the implementation plan.
