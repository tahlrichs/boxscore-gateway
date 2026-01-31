---
title: "feat: Player Profile Layout Redesign"
type: feat
date: 2026-01-31
linear: BOX-41
brainstorm: docs/brainstorms/2026-01-31-player-profile-redesign-brainstorm.md
---

# Player Profile Layout Redesign

## Overview

Restructure the Player Profile page layout to match the reference screenshot from BOX-41. This is a **layout-only** change — rearranging existing views and adding placeholder sections. Real data wiring for new sections comes in a follow-up.

## Problem Statement

The current player profile has headline stats nested inside the Stat Central tab, and there are no Game Splits, Game Log, or Advanced sub-tabs. The design calls for:
- Hero stats visible at all times (above the top tabs)
- Nested sub-tabs under Stat Central for Game Splits, Game Log, and Advanced

## Proposed Solution

Modify `PlayerProfileView.swift` to restructure the layout hierarchy. No new files, no backend changes, no new models.

## Changes

All changes are in one file: [PlayerProfileView.swift](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift)

### 1. Add Sub-Tab Enum

Add a new enum for the three nested sub-tabs under Stat Central. Note: "Season Stats" is NOT a sub-tab — the season stats table is the default content of Stat Central, always visible above the sub-tab picker. The sub-tabs offer additional views below it.

```swift
enum StatCentralSubTab: String, CaseIterable {
    case gameSplits = "Game Splits"
    case gameLog = "Game Log"
    case advanced = "Advanced"
}
```

### 2. Add ViewModel State

Add to `PlayerProfileViewModel`:

```swift
var selectedSubTab: StatCentralSubTab = .gameSplits
```

### 3. Move Hero Stats Above Tabs

In the `body` ScrollView VStack, change the order from:

```
playerHeader → tabPicker → tabContent
```

To:

```
playerHeader → headlineStatsView → tabPicker → tabContent
```

### 4. Update headlineStatsView

- Move it out of `statCentralContent` so it's always visible regardless of selected tab
- **Replace SPG with FG% and add 3P%** — change from 4 stats (PPG, RPG, APG, SPG) to 5 stats (PPG, RPG, APG, FG%, 3P%). SPG is deliberately removed in favor of shooting percentages
- **Delete the `headlineStats` tuple** on the ViewModel (lines 57-60). Instead, read `viewModel.response?.seasons.first` directly in the view and pull the fields needed. The tuple was an unnecessary indirection
- FG% is stored on `SeasonRow.fgPct` as a 0-100 scale value (e.g., `48.2` means 48.2%). Display with `"%.1f"` formatting — no conversion needed
- 3P% is NOT on `SeasonRow` yet — display as "--" placeholder until the backend adds the field

### 5. Update statCentralContent

The new Stat Central layout stacks the season stats table with the sub-tab picker below it:

```
seasonStatsTable (always visible, unchanged)
↓
subTabPicker (Game Splits | Game Log | Advanced)
↓
subTabContent (switch on selectedSubTab)
  - .gameSplits → placeholder "Coming Soon"
  - .gameLog → placeholder "Coming Soon"
  - .advanced → placeholder "Coming Soon"
```

### 6. Add Sub-Tab Picker View

Build a second tab picker for the sub-tabs. Same visual style as the top-level `tabPicker` (lines 234-260) — copy the pattern and swap the binding to `selectedSubTab`. Do not extract a shared generic component; the two pickers serve different purposes and will likely diverge as features are added.

### 7. Season Stats Table Columns

Keep the current 7 columns (Season, GP, PPG, RPG, APG, FG%, FT%). The `SeasonRow` model only has these fields. Expanding to match the full BoxScore column set (14 columns) requires backend changes to the stat-central response — that's a separate task. When more columns are added, follow the frozen-left-column + horizontal-scroll pattern from [NBABoxScoreView.swift](XcodProject/BoxScore/BoxScore/Sports/NBA/NBABoxScoreView.swift).

## Acceptance Criteria

- [x] Hero stats bar (PPG, RPG, APG, FG%, 3P%) displays between player header and tabs, visible on all tabs
- [x] SPG removed from hero stats, replaced by FG%
- [x] Switching to Bio or News tab still shows hero stats above
- [x] Stat Central tab shows season stats table, then sub-tab picker below: Game Splits | Game Log | Advanced
- [x] Game Splits, Game Log, Advanced sub-tabs show "Coming Soon" placeholder
- [x] Sub-tab picker only visible when Stat Central top-tab is selected
- [x] Animations match existing patterns (`Theme.standardAnimation`)
- [x] No backend changes required

## Files Modified

| File | Change |
|------|--------|
| [PlayerProfileView.swift](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift) | Layout restructure, add sub-tab enum + state, move headline stats |

## Out of Scope (Follow-up Issues)

- Wiring real data to Game Splits, Game Log, Advanced
- Adding more stat columns to season table (requires backend `SeasonRow` model expansion)
- Adding 3P% to hero stats (requires backend adding the field to `SeasonRow`)
- Bio tab content
- News tab content
- Horizontal scroll for expanded stat columns
- Extracting sub-views into separate files (not needed at current file size)

## References

- Brainstorm: [docs/brainstorms/2026-01-31-player-profile-redesign-brainstorm.md](docs/brainstorms/2026-01-31-player-profile-redesign-brainstorm.md)
- Existing tab pattern: [PlayerProfileView.swift:234-260](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift#L234-L260)
- Nested tab pattern: [NFLBoxScoreView.swift](XcodProject/BoxScore/BoxScore/Sports/NFL/NFLBoxScoreView.swift)
- BoxScore stat columns: [NBABoxScoreView.swift:31-46](XcodProject/BoxScore/BoxScore/Sports/NBA/NBABoxScoreView.swift#L31-L46)
- Data model: [StatCentralModels.swift](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/StatCentralModels.swift)
