---
title: "Game Log tab blank — .task on empty SwiftUI Group never fires"
category: ui-bugs
date: 2026-02-01
module: PlayerProfile
tags: [swiftui, task-modifier, group, view-lifecycle, conditional-rendering]
symptoms:
  - "Game Log tab showed blank screen"
  - "No loading spinner, no data, no error"
  - "loadGameLog() never called"
related_issues: [BOX-43, BOX-49]
files_changed:
  - XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift
---

# Game Log tab blank — .task on empty SwiftUI Group never fires

## Symptoms

- Player profile Game Log tab is completely blank
- No loading spinner, no data, no error message
- API returns data correctly; JSON decoding works
- `loadGameLog()` is never called (verified via print debugging)

## Root Cause

SwiftUI's `Group` distributes modifiers to its children, not to itself. When a `Group` has conditional children and all conditions are false on initial render, the Group has **zero children** and `.task` has nothing to attach to.

```swift
// BROKEN: .task never fires when all conditions are false
Group {
    if viewModel.gameLogLoading {        // false
        ProgressView()
    } else if let games = viewModel.gameLog {  // nil
        gameLogTable(games)
    } else if viewModel.gameLogError != nil {  // nil
        Text("Failed to load game log")
    }
}
.task { await viewModel.loadGameLog() }  // NEVER FIRES
```

Initial state: `gameLogLoading=false`, `gameLog=nil`, `gameLogError=nil` — all branches are false, zero children, `.task` is orphaned.

## Solution

Replace `Group` with `VStack(spacing: 0)`. A `VStack` is a concrete container view that always exists in the hierarchy regardless of children count. `.task` attaches to the VStack itself and fires on appear.

```swift
// FIXED: VStack always exists, .task fires correctly
VStack(spacing: 0) {
    if viewModel.gameLogLoading {
        ProgressView()
    } else if let games = viewModel.gameLog {
        gameLogTable(games)
    } else if viewModel.gameLogError != nil {
        Text("Failed to load game log")
    }
}
.task { await viewModel.loadGameLog() }  // FIRES
```

Use `spacing: 0` to match codebase conventions and avoid default ~8pt spacing.

## How to Verify

1. Build and run on simulator
2. Navigate to any player profile
3. Tap Game Log tab
4. Loading spinner appears, then game data loads

## Prevention

Never attach `.task` or `.onAppear` to a `Group` with conditional children. Use `VStack`, `ZStack`, or any concrete container instead.

**Rule of thumb**: If a view's children are all conditional, use a concrete container (`VStack`, `ZStack`) — not `Group`.

## Related

- [DateFormatter static allocation in game log](../performance-issues/dateformatter-static-allocation-game-log.md)
- [Player profile layout redesign (BOX-41)](player-profile-layout-redesign-box41.md)
- [Box score preloading — .task usage patterns](../performance-issues/box-score-preloading-instant-expansion.md)
- Apple docs: Group distributes modifiers to children, not to itself
