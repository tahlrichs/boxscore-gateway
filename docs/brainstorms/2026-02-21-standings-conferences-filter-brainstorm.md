# Standings Conferences & Filter — Brainstorm

**Date:** 2026-02-21
**Linear Issue:** BOX-55
**Status:** Brainstorm complete

## What We're Building

Fix two issues on the Standings tab:

1. **Remove duplicate sport selector** — StandingsView has its own pill-button sport picker that duplicates the HomeView's SportTabBar. Remove the standalone picker and use the shared SportTabBar.

2. **Add League / Conference / Division filter** — A segmented control below the SportTabBar that lets you toggle between three views of the standings data.

3. **Hide DateSelector on Standings tab** — The horizontal date scroll is irrelevant for standings and should only show on the Scores tab.

## Why This Approach

- **Shared SportTabBar** keeps the UI consistent across Scores and Standings tabs. One source of truth for selected sport eliminates confusion.
- **Segmented control** matches the existing PlayerProfile tab pattern (Bio | Stat Central | News) so it feels native to the app.
- **Three filter levels** (League → Conference → Division) give users progressively detailed views without overwhelming the interface.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Sport selector | Use shared HomeView SportTabBar | Eliminates duplicate buttons, single source of truth |
| Filter UI pattern | Segmented control (full-width tabs) | Matches PlayerProfile tab pattern already in the app |
| "League" view | Single flat list ranked 1–30 by win % | Clean, simple — no section headers needed |
| "Conference" view | Grouped by conference with pinned headers | Same as current behavior (Eastern, Western, etc.) |
| "Division" view | Two-level grouping: Conference → Division | e.g., Eastern > Atlantic, Central, Southeast |
| DateSelector | Hide on Standings tab | Standings aren't date-specific, removes clutter |
| Division backend data | Add to gateway as part of this work | Completes the feature end-to-end |

## Current State (Research Findings)

- **StandingsView** has its own `sportPicker` (pill buttons) independent of HomeView's `SportTabBar`
- **StandingsViewModel** groups by conference but has no user-selectable filter
- **Standing model** has `division: String?` field but it's always `nil` — gateway doesn't return division data
- **ESPN adapter** standings is marked "not yet implemented" — standings uses API-Sports or mock data
- **No segmented picker** exists anywhere in the app — all selection controls are custom button-based

## Scope

### In scope
- Remove StandingsView sport picker, sync with HomeViewModel's selectedSport
- Add segmented control with League / Conference / Division options
- Update StandingsViewModel with filter state and grouping logic
- Update gateway to return division data
- Hide DateSelector when Standings tab is active

### Out of scope
- Season selector
- Playoff standings / bracket views
- Wildcard / tiebreaker logic
- Standings for leagues that don't currently have data

## Open Questions

- Which sports support division data in our current providers? (NBA yes, NFL yes — others TBD)
- Should the selected filter persist when switching sports, or reset to Conference?
