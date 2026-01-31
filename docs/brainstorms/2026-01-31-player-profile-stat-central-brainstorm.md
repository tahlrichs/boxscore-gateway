# Player Profile Page — Stat Central Tab

**Date:** 2026-01-31
**Linear Issue:** BOX-37
**Status:** Brainstorm complete

## What We're Building

A redesigned Player Profile page focused on the **Stat Central** tab for NBA players. When a user taps a player's name (from a box score or search), they see:

1. **Player header:** Team name, player photo, name/number, position, college, hometown, draft info
2. **Three top tabs:** Bio | **Stat Central** (active) | News — only Stat Central is in scope
3. **Headline stats:** Current season PPG, RPG, APG, SPG displayed prominently
4. **Season Stats table:**
   - Current season row (bold/white)
   - Previous season row (normal)
   - One older season row (faded, acting as a "peek" to hint more data exists)
   - Career averages row
   - "Show earlier seasons" toggle to expand full history
   - Columns: SEASON, GP, PPG, RPG, APG, FG%, FT%
5. **Bottom sub-tabs** (Game Splits, Game Log, Advanced) are **out of scope** — will be follow-up issues

## Why This Approach

**Single gateway endpoint (Approach A):**
- One `GET /v1/players/:id/profile` call returns everything the Stat Central tab needs
- Gateway merges data from two sources:
  - **Historical seasons** (e.g. 2023-24, 2024-25): Stored in Supabase `nba_player_season_summary`, fetched once and never re-fetched
  - **Current season (2025-26) + Career averages**: Fetched live from ESPN, cached with shorter TTL (shorter during game time via `is_player_live`)
- iOS app makes one network call and renders — keeps client code simple
- Matches existing gateway-as-aggregator pattern

**Rejected: Multiple endpoints approach** — would add complexity to the iOS side with multiple network calls and loading state coordination, for no meaningful benefit at this scale.

## Key Decisions

1. **Scope: Stat Central tab only** — Bio and News tabs are future work
2. **Scope: Season Stats + headline only** — Game Splits, Game Log, Advanced sub-tabs are separate issues
3. **Data strategy: Hybrid** — Historical seasons in Supabase (permanent), current season + career from ESPN (cached)
4. **Single endpoint** — Gateway merges all data, iOS makes one call
5. **Season display: Match design exactly** — Current + previous year visible, one older year faded as peek, expand for rest
6. **NBA only** for this issue

## Open Questions

- How to populate historical season data in Supabase — bulk backfill script, or lazy-load on first profile view?
- Player headshot images — ESPN provides URLs, do we proxy them or use directly?
- What happens for rookies (only one season of data)?
- "Show earlier seasons" — does it expand inline or scroll?

## Existing Foundation

Already in the codebase:
- `PlayerProfileView.swift` + `PlayerProfileViewModel` with tab structure
- `PlayerProfileRoute` for navigation
- Gateway `playerRoutes.ts` with `/v1/players/:id` endpoint (basic stats)
- `espnPlayerService.ts` fetching from ESPN athlete API
- Supabase tables: `nba_player_season_summary`, `nba_player_career_summary`
- `is_player_live` database function for cache TTL decisions

## Next Steps

Run `/workflows:plan` to create an implementation plan covering:
1. Gateway endpoint changes (merge historical + live data)
2. Historical data population strategy
3. iOS view redesign to match the design
4. Cache strategy implementation
