# Player Profile: Full Stats & Game Log

**Date:** 2026-01-31
**Status:** Brainstorm complete

## What We're Building

Expanding NBA player profiles to show comprehensive stats across three areas:

### Issue 1: Hero Banner + Stat Central Table

**Hero Banner (5 headline stats - current season averages):**
- PTS, REB, AST, FG%, 3PT%

**Stat Central Table (season-by-season + career row):**
All stats shown as per-game averages. Columns:
- GP, GS, MIN, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, PTS

This expands the current table which only shows GP, PPG, RPG, APG, FG%, FT%.

### Issue 2: Game Log Tab

- Shows the **last 10 games** the player has played
- Each row shows:
  - **Date** formatted as: `Sat 1/28`, `Wed 11/12` (day abbreviation + numeric date)
  - **Opponent** (e.g., "vs SAS", "@ LAL")
  - **Full stat line** (game totals, not averages): MIN, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, PTS
- Future: "See more" page for full game log beyond last 10

## Why Two Issues

- Issue 1 (hero + table) shares the same backend data source: season/career averages
- Issue 2 (game log) requires a completely different data source (per-game data), a new gateway endpoint, and different display logic (totals vs averages)
- Splitting lets Issue 1 ship and be tested independently

## Key Decisions

- Skip +/- from stat columns
- Include GP (games played) and GS (games started) in the season table
- Game Log shows actual game totals, not averages
- Game Log date format: day abbreviation + numeric month/day (e.g., "Sat 1/28")
- Game Splits and Advanced tabs remain "Coming Soon" for now
- Last 10 games only for initial Game Log; deeper page comes later

## What Already Exists

- Player profile view with header, Stat Central tab, placeholder tabs
- Gateway `/v1/players/:id/stat-central` endpoint returning season + career data (limited stat set)
- Navigation from box scores and search to player profiles
- NBA box score views with full stat lines

## What Needs to Change

### Issue 1
- **Gateway:** Expand stat-central response to include all stat categories (GP, GS, MIN, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, PTS)
- **iOS:** Update hero banner to pull current season PPG, RPG, APG, FG%, 3PT%
- **iOS:** Expand Stat Central table to display all columns (will need horizontal scrolling)

### Issue 2
- **Gateway:** Build or complete `/v1/players/:id/season/:season/gamelog` endpoint returning last 10 games
- **iOS:** Build Game Log tab UI with date + opponent + full stat line
- **iOS:** Future "See more" navigation to full game log page

## Open Questions

- Where does game-by-game data come from? (ESPN player game log endpoint vs API-Sports)
- How to handle the wide stat table on smaller screens (horizontal scroll vs collapsible columns)
