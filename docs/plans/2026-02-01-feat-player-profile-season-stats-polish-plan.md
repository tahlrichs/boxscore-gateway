---
title: "feat: Player profile season stats & game log polish (BOX-46)"
type: feat
date: 2026-02-01
linear: BOX-46
---

# Player Profile Season Stats & Game Log Polish

Three UI improvements scoped **only** to the player profile screen. The main scoreboard box scores are not affected.

## 1. Team logo + abbreviation on season rows

**Current:** Season column shows just `"2025-26"`.
**Goal:** Show a small team logo and the team abbreviation next to the season label (e.g., `[LAL logo] LAL  2025-26`).

### What exists today

- `SeasonRow.teamAbbreviation` already comes from the gateway (nullable — nil for career/total rows).
- Team logos are **local assets** named `team-nba-{abbr}` (see `GameCardView.swift:22-26`). No network fetch needed.
- The frozen season column is currently 56pt wide. It will need to widen to fit logo + abbreviation + season label.

### Changes

- **`PlayerProfileView.swift`** — season stats frozen column:
  - Add a small `Image("team-nba-\(abbr)")` (12–14pt) and abbreviation `Text` next to the season label.
  - Skip logo/abbreviation for career and total rows (where `teamAbbreviation` is nil).
  - Widen the frozen column from 56pt to ~110–120pt.

## 2. Combine shooting stat columns (FG, 3PT, FT)

**Current:** Nine separate columns — FG, FGA, FG%, 3PM, 3PA, 3P%, FT, FTA, FT% (9 columns total).
**Goal:** Six columns — combine makes/attempts into one column each, but **keep the percentage columns**. Result: FG (makes-attempts), FG%, 3PT (makes-attempts), 3P%, FT (makes-attempts), FT%.

### Changes

- **`PlayerProfileView.swift`** — `statColumns` computed property (~line 592):
  - Replace the 6 makes/attempts columns (FG, FGA, 3PM, 3PA, FT, FTA) with 3 combined columns.
  - Each combined column formats as `String(format: "%.1f-%.1f", made, attempted)`.
  - Keep the 3 percentage columns (FG%, 3P%, FT%) as-is.
  - Combined column width ~60–70pt to fit `"XX.X-XX.X"`.
  - Column headers: `"FG"`, `"3PT"`, `"FT"` for combined; percentages stay as `"FG%"`, `"3P%"`, `"FT%"`.

## 3. Team logo in game log opponent column

**Current:** Opponent column shows `"vs SAS"` or `"@ SAS"`.
**Goal:** For away games show `"@"` then a small logo then `"SAS"`. For home games show `"vs"` then a small logo then `"SAS"`.

### What exists today

- `GameLogEntry.opponent` is a 3-letter abbreviation.
- `GameLogEntry.isHome` determines vs/@.
- Team logos are local assets (`team-nba-{abbr}`).

### Changes

- **`PlayerProfileView.swift`** — game log frozen column (~line 509):
  - Replace the `Text(game.opponentDisplay)` with an `HStack` containing: prefix text ("@" or "vs"), small team logo image (10–12pt), abbreviation text.
  - May need to widen the opponent sub-column from 52pt to ~70pt.

## Acceptance Criteria

- [x] Season rows show team logo + abbreviation (except career/total rows)
- [x] FG, 3PT, FT columns show combined "makes-attempts" format with 1 decimal
- [x] FG%, 3P%, FT% percentage columns are kept
- [x] Game log opponent column shows small team logo between prefix and abbreviation
- [x] Main scoreboard box scores are **unchanged**
- [x] Build succeeds on iPhone 17 Pro simulator

## Files to Change

| File | What |
|------|------|
| `Features/PlayerProfile/PlayerProfileView.swift` | All three UI changes |

No gateway or model changes needed — all data (`teamAbbreviation`, `opponent`) already exists.

## References

- Team logo pattern: `GameCardView.swift:22-26`
- Season stats columns: `PlayerProfileView.swift:~592`
- Game log opponent: `PlayerProfileView.swift:~509`
- Models: `StatCentralModels.swift`
- Linear: BOX-46
