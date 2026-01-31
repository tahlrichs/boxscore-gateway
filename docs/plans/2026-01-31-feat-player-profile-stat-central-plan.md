---
title: "feat: Player Profile Stat Central Tab"
type: feat
date: 2026-01-31
linear: BOX-37
brainstorm: docs/brainstorms/2026-01-31-player-profile-stat-central-brainstorm.md
reviewed: true
---

# Player Profile — Stat Central Tab

## Overview

Redesign the NBA Player Profile page to match the new design. When a user taps a player name (from a box score or search), they see a profile with a **Stat Central** tab showing headline stats and a season-by-season stats table with expand/collapse for historical seasons.

**Scope:** NBA only. Stat Central tab only (Bio and News tabs show "coming soon" placeholders). Game Splits, Game Log, and Advanced sub-tabs are separate future issues.

## Issue Split

This plan is implemented across **two Linear issues**:

| Issue | Scope | Phase in this plan |
|-------|-------|--------------------|
| **BOX-37: Gateway stat-central endpoint + backfill** | New `/stat-central` route, TypeScript interfaces, ESPN season-by-season parsing, Supabase query, Redis cache, backfill script | Phase 1 |
| **BOX-39: iOS Stat Central view redesign** | New Swift models, view model, full PlayerProfileView redesign with tabs, table, expand/collapse | Phase 2 (depends on BOX-37) |

BOX-39 depends on BOX-37 being deployed — the iOS app needs the gateway endpoint to exist.

## Proposed Solution

### What the user sees

1. **Header:** Team name (with back button), player photo, name + jersey number, position, college, hometown, draft info
2. **Three top tabs:** Bio | **Stat Central** (selected, pill style) | News
3. **Headline stats:** 4 large numbers — PPG, RPG, APG, SPG (derived from current season row)
4. **Season Stats table:**
   - Current season row (bold/white text)
   - Previous season row (normal text)
   - One older season row (faded ~50% opacity, "peek" to hint more data)
   - Career averages row
   - "Show earlier seasons" toggle expands to reveal full history
   - Columns: SEASON, GP, PPG, RPG, APG, FG%, FT%
5. **Mid-season trades:** Show separate rows per team within a season (e.g., "2025-26 LAL" and "2025-26 BKN"), plus a TOTAL row

### Data strategy

- **Single gateway endpoint** `GET /v1/players/:id/stat-central` returns ALL seasons in one response (no two-phase loading)
- **Historical seasons** (completed seasons): stored permanently in Supabase `nba_player_season_summary` table, populated by backfill script run before launch
- **Current season + career:** fetched live from ESPN, merged with historical data
- **Cache:** 5-minute TTL on the full response in Redis. Simple, no per-request `is_player_live()` branching
- **No lazy backfill in the read path.** If a player is missing from Supabase, the endpoint returns only ESPN data (current season + career). The backfill script handles population.

### Data conventions

- **Percentages:** Always returned as 0-100 scale (e.g., `47.0` for 47.0% FG). The existing `/v1/players/:id` endpoint divides by 100 — this new endpoint will NOT do that, and the existing endpoint should be updated for consistency in a follow-up.
- **Season numbers:** Integer representing the start year (e.g., `2025` for 2025-26 season). Gateway generates the display label `"2025-26"`.
- **Per-game stats:** 1 decimal place (e.g., `29.2` PPG).
- **Trade rows:** For traded players, seasons array includes per-team rows AND a TOTAL row (where `teamAbbreviation` is `null`). The iOS app shows the TOTAL row by default and can expand to show per-team breakdown.

## Technical Approach

### Phase 1: Gateway Endpoint + Backfill Script

#### New TypeScript interfaces

```typescript
// gateway/src/types/statCentral.ts

interface StatCentralResponse {
  data: {
    player: StatCentralPlayer;
    seasons: SeasonRow[];    // sorted descending by season, then by team
    career: SeasonRow;
  };
  meta: {
    lastUpdated: string;     // ISO 8601
  };
}

interface StatCentralPlayer {
  id: string;
  displayName: string;
  jersey: string;
  position: string;
  teamName: string;
  teamAbbreviation: string;
  headshot: string | null;
  college: string | null;
  hometown: string | null;
  draftSummary: string | null;  // "2020 · Round 1 · Pick 21" or null if undrafted
}

interface SeasonRow {
  seasonLabel: string;           // "2025-26" or "Career"
  teamAbbreviation: string | null; // null for TOTAL or career rows
  gamesPlayed: number;
  ppg: number;
  rpg: number;
  apg: number;
  spg: number;
  fgPct: number;                 // 0-100 scale
  ftPct: number;                 // 0-100 scale
}
```

#### New endpoint: `GET /v1/players/:id/stat-central`

**Files to modify/create:**

