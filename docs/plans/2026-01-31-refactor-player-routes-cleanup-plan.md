---
title: "refactor: Player routes cleanup (from BOX-37 code review)"
type: refactor
date: 2026-01-31
linear: BOX-40
---

# ♻️ refactor: Player Routes Cleanup

## Overview

Code review findings from BOX-37 (stat-central endpoint) that are out of scope for the initial PR but should be addressed. The player routes file (`playerRoutes.ts`, 586 LOC) has accumulated inline logic, dead code, and duplicated patterns that need cleanup.

## Problem Statement

1. **Bloated route handler** — The stat-central handler has ~130 lines of inline merge/transform logic that belongs in a service layer
2. **Dead code** — 4 stub 501 endpoints (~130 LOC) and an unused `getCareerSummaries` function serve no purpose
3. **Duplicated logic** — `getCurrentSeason()` is duplicated in 3 files; two ESPN fetchers overlap significantly
4. **Missing safeguards** — No ILIKE character escaping in search, no `pg_trgm` index for performance, no player-specific rate limiting
5. **Minor code smells** — `SELECT *` in repository, `seasonLabel()` in wrong file, hardcoded `source: 'espn'` in response

## Proposed Solution

Two-phase refactor: Phase 1 tackles high-value structural cleanup (service extraction, dead code removal, deduplication). Phase 2 handles safeguards and nice-to-haves.

---

## Phase 1: Structural Cleanup (P2)

### 1.1 Extract stat-central logic into service layer

**File to create:** `gateway/src/services/playerStatCentralService.ts`

Extract lines 101-229 of [playerRoutes.ts](gateway/src/routes/playerRoutes.ts) into a service function:

```typescript
// gateway/src/services/playerStatCentralService.ts

interface StatCentralResult {
  bio: PlayerBio;
  seasons: SeasonRow[];
  career: SeasonRow | null;
}

export async function buildStatCentral(playerId: string): Promise<StatCentralResult> {
  // 1. Parallel fetch: player bio, historical seasons, ESPN data
  // 2. Merge DB + ESPN seasons (ESPN wins for current season, DB for historical)
  // 3. Compute career averages (ESPN preferred, fallback to aggregation)
  // 4. Apply percentage conversion (DB 0-1 → API 0-100)
}
```

**Design decisions:**
- Service throws exceptions; route error middleware converts to HTTP responses
- Service does NOT handle caching — that stays in the route layer
- Service accepts `playerId` (string UUID), fetches its own data
- Returns domain objects, not HTTP DTOs

