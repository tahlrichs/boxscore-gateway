---
title: "Box score loading state feels empty and jarring"
category: ui-bugs
module: Features/Home
tags: [loading-state, animation, SwiftUI, ProgressView, UX]
symptoms:
  - Expanding box score shows tiny spinner in header bar with empty content area
  - "No box score available" text flashes during loading
  - Card opens to awkward small height before data arrives
date_solved: 2026-01-29
linear_issue: BOX-28
---

# Box Score Loading State Feels Empty and Jarring

## Problem

When a user taps to expand a box score and data isn't cached yet, the card opened to show a team name header bar with a tiny `.scaleEffect(0.6)` spinner and an empty content area (or "No box score available" text). This intermediate state felt unfinished — the card was too short, the spinner was barely visible, and the empty text was misleading.

## Root Cause

The original `teamBoxScoreSection` in `GameCardView.swift` placed a small spinner inside the header bar and relied on the sport-specific switch statement to render content. While loading, the switch cases had `&& !isLoading` guards that suppressed the empty state text, but showed nothing in its place — just a collapsed empty area.

## Solution

Replaced the loading state with a 300pt fixed-height placeholder containing a centered, standard-size `ProgressView`. Removed the small header spinner entirely.

**Key changes to `GameCardView.swift`:**

1. **Removed header spinner** — the black team name bar no longer contains a `ProgressView`
2. **Added loading placeholder** — when `isLoading && boxScore.isEmpty`, show a 300pt centered spinner instead of empty space
3. **Animated the transition** — `.animation(Theme.standardAnimation, value: isLoading)` on the parent `VStack` smoothly animates from placeholder height to actual content height

```swift
// Loading placeholder
if isLoading && boxScore.isEmpty {
    VStack {
        Spacer()
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        Spacer()
    }
    .frame(maxWidth: .infinity)
    .frame(height: 300)
    .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
} else {
    // Sport-specific box score content
}
```

**Supporting changes:**

- Added `BoxScorePayload.isEmpty` computed property in `GameModels.swift` to deduplicate the empty-data check
- Added `Theme.standardAnimation` constant (`.easeInOut(duration: 0.3)`) to centralize the animation duration
- Replaced all 8 hardcoded animation durations across 7 files with `Theme.standardAnimation`

## Prevention

- When adding loading states, design the placeholder to match the expected content height so expansion feels intentional
- Keep animation durations in a central constant (`Theme.standardAnimation`) so they stay consistent as new views are added
- Put data-shape checks (like "is this box score empty?") on the model itself, not in the view layer

## Related

- [Box score preloading](../performance-issues/box-score-preloading-instant-expansion.md) — preloading eliminates the loading state for most cases
- Plan: [docs/plans/2026-01-29-feat-box-score-loading-placeholder-plan.md](../../plans/2026-01-29-feat-box-score-loading-placeholder-plan.md)
