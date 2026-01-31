---
title: "feat: Team primary color on box score header bar"
type: feat
date: 2026-01-30
---

# feat: Team primary color on box score header bar

## Overview

Replace the hardcoded black background on the box score team header bar with each team's primary color. The Lakers header should be purple, the Bulls red, the Celtics green, etc.

## Data Source: teamColors.json

Use the curated `teamColors.json` (scraped from TruColor.net, 486 teams) served via a new gateway endpoint. ESPN provides colors on `TeamInfo.primaryColor` but we use the curated JSON for color accuracy and secondary color availability.

## Proposed Solution

### 1. Gateway: New `GET /v1/team-colors` endpoint

Serve `gateway/src/data/teamColors.json` as a static JSON response.

- Read the JSON file once at startup, strip `_meta` key, serve from memory
- Fail fast at startup if JSON file is missing
- Add `Cache-Control: max-age=86400` header (data is static)
- Follow existing route pattern in [gateway/src/routes/](gateway/src/routes/)

### 2. iOS: Fetch colors in HomeViewModel

Add ~15 lines directly to [HomeViewModel.swift](XcodProject/BoxScore/BoxScore/Features/Home/HomeViewModel.swift):

- A `teamColors: [String: [String: [String: String]]]` dictionary property (league → abbreviation → color fields)
- A `loadTeamColors()` async function called once on launch (fire-and-forget — falls back to black if not yet loaded)
- A `teamColor(for:league:)` lookup function returning a `Color`, defaulting to black

No separate repository or model file — the data is a simple dictionary.

### 3. UI: Apply color to box score header bar

- In [GameCardView.swift:237](XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift#L237), replace `.background(Color.black)` with the team's primary color via the view model lookup
- Look up by team abbreviation (lowercased) and league
- `Color(hex:)` already exists in [Theme.swift:170](XcodProject/BoxScore/BoxScore/Core/Config/Theme.swift#L170), falls back to black on invalid input
- Update stale comment on line 228

## Edge Cases

| Scenario | Behavior |
|---|---|
| Team not found in JSON | Fall back to black (current behavior) |
| Color fetch hasn't completed yet | Fall back to black |
| Color fetch fails (offline) | Fall back to black |
| Light primary color (e.g. yellow) | White text stays — accepted trade-off |
| Abbreviation case mismatch | Lowercase before lookup (ESPN sends "ATL", JSON keys are "atl") |
| JSON file missing at gateway startup | Fail fast with clear error |

## Acceptance Criteria

- [x] New `GET /v1/team-colors` endpoint serves `teamColors.json` (without `_meta`)
- [x] Gateway fails fast if JSON file is missing at startup
- [x] iOS fetches colors once on app launch via HomeViewModel
- [x] Box score team header bar background uses team's primary color
- [x] Falls back to black when color is unavailable
- [x] White text remains on all headers

## Files to Change

| Area | File | Change |
|---|---|---|
| Gateway | New `routes/teamColors.ts` | Endpoint serving JSON (strip `_meta`, fail fast) |
| Gateway | [index.ts](gateway/src/index.ts) | Register new route |
| iOS | [GatewayEndpoints.swift](XcodProject/BoxScore/BoxScore/Core/Networking/GatewayEndpoints.swift) | Add `teamColors` case |
| iOS | [HomeViewModel.swift](XcodProject/BoxScore/BoxScore/Features/Home/HomeViewModel.swift) | Add color fetch + lookup (~15 lines) |
| iOS | [GameCardView.swift:237](XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift#L237) | Use team color for background |

## References

- Brainstorm: [docs/brainstorms/2026-01-30-team-colors-boxscore-header-brainstorm.md](docs/brainstorms/2026-01-30-team-colors-boxscore-header-brainstorm.md)
- Color data: [gateway/src/data/teamColors.json](gateway/src/data/teamColors.json)
- Hex color parser: [Theme.swift:170](XcodProject/BoxScore/BoxScore/Core/Config/Theme.swift#L170)
- Route pattern: [gateway/src/routes/teams.ts](gateway/src/routes/teams.ts)
- Endpoint pattern: [GatewayEndpoints.swift](XcodProject/BoxScore/BoxScore/Core/Networking/GatewayEndpoints.swift)
