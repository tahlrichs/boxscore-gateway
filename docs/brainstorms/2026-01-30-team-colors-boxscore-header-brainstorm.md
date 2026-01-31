# Team Colors on Box Score Header Bar

**Date:** 2026-01-30

## What We're Building

Apply each team's primary color as the background of the box score dropdown header bar (currently hardcoded black). This requires serving team color data from the gateway and fetching it in the iOS app.

**Single issue** — data delivery and UI change are tightly coupled.

## Key Decisions

1. **Data delivery**: New `GET /v1/team-colors` endpoint on the gateway, serving `teamColors.json`. iOS fetches once and caches.
2. **UI change**: Replace `Color.black` background on the team header bar in `GameCardView.swift` (line 237) with the team's primary color.
3. **Text contrast**: Always white text. No auto-contrast logic.
4. **Scope**: NBA only initially (that's what box scores currently support), but the endpoint serves all leagues for future use.

## What Exists

- `gateway/src/data/teamColors.json` — 486 teams with `primary`, `secondary`, `name` fields keyed by abbreviation
- `Theme.swift` — already has `Color(hex:)` initializer
- `GameCardView.swift:237` — the `.background(Color.black)` line to change
- Team abbreviations in game data (e.g. `lal`, `bos`) match the JSON keys

## Open Questions

None — ready for planning.

## Next Step

Run `/workflows:plan` to create the implementation plan.
