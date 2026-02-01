---
title: "fix: Game Log .task never fires on empty SwiftUI Group"
type: fix
date: 2026-02-01
related: BOX-43
---

# fix: Game Log .task never fires on empty SwiftUI Group

## Problem

The Game Log tab on the player profile shows blank — no loading spinner, no data, no error message. The production API returns 10 games correctly, JSON decoding works, and the code logic is sound. **The fetch never starts.**

### Root Cause

In `PlayerProfileView.swift:431-454`, the `gameLogContent` view uses a `Group` with conditional children and a `.task` modifier:

```swift
private var gameLogContent: some View {
    Group {
        if viewModel.gameLogLoading {        // false initially
            ProgressView()
        } else if let games = viewModel.gameLog {  // nil initially
            // ...
        } else if viewModel.gameLogError != nil {   // nil initially
            // ...
        }
    }
    .task { await viewModel.loadGameLog() }  // NEVER FIRES
}
```

**SwiftUI distributes modifiers on a `Group` to its children.** In the initial state (`gameLogLoading=false`, `gameLog=nil`, `gameLogError=nil`), all conditions are false, the Group has **zero children**, and `.task` has nothing to attach to — so it never executes.

### Verification

- Built app with `print()` debug logging in `loadGameLog()`
- Auto-navigated to Harrison Barnes' profile, tapped Game Log tab
- Console captured `print("HealthCheck: ...")` from app startup (proving print capture works)
- **No `[GameLog]` output appeared** — confirming `loadGameLog()` is never called

## Proposed Solution

Replace `Group` with `VStack`. Unlike `Group` (a transparent container), `VStack` is a concrete view that always exists in the hierarchy. `.task` attaches to the `VStack` itself and fires when it appears, regardless of whether it has children.

### `PlayerProfileView.swift` — gameLogContent (lines 431-448)

```swift
// BEFORE (broken):
private var gameLogContent: some View {
    Group {
        // ... conditional children ...
    }
    .background(Theme.cardBackground(for: colorScheme))
    .cornerRadius(12)
    .task { await viewModel.loadGameLog() }
}

// AFTER (fixed):
private var gameLogContent: some View {
    VStack {
        if viewModel.gameLogLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let games = viewModel.gameLog {
            if games.isEmpty {
                Text("No game log data available")
                    .font(.subheadline)
                    .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                gameLogTable(games)
            }
        } else if viewModel.gameLogError != nil {
            Text("Failed to load game log")
                .font(.subheadline)
                .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }
    .background(Theme.cardBackground(for: colorScheme))
    .cornerRadius(12)
    .task { await viewModel.loadGameLog() }
}
```

## Acceptance Criteria

- [ ] Game Log tab shows a loading spinner, then displays 10 recent games for any NBA player
- [ ] Empty game log shows "No game log data available" message
- [ ] API errors show "Failed to load game log" message
- [ ] No visual layout changes (VStack with conditional children renders identically to Group)

## Context

- **File to change:** `XcodProject/BoxScore/BoxScore/Features/PlayerProfile/PlayerProfileView.swift:431` — change `Group` to `VStack`
- **Related issue:** BOX-43 (Player Profile: Game Log Tab) — this bug was introduced in PR #24 (commit `36d6f4f`)
- **API confirmed working:** `GET /v1/players/:id/season/2025/gamelog` returns 10 games on both local and production gateways
- **No other `.task`-on-`Group` instances** found in the codebase (repo research confirmed)

## References

- PR #24: feat: player profile game log tab (BOX-43) — introduced the bug
- Apple SwiftUI docs: Group distributes modifiers to children, not to itself