| File | Action |
|------|--------|
| `gateway/src/types/statCentral.ts` | NEW — TypeScript interfaces for request/response |
| [playerRoutes.ts](gateway/src/routes/playerRoutes.ts) | Add `/v1/players/:id/stat-central` route |
| [espnPlayerService.ts](gateway/src/providers/espnPlayerService.ts) | Add `fetchSeasonBySeasonStats()` — calls ESPN `/athletes/{espnId}` with `?enable=stats` to get the `statsSummary.statistics` array containing all seasons |
| [playerRepository.ts](gateway/src/db/repositories/playerRepository.ts) | Add `getHistoricalSeasons(playerId)` — queries `nba_player_season_summary WHERE team_id = 'TOTAL' OR team_id != 'TOTAL'` for all rows |
| [redis.ts](gateway/src/cache/redis.ts) | Add cache key: `playerStatCentral: (id: string) => \`player:stat-central:${id}\`` |

**Gateway logic flow:**

```
1. Validate :id parameter matches expected format
2. Check Redis cache → if hit, return cached response
3. In parallel (Promise.all):
   a. Fetch player bio from `players` table
   b. Fetch historical seasons from `nba_player_season_summary`
   c. Fetch current season + career from ESPN via fetchSeasonBySeasonStats()
4. Merge: historical from Supabase + current season from ESPN
5. Build response matching StatCentralResponse interface
6. Cache in Redis with 5-minute TTL
7. Return response
```

**Career averages:** ESPN's athlete endpoint includes career averages in the `statsSummary` response. The gateway extracts these directly rather than computing them locally.

**Headline stats:** Not a separate field in the response. The iOS app derives PPG/RPG/APG/SPG from the first season in the `seasons` array (current season). This avoids data duplication.

#### Backfill script: `gateway/src/scripts/backfillPlayerSeasons.ts`

- Queries all active NBA players from `players` table
- For each player: fetches ESPN season-by-season data, upserts into `nba_player_season_summary`
- One row per season per team (for traded players), plus a TOTAL row per season
- Concurrency: 3 players at a time, 500ms delay between batches
- Progress logging: `[142/450] Backfilled Tyrese Maxey (4 seasons)`
- Resumable: skips players who already have historical data (unless `--force` flag)
- Idempotent: uses ON CONFLICT upserts
- Run once before feature launch, re-run at end of each season

**Note:** No lazy backfill in the endpoint. If the backfill script missed a player, the endpoint returns ESPN-only data (current season + career). Re-run the script to fix gaps.

### Phase 2: iOS Models + View Redesign

**New/modified files:**

| File | Action |
|------|--------|
| [GatewayEndpoints.swift](XcodProject/BoxScore/BoxScore/Core/Networking/GatewayEndpoints.swift) | Add `.playerStatCentral(playerId:)` endpoint case |
| `Features/PlayerProfile/StatCentralModels.swift` | NEW — response models (separate from view file) |
| [PlayerProfileView.swift](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift) | Replace view + view model with new design |

#### iOS response models (`StatCentralModels.swift`)

```swift
struct StatCentralResponse: Codable, Sendable {
    let player: StatCentralPlayer
    let seasons: [SeasonRow]
    let career: SeasonRow
}

struct StatCentralPlayer: Codable, Sendable {
    let id: String
    let displayName: String
    let jersey: String
    let position: String
    let teamName: String
    let teamAbbreviation: String
    let headshot: String?
    let college: String?
    let hometown: String?
    let draftSummary: String?   // pre-formatted: "2020 · Round 1 · Pick 21"
}

struct SeasonRow: Identifiable, Codable, Sendable {
    let seasonLabel: String
    let teamAbbreviation: String?
    let gamesPlayed: Int
    let ppg: Double
    let rpg: Double
    let apg: Double
    let spg: Double
    let fgPct: Double
    let ftPct: Double

    var id: String { "\(seasonLabel)-\(teamAbbreviation ?? "total")" }
}
```

Three structs total. Headline stats derived from `seasons[0]`.

#### View redesign

**Tab structure:**
- Replace existing 4-tab enum (`Season/GameLog/Splits/Career`) with 3 tabs: `Bio`, `StatCentral`, `News`
- `StatCentral` is the default selected tab
- `Bio` and `News` show centered "Coming Soon" placeholder text

**Header section:**
- Team name centered at top with back chevron
- Player photo (`AsyncImage` with `person.circle.fill` placeholder) + name/number + position + college + hometown + draft summary
- Use `Theme.*` colors throughout (never system colors)

**Headline stats:**
- 4-column HStack derived from `seasons[0]`: PPG, RPG, APG, SPG
- Large font for number, small caps label below

**Season Stats table:**
- Column headers: SEASON, GP, PPG, RPG, APG, FG%, FT%
- Row styling:
  - Current season (first row): `.fontWeight(.bold)`, white text
  - Previous season: normal weight, white text
  - Peek season (one older): `.opacity(0.4)`, visual hint for more data
  - Career row: normal weight, white text, separated by subtle divider
- "Show earlier seasons" toggle with eye icon and chevron
- When expanded: all seasons visible at full opacity, TOTAL rows shown with per-team rows indented below
- Stats formatting: 1 decimal place (`String(format: "%.1f", value)`)

