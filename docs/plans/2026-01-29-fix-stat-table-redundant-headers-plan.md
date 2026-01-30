---
title: "fix: Remove redundant stat table header rows in NFL and NHL"
type: fix
date: 2026-01-29
linear: BOX-30
brainstorm: docs/brainstorms/2026-01-29-nfl-ncaaf-nhl-stat-header-cleanup-brainstorm.md
---

# Fix: Remove Redundant Stat Table Header Rows (NFL & NHL)

## Overview

NFL and NHL box score stat tables show a redundant category header bar above the table column headers. The category name should replace the "PLAYER" text (or empty spacer) in the table header row, and the separate bar should be removed — producing one clean header row per section.

NCAAF and NCAAM don't have box score views yet, so they're out of scope.

## Problem Statement

**NFL** currently renders:
```
[ Punting                          ]  ← separate gray category bar
[ PLAYER   | PUNTS | YDS | AVG …  ]  ← table header with "PLAYER"
[ T. Townsend #5 | 3 | 142 | …    ]  ← data row
```

**NHL skaters** currently renders:
```
[  (empty) | TOI | G | A | PTS …  ]  ← stat column headers + empty frozen cell
[ Skaters                          ]  ← dark section header bar (full width)
[ C. McDavid #97 C | 22:14 | …    ]  ← data row
```

Both should become a single header row with the category/section name in the player name column.

## Proposed Solution

### Change 1: SimpleTableView — add optional `headerLabel` parameter

**File:** [SimpleTableView.swift](XcodProject/BoxScore/BoxScore/Components/Tables/SimpleTableView.swift)

Add an optional `headerLabel: String?` init parameter (default `nil`). When provided, `playerColumnHeader` displays that label instead of `"PLAYER"`. When `nil`, behavior is unchanged (shows "PLAYER").

```swift
// New parameter
var headerLabel: String? = nil

// Updated playerColumnHeader
private var playerColumnHeader: some View {
    Text(headerLabel ?? "PLAYER")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
        // ... rest unchanged
}
```

### Change 2: NFLBoxScoreView — pass section name, remove category bar

**File:** [NFLBoxScoreView.swift:98-126](XcodProject/BoxScore/BoxScore/Sports/NFL/NFLBoxScoreView.swift#L98-L126)

In `sectionView(_:)`:
1. Remove the `HStack` that renders `section.displayName` as a separate bar (lines ~101-113)
2. Pass `section.displayName.uppercased()` as `headerLabel` to `SimpleTableView`

Before:
```swift
@ViewBuilder
private func sectionView(_ section: NFLSection) -> some View {
    VStack(spacing: 0) {
        HStack { Text(section.displayName) ... }  // ← REMOVE THIS
        if section.isEmpty {
            EmptyTableStateView(...)
        } else {
            SimpleTableView(columns:..., rows:..., teamTotalsRow:..., playerColumnWidth:...)
        }
    }
}
```

After:
```swift
@ViewBuilder
private func sectionView(_ section: NFLSection) -> some View {
    VStack(spacing: 0) {
        if section.isEmpty {
            EmptyTableStateView(message: "No \(section.displayName)")
        } else {
            SimpleTableView(
                columns: section.columns,
                rows: section.rows,
                teamTotalsRow: section.teamTotalsRow,
                playerColumnWidth: NFLColumns.playerColumnWidth,
                headerLabel: section.displayName.uppercased()
            )
        }
    }
}
```

### Change 3: NHLBoxScoreView — merge skaters header rows

**File:** [NHLBoxScoreView.swift](XcodProject/BoxScore/BoxScore/Sports/NHL/NHLBoxScoreView.swift)

NHL doesn't use `SimpleTableView`, so this is a direct edit to its custom layout.

**Frozen skater column** (`frozenSkaterColumn`, lines 93-107):
- Replace the empty `Color(.systemGray6)` spacer (line 96-97) with a "SKATERS" label styled to match the stat column headers
- Remove the `sectionHeader("Skaters", isDark: true)` call (line 100)

**Scrollable skater column** (`scrollableSkaterColumn`, lines 109-122):
- Remove the `scrollableSectionSpacer(isDark: true)` call (line 115) — this was the right-side companion to the removed section header

Before (frozen):
```swift
VStack(spacing: 0) {
    Color(.systemGray6).frame(height: headerHeight)  // empty spacer
    sectionHeader("Skaters", isDark: true)            // section bar
    ForEach(boxScore.skaters) { ... }
}
```

After (frozen):
```swift
VStack(spacing: 0) {
    // Header label replacing "PLAYER"-style spacer
    HStack {
        Text("SKATERS")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
        Spacer()
    }
    .padding(.leading, 6)
    .frame(height: headerHeight)
    .background(Color(.systemGray6))

    ForEach(boxScore.skaters) { ... }
}
```

Before (scrollable):
```swift
VStack(spacing: 0) {
    skaterColumnHeaders                       // stat column names
    scrollableSectionSpacer(isDark: true)     // dark spacer bar
    ForEach(boxScore.skaters) { ... }
}
```

After (scrollable):
```swift
VStack(spacing: 0) {
    skaterColumnHeaders
    ForEach(boxScore.skaters) { ... }
}
```

### Change 4: Dead code cleanup in NHLBoxScoreView

After removing the skaters section header and spacer:

- **Delete `scrollableSectionSpacer(isDark:)`** (lines 320-323) — its only call site was the skaters scrollable column. It is no longer called anywhere.
- **Simplify `sectionHeader(_:isDark:)`** (lines 283-293) — remove the `isDark` parameter since only `isDark: false` callers remain (goalies line 193, scratches line 256). Inline the light styling.

Before:
```swift
private func sectionHeader(_ title: String, isDark: Bool) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isDark ? .white : .primary)
        Spacer()
    }
    .padding(.horizontal, 6)
    .frame(height: sectionHeaderHeight)
    .background(isDark ? Color.black.opacity(0.85) : Color(.systemGray4))
}
```

After:
```swift
private func sectionHeader(_ title: String) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.primary)
        Spacer()
    }
    .padding(.horizontal, 6)
    .frame(height: sectionHeaderHeight)
    .background(Color(.systemGray4))
}
```

Update callers at lines 193 and 256 to remove `isDark:` argument.

## Acceptance Criteria

- [x] NFL stat sections show one header row with category name (e.g., "PASSING") in the player column and stat names beside it
- [x] NHL skaters section shows one header row with "SKATERS" in the player column and stat names beside it
- [x] NHL goalies section is unchanged
- [x] NBA box scores are unchanged (still show "PLAYER")
- [x] Dead code removed: `scrollableSectionSpacer`, `isDark` parameter from `sectionHeader`
- [x] No NCAAF/NCAAM changes needed (views don't exist yet)

## Files Changed

| File | Change |
|------|--------|
| `Components/Tables/SimpleTableView.swift` | Add optional `headerLabel` parameter |
| `Sports/NFL/NFLBoxScoreView.swift` | Pass section name as `headerLabel`, remove category bar |
| `Sports/NHL/NHLBoxScoreView.swift` | Merge skaters header rows, remove spacer, delete dead code |

## References

- Brainstorm: [docs/brainstorms/2026-01-29-nfl-ncaaf-nhl-stat-header-cleanup-brainstorm.md](docs/brainstorms/2026-01-29-nfl-ncaaf-nhl-stat-header-cleanup-brainstorm.md)
- Linear: BOX-30
