---
title: "Serving static JSON data via gateway endpoint for iOS consumption"
category: integration-issues
module: Gateway, Features/Home
tags: [gateway, static-data, team-colors, SwiftUI, endpoint, caching]
symptoms:
  - Need to serve curated data file to iOS app
  - Want to avoid bundling large JSON in app binary
  - Need graceful fallback when data unavailable
date_solved: 2026-01-31
linear_issue: BOX-34
pr: "#13"
---

# Serving Static JSON Data via Gateway Endpoint

## Problem

Needed to display team primary colors on box score header bars (Lakers = purple, Bulls = red, etc.). The curated `teamColors.json` (486 teams from TruColor.net) lives in the gateway, but the iOS app needed to consume it.

Two options existed: use ESPN's built-in `TeamInfo.primaryColor` (already wired) or serve the curated JSON. The curated JSON was chosen for color accuracy.

## Root Cause

No mechanism existed to serve static data files from the gateway to the iOS app. The pattern needed to be established: read once at startup, serve from memory, cache aggressively.

## Solution

### Gateway: Static JSON endpoint pattern

**File:** `gateway/src/routes/teamColors.ts`

```typescript
import { Router, Request, Response } from 'express';
import * as fs from 'fs';
import * as path from 'path';

const dataPath = path.join(__dirname, '..', 'data', 'teamColors.json');

// Fail fast if JSON file is missing at startup
if (!fs.existsSync(dataPath)) {
  throw new Error(`teamColors.json not found at ${dataPath}`);
}

// Read once at startup, serve from memory
const teamColors = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));

export const teamColorsRouter = Router();

teamColorsRouter.get('/', (_req: Request, res: Response) => {
  res.set('Cache-Control', 'public, max-age=86400');
  res.json({ data: teamColors });
});
```

Key decisions:
- `readFileSync` at module load (before server accepts connections) — no async needed
- Fail fast with thrown error if file missing — don't start broken
- `Cache-Control: max-age=86400` — data changes at most once per season
- Wrap in `{ data: ... }` envelope to match existing API pattern

### iOS: Fire-and-forget fetch with fallback

**File:** `Features/Home/HomeViewModel.swift`

```swift
struct TeamColorEntry: Decodable {
    let primary: String
    let secondary: String
    let name: String
}

// In HomeViewModel:
private var teamColors: [String: [String: TeamColorEntry]] = [:]

// In init — separate Task so it doesn't block game loading
Task { await loadTeamColors() }
Task {
    await loadAvailableDates()
    await loadGames()
}

private func loadTeamColors() async {
    do {
        let colors: [String: [String: TeamColorEntry]] = try await GatewayClient.shared.fetch(.teamColors)
        teamColors = colors
    } catch {
        // Silently fail — header bars fall back to black
    }
}

func teamColor(for team: TeamInfo, in sport: Sport) -> Color {
    let league = sport.leagueId
    let abbrev = team.abbreviation.lowercased()
    guard let hex = teamColors[league]?[abbrev]?.primary else {
        return .black
    }
    return Color(hex: hex)
}
```

### Performance gotcha: parallel loading

Initially `loadTeamColors()` was awaited sequentially before `loadGames()`. This blocked game data loading behind a cosmetic fetch. Fix: put color loading in its own `Task` so games load immediately. The `@Observable` re-render handles the color fill-in automatically.

## Key Pattern: Abbreviation Case Mismatch

ESPN sends team abbreviations in uppercase (`"ATL"`, `"LAL"`), but teamColors.json keys are lowercase (`"atl"`, `"lal"`). Always `.lowercased()` before lookup.

## Prevention

- When adding static data endpoints, always read at startup and serve from memory — never read per-request
- Fire-and-forget fetches for cosmetic data should run in separate `Task` blocks to avoid blocking critical data
- When matching identifiers between different data sources, normalize case before comparison
- Use `Color(hex:)` extension (in `Theme.swift`) which falls back to black on invalid input — no crash risk

## Related

- Color data: `gateway/src/data/teamColors.json` (486 teams, scraped from TruColor.net)
- Hex color parser: `Core/Config/Theme.swift` line 170
- TruColor scraper: [docs/solutions/integration-issues/trucolor-scraper-html-parsing.md](trucolor-scraper-html-parsing.md)
- Linear: BOX-34
- Branch: `ahlrichstim/box-34-feat-team-primary-color-on-box-score-header-bar`
