---
title: "Scheduled Player Game Log Ingestion from ESPN"
type: feat
date: 2026-02-01
linear: BOX-47
---

# Scheduled Player Game Log Ingestion from ESPN

## Overview

The game log UI (BOX-43) is built and working, but most players show empty game logs because the DB only contains 87 games (Jan 5–16). The ingestion code exists in `gateway/src/jobs/playerIngestion.ts` but is never called automatically. We need:

1. **Bug fixes** in the existing ingestion code (double ESPN fetch, rate limiter bypass)
2. **A scheduled job** that runs hourly to ingest player data from newly-finalized games
3. **A backfill mechanism** to populate the current season's historical games

## Problem Statement

- DB has 87 of ~700+ NBA games played this season (2025-26)
- Those 87 games DO have player game logs (ingested manually at some point)
- The other ~600+ games have no player data — any player who didn't play Jan 5–16 shows empty
- `ingestPlayersFromGame()` makes TWO ESPN API calls per game (double-fetch bug on lines 44 and 56 of `playerIngestion.ts`)
- Ingestion bypasses the ESPN rate limiter entirely (uses raw axios)
- Existing schedulers (`scheduleScheduleSync`, `scheduleNightlyMaterialization`) are also not wired into server startup

## Prerequisite: Games must be in PostgreSQL

The ingestion queries the `games` table in PostgreSQL, but only 87 games exist there currently. The `scheduleSync` job stores games in an in-memory `ScheduleStore` (JSON file), and may or may not also write to PostgreSQL.

**This must be investigated before any other work begins.** If `scheduleSync` does not reliably write to the `games` table, the hourly ingestion will find nothing to process and the backfill will find nothing to backfill.

**Verify:** Does `scheduleSync` write to the `games` table? The 87 games got there somehow — trace that code path and confirm it's reliable.

**Likely fix:** The schedule sync should upsert games into PostgreSQL as it processes them. If this isn't happening, it needs to happen first.

## Implementation

### Phase 1: Fix existing bugs in `playerIngestion.ts`

**File:** `gateway/src/jobs/playerIngestion.ts`

**Double-fetch bug (lines 42-64):** `ingestPlayersFromGame()` calls `espnAdapter.fetchBoxScore()` (line 44) and then immediately fetches the same data via raw axios (lines 55-62). The adapter result is never used. Fix: remove the adapter call, route the raw fetch through the ESPN rate limiter.

**Rate limiter bypass:** The raw axios call on line 56 bypasses `ESPNRateLimiter` entirely. Fix: use the rate limiter's `gameSummary` bucket (600/day budget) for all ingestion fetches. This is critical — without it, backfill could hammer ESPN with 600+ unthrottled requests.

**Approach:** Add a `fetchRawSummary(gameId: string): Promise<ESPNSummaryResponse>` method to the ESPN adapter that goes through the rate limiter but returns the raw summary JSON. This keeps rate limiting encapsulated in the adapter — the only place that should talk to ESPN. Define a proper return type, not `any`.

**Cleanup:** Remove the `getSportPath()` helper from `playerIngestion.ts` — it duplicates logic already in the ESPN adapter and won't be needed once the raw fetch is replaced with `fetchRawSummary()`. Also remove the `require('axios')` runtime import.

### Phase 2: Hourly scheduler, backfill endpoint, and wiring

**New file:** `gateway/src/jobs/schedulePlayerIngestion.ts`

**Scheduler pattern:** Follow the existing `scheduleScheduleSync.ts` pattern — `setTimeout` to next target time, then `setInterval` every hour.

**Logic each hour:**
1. Query `games` for NBA games with `status = 'final'` that have NO rows in `nba_player_game_logs` (LEFT JOIN check — no schema change needed)
2. For each un-ingested game, call `ingestPlayersFromGame()`
3. Log summary: X games processed, Y succeeded, Z failed
4. Failed games will be retried on the next hourly run (natural retry — no tracking needed since we check for missing game log rows each time)

**Ingestion tracking approach:** Query-based, not flag-based. Each run does:
```sql
SELECT g.id FROM games g
LEFT JOIN nba_player_game_logs gl ON gl.game_id = g.id
WHERE g.league_id = 'nba' AND g.status = 'final'
AND gl.game_id IS NULL
ORDER BY g.scoreboard_date DESC
```
This is simple, requires no schema change, and automatically retries failed games.

**Timing:** Run at :30 past each hour UTC. NBA games typically end between 22:00–00:00 Eastern (03:00–05:00 UTC). Running at :30 catches games that just finalized without colliding with the other schedulers (02:00 and 04:00 UTC).

**Backfill admin endpoint:**

