# BoxScore Development Rules

This document contains rules and guidelines for the BoxScore app development. These rules ensure consistency and should be followed when making changes.

## Date Selection

### Available Dates
- **Only show dates with games**: The date picker should only display dates where games are actually scheduled, not the entire season range
- **Source**: Dates are fetched from `/v1/scoreboard/dates?league={league}` which returns only dates with `gameCount > 0`
- **Fallback**: If game dates aren't synced yet, fall back to the full season date range

### Season Ranges (2025-26)
| Sport | Season Start | Season End |
|-------|--------------|------------|
| NBA | Oct 4, 2025 | Jun 22, 2026 |
| NFL | Aug 1, 2025 | Feb 8, 2026 |
| NCAAF | Aug 23, 2025 | Jan 20, 2026 |
| NCAAM | Nov 4, 2025 | Apr 6, 2026 |
| NHL | Sep 21, 2025 | Jun 20, 2026 |

## Box Score Display Rules

### NBA Box Scores
- Show all players including those with 0 minutes
- **DNP Players (game final)**: Display "DNP - {reason}" or "DNP - COACH'S DECISION"
- **Players not yet entered (game in progress)**: Display "Has not entered the game"
- Show starters and bench sections separately

### College Basketball (NCAAM) Box Scores
- **Only show players who logged minutes**: Filter out any player with 0 minutes played
- Hide DNP section entirely for college games
- This differs from NBA because college rosters are larger and many players never see court time

### NFL Box Scores
- Group players by position category (Passing, Rushing, Receiving, etc.)
- Expandable sections for each category

### NHL Box Scores
- Show skaters and goalies separately
- Include scratches section

## Team Logos

### Naming Convention
- Asset names follow pattern: `team-{league}-{abbreviation}`
- Abbreviation is **lowercased** API abbreviation (e.g., `team-nba-lal`, `team-nfl-kc`)
- NCAA teams use API abbreviations, not custom names

### Logo Sources
- Pro leagues (NBA, NFL, NHL): ESPN CDN using team abbreviation
- College (NCAAF, NCAAM): ESPN CDN using team ID number, saved with API abbreviation

### Missing Logos
- If a logo asset doesn't exist, show empty/clear space (don't break layout)
- When adding new teams, download logo and generate asset catalog entry

## API Conventions

### Game IDs
- Format: `{league}_{provider_id}` (e.g., `nba_401810123`)
- Provider is typically ESPN

### Team Abbreviations
- Use API-provided abbreviations, not custom mappings
- Abbreviations are uppercase from API, lowercased for asset lookup
- Examples: WSH (not WAS) for Wizards, UTAH (not UTA) for Jazz

## Gateway Endpoints

### Scoreboard
- `GET /v1/scoreboard?league={league}&date={YYYY-MM-DD}`
- Returns games for specified date

### Available Dates
- `GET /v1/scoreboard/dates?league={league}`
- Returns only dates with scheduled games
- Cached for 1 hour

### Box Score
- `GET /v1/games/{gameId}/boxscore`
- Returns detailed player statistics