**Files affected:**
- [playerRoutes.ts:101-229](gateway/src/routes/playerRoutes.ts#L101-L229) — extract logic
- New: `gateway/src/services/playerStatCentralService.ts`

### 1.2 Remove 4 stub 501 endpoints

These endpoints return 501 and serve no purpose. The iOS client does not call them.

| Endpoint | Lines |
|----------|-------|
| `GET /:id/season/:season/summary` | [332-366](gateway/src/routes/playerRoutes.ts#L332-L366) |
| `GET /:id/season/:season/gamelog` | [375-402](gateway/src/routes/playerRoutes.ts#L375-L402) |
| `GET /:id/season/:season/splits` | [411-437](gateway/src/routes/playerRoutes.ts#L411-L437) |
| `GET /:id/career/summary` | [446-461](gateway/src/routes/playerRoutes.ts#L446-L461) |

~130 LOC removed.

### 1.3 Consolidate duplicate ESPN fetchers

`fetchESPNDetailedStats` ([espnPlayerService.ts:290-374](gateway/src/providers/espnPlayerService.ts#L290-L374)) and `fetchSeasonBySeasonStats` ([espnPlayerService.ts:401-492](gateway/src/providers/espnPlayerService.ts#L401-L492)) both:
- Call the same ESPN `/stats` endpoint
- Parse `categories.find(c => c.name === 'averages')`
- Handle labels/statistics arrays

**Approach:** Extract shared parsing into helper functions. Keep the two functions but eliminate duplicated parsing logic (~85 LOC savings). Don't merge into one function — different return types serve different callers.

```typescript
// Shared helper
function parseESPNStatCategories(statsData: any): { labels: string[]; seasonEntries: any[] } { ... }

// fetchESPNDetailedStats uses it for single most-recent season
// fetchSeasonBySeasonStats uses it for all seasons + career row
```

### 1.4 Hoist ESPN ID lookup into Promise.all

Currently in [espnPlayerService.ts](gateway/src/providers/espnPlayerService.ts), `getStatCentralFromESPN` runs the ESPN ID lookup (`external_ids` table query) sequentially before fetching ESPN stats.

Move the ESPN ID lookup to the route-level `Promise.all` at [playerRoutes.ts:121-125](gateway/src/routes/playerRoutes.ts#L121-L125) so it runs in parallel with the player bio and historical seasons fetch. Saves ~10-20ms per cache miss.

```typescript
// Before: 3-way parallel, then sequential ESPN ID lookup
const [player, historicalSeasons, espnData] = await Promise.all([...]);

// After: 4-way parallel
const [player, historicalSeasons, espnId, ...] = await Promise.all([
  getPlayerById(playerId),
  getHistoricalSeasons(playerId),
  getESPNPlayerId(playerId),  // hoisted
  ...
]);
// Then fetch ESPN stats using espnId (if not null)
```

### 1.5 Replace `SELECT *` with explicit columns

[playerRepository.ts:675-684](gateway/src/db/playerRepository.ts#L675-L684) — `getHistoricalSeasons` uses `SELECT *` on `nba_player_season_summary`.

Only these columns are used by stat-central:
`season, team_id, games_played, ppg, rpg, apg, stl, fg_pct, ft_pct`

Replace with explicit column list.

### 1.6 Remove dead `getCareerSummaries` function

[playerRepository.ts:737-746](gateway/src/db/playerRepository.ts#L737-L746) — Never called anywhere. Delete it.

---

## Phase 2: Safeguards & Polish (P2/P3)

### 2.1 Escape ILIKE special characters (P2)

[playerRepository.ts:769](gateway/src/db/playerRepository.ts#L769) — The search endpoint doesn't escape `%` and `_` in user input.

```typescript
// Before
const searchPattern = `%${queryStr}%`;

// After
const escaped = queryStr.replace(/[%_\\]/g, '\\$&');
const searchPattern = `%${escaped}%`;
// SQL: WHERE display_name ILIKE $1 ESCAPE '\'
```

### 2.2 Add `pg_trgm` GIN index on `display_name` (P2)

New migration file: `gateway/src/db/migrations/006_player_search_index.sql`

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX CONCURRENTLY idx_players_display_name_trgm
  ON players USING gin (display_name gin_trgm_ops)
  WHERE is_active = true;
```

Partial index (active players only) keeps it lean.

### 2.3 Add rate limiting to player endpoints (P2)

The global `express-rate-limit` on `/v1` already exists ([index.ts:42-49](gateway/src/index.ts#L42-L49)). For ESPN quota protection, assign player stat-central to a dedicated `ESPNRateLimiter` bucket:

```typescript
// In ESPNRateLimiter bucket allocation
playerStats: 300,  // 300 ESPN calls/day for player endpoints
```

No additional HTTP rate limiter needed — the global one covers abuse prevention.

### 2.4 Extract `getCurrentSeason()` to shared utility (P3)

Duplicated in:
- [playerRoutes.ts:468-476](gateway/src/routes/playerRoutes.ts#L468-L476)
- [backfillPlayerSeasons.ts:87-91](gateway/src/scripts/backfillPlayerSeasons.ts#L87-L91) (as `getCurrentSeasonYear`)
- [espnPlayerService.ts:515-516](gateway/src/providers/espnPlayerService.ts#L515-L516) (inline)

Create `gateway/src/utils/seasonUtils.ts`:

```typescript
export function getCurrentSeason(): number {
  const now = new Date();
  return now.getMonth() >= 9 ? now.getFullYear() : now.getFullYear() - 1;
}

export function seasonLabel(season: number): string {
  const nextYear = (season + 1) % 100;
  return `${season}-${nextYear.toString().padStart(2, '0')}`;
}
```

This also addresses **2.5 Move `seasonLabel()` from types file** (currently in [statCentral.ts:50-53](gateway/src/types/statCentral.ts#L50-L53)).

### 2.6 Remove `source: 'espn'` from `/:id` meta response (P3)

Hardcoded string that provides no value to the client. Remove from the player header endpoint response.

### 2.7 Add singleflight for cache miss thundering herd (P3)

Use an in-memory Map to deduplicate concurrent stat-central requests for the same player:

```typescript
const inflight = new Map<string, Promise<StatCentralResult>>();

async function getOrBuild(playerId: string): Promise<StatCentralResult> {
  if (inflight.has(playerId)) return inflight.get(playerId)!;
  const promise = buildStatCentral(playerId);
  inflight.set(playerId, promise);
  try { return await promise; } finally { inflight.delete(playerId); }
}
```

### 2.8 Batch upserts in backfill script (P3)

[backfillPlayerSeasons.ts](gateway/src/scripts/backfillPlayerSeasons.ts) currently does N individual INSERTs per player. Switch to multi-row INSERT with 50-row batches for better performance.

---

## Acceptance Criteria

### Phase 1
- [ ] `playerStatCentralService.ts` exists and handles all merge/transform logic
- [ ] `playerRoutes.ts` stat-central handler delegates to service (< 30 lines in route)
- [ ] 4 stub 501 endpoints removed
- [ ] ESPN fetcher parsing logic deduplicated
- [ ] ESPN ID lookup runs in parallel with other fetches
- [ ] `getHistoricalSeasons` uses explicit column list
- [ ] `getCareerSummaries` removed
- [ ] Existing tests pass, stat-central endpoint returns same response as before

### Phase 2
- [ ] ILIKE special characters escaped in search
- [ ] `pg_trgm` index migration created and applied
- [ ] Player endpoints assigned ESPN rate limiter bucket
- [ ] `getCurrentSeason()` extracted to shared utility, all 3 callsites updated
- [ ] `seasonLabel()` moved to `utils/seasonUtils.ts`
- [ ] `source: 'espn'` removed from player header response
- [ ] Singleflight prevents duplicate ESPN calls for same player
- [ ] Backfill script uses batch upserts

## Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Service extraction introduces regression | Compare API responses before/after with same test payloads |
| Percentage conversion bugs during refactor | Maintain existing convention: DB 0-1, API 0-100. Add inline comments |
| ESPN fetcher consolidation breaks callers | Keep function signatures unchanged, only extract internal helpers |
| `pg_trgm` index slows inserts during backfill | Use `CREATE INDEX CONCURRENTLY`, run `ANALYZE` after backfill |

## Institutional Learnings Applied

- **Percentage scale convention** ([docs/solutions](docs/solutions/integration-issues/percentage-scale-api-contract-inconsistency.md)): DB stores 0-1 decimal, gateway converts to 0-100 for API responses
- **Gateway response unwrap** ([docs/solutions](docs/solutions/integration-issues/gateway-response-double-data-unwrap.md)): Service returns domain objects, not wrapped DTOs
- **Service layer pattern** ([docs/solutions](docs/solutions/code-quality-issues/box-25-centralize-auth-sign-in-through-authmanager.md)): Centralized service throws exceptions, callers handle mapping

## References

- Linear: [BOX-40](https://linear.app/boxscores/issue/BOX-40)
- Related: BOX-37, BOX-39
- PR: #14