**File:** `gateway/src/routes/adminRoutes.ts` (or new file if admin routes don't exist)

**Endpoint:** `POST /v1/admin/backfill/players`

**Parameters:**
- `league` (default: `"nba"`)
- `season` (default: current season, e.g., `2025`)
- `limit` (optional — process at most N games per invocation, default: 500)

**Behavior:**
1. Query un-ingested final games for the given league/season (same query as the scheduler)
2. Process up to `limit` games synchronously
3. Return `{ processed: N, failed: M, failedGameIds: [...] }` when complete
4. Log progress as games complete

The endpoint is synchronous — you call it, wait, get results. No background processing, no status polling. Increase the HTTP timeout if needed; this is an admin tool, not a user-facing API.

**Multi-day backfill:** With ~600 un-ingested games and a 500/day limit, the backfill takes 2 days. Run the endpoint on day 1, it processes 500. Run again on day 2, it processes the remaining ~100+. The query-based tracking means it automatically picks up where it left off.

**Deferred recomputation:** During backfill, skip per-game `recomputeSeasonSummary()` and `recomputeNBASplits()` calls. After all games are ingested, do a single recomputation pass for all affected players. This avoids recomputing a player's stats 50 times when processing 50 of their games.

**Wire up all schedulers in `index.ts`:**

**File:** `gateway/src/index.ts`

Currently, `startServer()` initializes Redis and starts Express but never calls any scheduler. Wire up both:
1. `scheduleScheduleSync()` — existing, daily at 04:00 UTC
2. `schedulePlayerIngestion()` — new, hourly at :30

Note: `materializeGameDates()` exists as a function but has no scheduler wrapper — it only runs via the admin endpoint `POST /v1/admin/schedule/materialize`.

Add them after `app.listen()` with a log message for each.

## ESPN Rate Limit Budget

| Activity | Daily Calls | Bucket |
|----------|-------------|--------|
| Hourly ingestion (5-15 games/night) | ~15 | gameSummary (600/day) |
| Backfill (one-time, capped) | ~500 | gameSummary (600/day) |
| Normal app usage (box scores) | ~50-100 | gameSummary (600/day) |
| **Total typical day** | **~65-115** | **Well within budget** |
| **Backfill day** | **~550-615** | **Near limit — hence the 500 cap** |

## Edge Cases

- **Server restart mid-ingestion:** Query-based tracking means already-ingested games are skipped on restart. No checkpoint needed.
- **ESPN API outage:** Individual games fail, are logged, and retried on the next hourly run.
- **Game goes from live → final between runs:** Picked up on the next hourly check automatically.
- **Overtime/delayed finals:** Same — picked up whenever the game finally appears as `status='final'`.
- **Duplicate processing:** `upsertNBAGameLog()` uses `ON CONFLICT ... DO UPDATE`, so processing the same game twice is idempotent.
- **Backfill + hourly overlap:** Both use the same idempotent upsert path. If they overlap, some games get processed twice with no data corruption. The rate limiter prevents ESPN from being hammered.

## Acceptance Criteria

- [x] Double-fetch bug fixed — `ingestPlayersFromGame()` makes exactly one ESPN API call per game
- [x] All ESPN calls go through the rate limiter's `gameSummary` bucket
- [x] `fetchRawSummary()` returns a typed `ESPNSummaryResponse`, not `any`
- [x] `getSportPath()` and `require('axios')` removed from `playerIngestion.ts`
- [x] Hourly scheduler runs automatically on server startup
- [x] Un-ingested final games are detected and processed each hour
- [x] Failed games are retried on the next run
- [x] Two schedulers wired into `index.ts` (scheduleSync + playerIngestion; nightly materialization doesn't exist)
- [x] Admin endpoint `POST /v1/admin/backfill/players` exists and returns synchronously
- [x] Backfill processes up to 500 games per invocation (configurable via `limit`)
- [x] Backfill skips already-ingested games
- [x] Season summary recomputation deferred to after all games complete during backfill
- [x] Running backfill twice is safe (idempotent)
- [ ] Current season (2025-26) fully backfilled after 2 runs — **blocked:** requires games in PostgreSQL first (see BOX-48)

## Key Files

| File | Change |
|------|--------|
| `gateway/src/jobs/playerIngestion.ts` | Fix double-fetch, use rate limiter, remove `getSportPath()` |
| `gateway/src/jobs/schedulePlayerIngestion.ts` | New — hourly scheduler |
| `gateway/src/index.ts` | Wire up all three schedulers |
| `gateway/src/routes/adminRoutes.ts` | New or modified — backfill endpoint |
| `gateway/src/providers/espnAdapter.ts` | Add `fetchRawSummary()` method |

## Dependencies

- **BOX-43 (done)** — Game log UI is already built and waiting for data
- **Prerequisite investigation** — Must confirm games are reliably in PostgreSQL before the scheduler will work

## References

- Existing scheduler pattern: `gateway/src/jobs/scheduleSync.ts`
- ESPN rate limiter: `gateway/src/utils/ESPNRateLimiter.ts`
- Documented learning: `docs/solutions/integration-issues/espn-combined-stat-format-parsing-box42.md`
- Documented learning: `docs/solutions/logic-errors/backfill-write-path-data-gap-box42.md`
