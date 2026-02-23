# ESPN Standings — Real Data Integration

**Date**: 2026-02-22
**Linear**: BOX-56 (tentative)
**Status**: Ready to plan

## What We're Building

Wire up real NBA standings data from ESPN's public API. Currently, the gateway's `fetchStandings()` is a stub that throws an error ("Phase 2 implementation"), so the iOS app either shows stale cached mock data or errors out. The win/loss records are frozen and don't reflect actual NBA standings.

## Why This Matters

The Standings tab (BOX-55) looks great now with logos, League/Conference/Division grouping, and the segmented picker — but the numbers are wrong. Users see outdated hardcoded records instead of real standings.

## The ESPN API

**Endpoint**: `https://site.api.espn.com/apis/v2/sports/basketball/nba/standings`

**Response structure**:
```
{
  children: [
    {
      name: "Eastern Conference",
      standings: {
        season: 2026,
        seasonDisplayName: "2025-26",
        entries: [
          {
            team: { id, abbreviation, displayName, logos: [...] },
            stats: [
              { name: "wins", value: 15.0, displayValue: "15" },
              { name: "losses", value: 42.0, displayValue: "42" },
              { name: "winPercent", value: 0.263, displayValue: ".263" },
              { name: "gamesBehind", value: 28.0, displayValue: "28" },
              { name: "playoffSeed", value: 15.0, displayValue: "15" },
              { name: "streak", value: -2.0, displayValue: "L2" },
              { name: "differential", ... },
              { name: "avgPointsFor", ... },
              { name: "avgPointsAgainst", ... },
              ...
            ]
          }
        ]
      }
    },
    { name: "Western Conference", ... }
  ]
}
```

**Key observations**:
- Stats are a flat array — find by `name` to extract values
- `playoffSeed` = our `rank`
- `streak` displayValue gives "W2", "L3", etc.
- No `lastTen` stat available — skip or omit
- 15 teams per conference (30 total)
- Free, no API key needed
- Same URL pattern works for other sports: `sports/{sport}/{league}/standings`

## Chosen Approach

**Gateway-only change.** Implement `fetchStandings()` in `espnAdapter.ts` to:

1. Fetch ESPN standings API
2. Parse `children` → conferences, `entries` → teams
3. Extract stats by name into our `Standing` interface
4. Map `playoffSeed` → `rank`, `streak.displayValue` → `streak`
5. Return as `StandingsResponse` (conferences → teams format)

**No iOS changes needed** — the app already parses `StandingsResponse` correctly.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Gateway-only, no iOS changes | iOS already has full standings UI from BOX-55. Just need real data to flow. |
| NBA first, other leagues later | User explicitly said "stick with NBA for now." |
| Skip `lastTen` | Not in ESPN standings response. Could add later via box score calculation. |
| Use `playoffSeed` as rank | ESPN provides seed which is the natural ranking within conference. |
| Keep mock data as fallback | If ESPN is down, mock data still works when `useMockData = true`. |
| Standard cache TTL | Standings cached for 18 hours per existing config — fine for standings that change once per game. |

## Scope

- **In scope**: Implement `fetchStandings()` for NBA in `espnAdapter.ts`
- **Out of scope**: NFL/NHL/MLB standings (future work), `lastTen` calculation, iOS changes
- **File to change**: `gateway/src/providers/espnAdapter.ts` (one file)

## Open Questions

None — approach is clear. Ready for `/workflows:plan`.
