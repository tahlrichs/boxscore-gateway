---
title: "feat: Add League/Conference/Division filter to Standings"
type: feat
date: 2026-02-21
linear: BOX-55
brainstorm: docs/brainstorms/2026-02-21-standings-conferences-filter-brainstorm.md
---

# feat: Add League/Conference/Division filter to Standings

## Overview

Fix two issues on the Standings tab: (1) remove the duplicate sport picker that shows alongside HomeView's SportTabBar, and (2) add a segmented control to group standings by League, Conference, or Division. Also hide the DateSelector when on the Standings tab since standings are not date-specific.

**Scope**: iOS-only. No gateway changes. Division data is static (team-to-division assignments don't change mid-season) so we use a client-side lookup table instead of building an ESPN API integration.

## Problem Statement

- **Duplicate sport buttons**: StandingsView has its own pill-button sport picker AND HomeView's SportTabBar is visible above it. Two independent sport selectors confuse users.
- **No grouping options**: Standings always show all conferences as sections. No way to see a flat league ranking or drill into divisions.
- **Irrelevant DateSelector**: The horizontal date scroll shows on the Standings tab even though standings don't change by date.

## Proposed Solution

All changes in one PR touching 4 iOS files. No gateway deployment needed.

**Files:**
- [HomeView.swift](XcodProject/BoxScore/BoxScore/Features/Home/HomeView.swift)
- [StandingsView.swift](XcodProject/BoxScore/BoxScore/Features/Standings/StandingsView.swift)
- [StandingsViewModel.swift](XcodProject/BoxScore/BoxScore/Features/Standings/StandingsViewModel.swift)
- [PlayerProfileView.swift](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift) (extract shared picker)

### 1. HomeView — Hide DateSelector & Pass Sport Binding

- Wrap the date/week/conference/tour selector block (~lines 38-59) in `if selectedTab != .standings`
- Pass `viewModel.selectedSport` as a `Binding<Sport>` into `StandingsView`:
  ```swift
  case .standings:
      StandingsView(selectedSport: $viewModel.selectedSport)
  ```

### 2. StandingsView — Remove Duplicate Picker, Add Grouping Control

- Remove the `sportPicker` computed property and `sportButton()` helper (lines 36-70)
- Add `@Binding var selectedSport: Sport` parameter
- Wire sport changes to viewModel via `.onChange(of: selectedSport)` → set `viewModel.selectedSport` (keep existing `didSet` on viewModel)
- Add segmented grouping control — extract the PlayerProfile tab picker pattern into a reusable `SegmentedPicker<T: CaseIterable & RawRepresentable>` component instead of copying the pattern a third time
- Update `standingsList` to render differently per grouping mode (see section 4 below)
- Update the preview to use `.constant(.nba)` for the new binding

### 3. StandingsViewModel — Add Grouping Logic & Division Lookup

**Add `StandingsGrouping` enum:**
```swift
enum StandingsGrouping: String, CaseIterable {
    case league = "League"
    case conference = "Conference"
    case division = "Division"
}
```

**Add static division lookup table** (~40 lines of well-known data):
```swift
private static let divisionsByTeam: [String: [String: String]] = [
    "nba": [
        "BOS": "Atlantic", "BKN": "Atlantic", "NYK": "Atlantic", "PHI": "Atlantic", "TOR": "Atlantic",
        "CHI": "Central", "CLE": "Central", "DET": "Central", "IND": "Central", "MIL": "Central",
        "ATL": "Southeast", "CHA": "Southeast", "MIA": "Southeast", "ORL": "Southeast", "WAS": "Southeast",
        "DEN": "Northwest", "MIN": "Northwest", "OKC": "Northwest", "POR": "Northwest", "UTA": "Northwest",
        "GSW": "Pacific", "LAC": "Pacific", "LAL": "Pacific", "PHX": "Pacific", "SAC": "Pacific",
        "DAL": "Southwest", "HOU": "Southwest", "MEM": "Southwest", "NOP": "Southwest", "SAS": "Southwest",
    ],
    "nfl": [ /* AFC East/North/South/West, NFC East/North/South/West */ ],
    "nhl": [ /* Eastern: Atlantic/Metropolitan, Western: Central/Pacific */ ],
    "mlb": [ /* AL East/Central/West, NL East/Central/West */ ],
]
```

**Update `groupStandings()` to support three modes:**

- **League**: Sort all standings by `winPct` descending. Single flat list. Re-rank 1-N. Show existing GB values (conference-relative from API — don't recalculate).
- **Conference**: Group by `standing.conference` (current behavior, unchanged).
- **Division**: Group by conference, then sub-group by division within each conference using the lookup table. Use a nested dictionary `[String: [String: [Standing]]]` (conference → division → teams). The view iterates conferences, then divisions within each conference using nested `ForEach`.

**Add `selectedGrouping` property** (defaults to `.conference`). Calling `didSet` triggers `groupStandings()` to recompute.

**Add computed `availableGroupings`** — returns all three options for sports with division data, or just `[.league, .conference]` for sports without (golf, college). Check if any standing has a division from the lookup table.

### 4. View Rendering Per Mode

- **League mode**: No section headers. Flat list with rank 1-N and column headers once at top.
- **Conference mode**: Pinned section headers per conference (current behavior, unchanged).
- **Division mode**: Conference names as pinned section headers (large, Oswald Bold). Division names as non-pinned sub-headers within each conference (smaller, secondary style). Teams listed under their division.

## Edge Cases

| Edge Case | Decision |
|-----------|----------|
| Sport without divisions (golf, college) | Hide "Division" option from segmented control via `availableGroupings` |
| Golf on Standings tab | Hide DateSelector, WeekSelector, and TourSelector. Show existing empty state. |
| Grouping persistence across tab switches | Persists in StandingsViewModel `@State` for the session |
| Sport sync across tabs | Single source of truth via binding from HomeViewModel |
| Games Back in League view | Show existing API-provided GB (conference-relative). Don't recalculate. |
| `.task` placement | Place on parent VStack, not conditional Group. See [swiftui-task-on-empty-group-never-fires.md](docs/solutions/ui-bugs/swiftui-task-on-empty-group-never-fires.md) |

## Acceptance Criteria

- [x] Only one set of sport buttons visible on Standings tab (shared SportTabBar)
- [x] DateSelector/WeekSelector/TourSelector hidden when on Standings tab
- [x] Segmented control (League | Conference | Division) visible on Standings tab
- [x] "Division" option hidden for sports without division data
- [x] **League**: Flat list of all teams ranked 1-N by win percentage
- [x] **Conference**: Teams grouped by conference with pinned headers (current behavior)
- [x] **Division**: Two-level grouping — conference headers → division sub-headers → teams
- [x] Switching sports reloads standings, grouping mode persists
- [x] Segmented picker extracted as reusable `SegmentedPicker` component
- [x] Segmented control only visible on Standings tab, not on Scores tab

## Risks

- **No test target**: Build verification only — no XCTests to validate grouping logic.
- **Team abbreviation mismatch**: The lookup table keys must match the `teamAbbrev` values returned by the API. Verify against actual API responses.
- **Future gateway work**: When ESPN `fetchStandings()` is eventually implemented, division data should be added to the gateway response too. That's a separate ticket.

## References

- **Brainstorm**: [2026-02-21-standings-conferences-filter-brainstorm.md](docs/brainstorms/2026-02-21-standings-conferences-filter-brainstorm.md)
- **Linear Issue**: BOX-55
- **Tab picker pattern**: [PlayerProfileView.swift:316-342](XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift#L316-L342)
- **SportTabBar**: [SportTabBar.swift](XcodProject/BoxScore/BoxScore/Components/Navigation/SportTabBar.swift)
- **Layout stability**: [swiftui-hstack-conditional-layout-stability.md](docs/solutions/ui-bugs/swiftui-hstack-conditional-layout-stability.md)
- **Task on empty Group**: [swiftui-task-on-empty-group-never-fires.md](docs/solutions/ui-bugs/swiftui-task-on-empty-group-never-fires.md)