**Loading state:**
- Fixed-height (300pt) centered `ProgressView` (per documented learnings)
- `Theme.standardAnimation` for transitions

**Error state:**
- Network failure: Show error message with "Retry" button
- Graceful degradation: if ESPN is down but Supabase has data, show historical seasons only with a note that current stats are unavailable

**Edge cases:**
- Rookie (1 season): Show current season + career only. No previous/peek rows. Hide "Show earlier seasons" toggle.
- Retired player: Show most recent seasons. No "current season" distinction — all rows normal weight.
- Player with 0 GP current season (injured): Show 0 GP row with "--" for averages (cannot divide by 0 games).
- Missing headshot: Show `person.circle.fill` SF Symbol placeholder.
- Undrafted player: `draftSummary` is `null`, omit draft info line entirely.
- Traded mid-season: TOTAL row shown by default, per-team rows visible when "Show earlier seasons" is expanded.

## Acceptance Criteria

- [x] Tapping a player name from box score navigates to redesigned profile
- [x] Header shows player photo, name, number, position, college, hometown, draft info
- [x] Three top tabs visible: Bio (coming soon), Stat Central (active), News (coming soon)
- [x] Headline stats show PPG, RPG, APG, SPG for current season
- [x] Season Stats table shows current (bold) + previous (normal) + one older (faded) + career
- [x] "Show earlier seasons" toggle reveals full season history
- [x] Mid-season trades show separate rows per team
- [x] Rookie players show only current season + career
- [x] Missing headshots show placeholder avatar
- [x] Undrafted players don't show draft info
- [x] Loading state shows centered spinner at 300pt height
- [x] Error state shows retry button on network failure
- [x] Dark mode uses `Theme.*` colors throughout
- [x] Gateway caches response in Redis with 5-minute TTL
- [x] Gateway validates `:id` parameter format before querying
- [x] Historical seasons stored in Supabase via backfill script
- [x] Backfill script handles 450+ players with concurrency limiting and progress logging
- [x] All percentages use 0-100 scale consistently

## Dependencies & Risks

**Dependencies:**
- ESPN athlete API must provide season-by-season stats (confirmed — `statsSummary.statistics` array)
- Supabase `nba_player_season_summary` table exists (confirmed — migration 001)
- Backfill script must run successfully before feature launch

**Risks:**
- ESPN season-by-season data format may vary per player (mitigate: robust parsing with fallbacks, matching existing 4-strategy approach in `espnPlayerService.ts`)
- Backfill script may hit ESPN rate limits (mitigate: 500ms delays between batches, 3 concurrent)
- Players not in backfill get ESPN-only data (mitigate: re-run script, or manually trigger for specific players)

## References

### Internal
- Brainstorm: [2026-01-31-player-profile-stat-central-brainstorm.md](docs/brainstorms/2026-01-31-player-profile-stat-central-brainstorm.md)
- Current player profile: [PlayerProfileView.swift](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift)
- Gateway player routes: [playerRoutes.ts](gateway/src/routes/playerRoutes.ts)
- ESPN service: [espnPlayerService.ts](gateway/src/providers/espnPlayerService.ts)
- Player repository: [playerRepository.ts](gateway/src/db/repositories/playerRepository.ts)
- DB schema: [001_player_stats_tables.sql](gateway/src/db/migrations/001_player_stats_tables.sql)
- Cache policy: [CachePolicy.ts](gateway/src/cache/CachePolicy.ts)
- Theme colors: `Core/Config/Theme.swift`

### Learnings Applied
- Use `Theme.*` methods, never system colors ([dark-mode-card-contrast.md](docs/solutions/ui-bugs/dark-mode-card-contrast.md))
- Fixed-height loading placeholders with `Theme.standardAnimation` ([box-score-loading-placeholder.md](docs/solutions/ui-bugs/box-score-loading-placeholder.md))
- Fire-and-forget loading for non-critical data ([team-colors-static-json-endpoint.md](docs/solutions/integration-issues/team-colors-static-json-endpoint.md))
- Avoid stacked table headers ([redundant-stat-table-headers.md](docs/solutions/ui-bugs/redundant-stat-table-headers.md))

### Review Feedback Incorporated
- Removed two-phase loading — all seasons returned in one response
- Removed lazy backfill from read path — backfill script only
- Simplified cache to flat 5-minute TTL (no per-request `is_player_live()` branching)
- Removed `meta.source` field — client doesn't need backend implementation details
- Flattened Swift models from ~7 structs to 3 (inlined TeamRef, DraftInfo as pre-formatted string, headline derived from first season)
- Added TypeScript interfaces as source of truth for response contract
- Specified percentage convention (0-100 scale)
- Parallelized DB + ESPN fetches with Promise.all
- Added error handling strategy (retry button, graceful degradation)
- Models in separate file (`StatCentralModels.swift`), not inside view
- Added input validation on `:id` parameter
- Specified backfill script concurrency (3), delay (500ms), and resume strategy
