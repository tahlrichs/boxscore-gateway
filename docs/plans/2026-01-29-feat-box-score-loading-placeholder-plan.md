---
title: "feat: Box score loading placeholder"
type: feat
date: 2026-01-29
---

# Box Score Loading Placeholder

## Overview

Replace the jarring "team name + tiny spinner + empty content" loading state with a pre-expanded placeholder that shows a large centered spinner. When data arrives, smoothly animate to the actual content height.

## Problem Statement

When a user taps to expand a box score and data isn't cached yet, the card opens to show only a team name header bar with a small spinner and an empty area (or "No box score available" text). This intermediate state feels unfinished. We want the expansion to feel intentional — open to a full-height placeholder with a prominent spinner, then smoothly transition to real content.

## Proposed Solution

Modify `GameCardView.swift` to show a fixed-height placeholder (with centered `ProgressView`) while loading, then animate to the actual content height when data arrives.

### Changes Required

**File: `GameCardView.swift`**

1. **Replace the empty/loading content area** in `teamBoxScoreSection` (lines ~245-276):
   - When `isLoading` and no data: show a placeholder `VStack` with a fixed height (~300pt) containing a centered, standard-size `ProgressView` spinner (no `.scaleEffect(0.6)`)
   - When data arrives: render the sport-specific box score view as today, with smooth animation to actual content height

2. **Keep the team name header as-is** (lines ~228-242):
   - The black bar with team name stays at the top immediately on expand
   - Remove the small spinner from the header (the large centered one replaces it)

3. **Wrap content transition in animation**:
   - Use `.animation(.easeInOut(duration: 0.3), value: isLoading)` on the content area so SwiftUI animates the height change when `isLoading` flips from true to false

That's it. No new files, no new view models, no skeleton views.

## Acceptance Criteria

- [x] Tapping a team expands the card to show team name header + ~300pt placeholder with centered spinner
- [x] No "No box score available" text visible during loading
- [x] No small spinner in the team name header bar (replaced by the large centered one)
- [x] When data loads, content smoothly animates from placeholder height to actual height (~0.3s easeInOut)
- [x] If data is already cached (preloaded), box score renders immediately — no spinner flash
- [x] Works for all sports (NBA, NFL, NHL, NCAAM, NCAAF)
- [x] Collapsing still works normally

## Technical Notes

- The placeholder height of ~300pt is approximate. SwiftUI will naturally animate from this fixed frame to the content's intrinsic size when the `isLoading` condition changes.
- If data is already cached, `isLoading` will flip to false almost instantly and the box score view renders without the placeholder ever being visible — no special case needed.
- Error handling remains unchanged (silent fail, empty state shows after loading ends).

## Files to Modify

| File | Change |
|------|--------|
| [GameCardView.swift](XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift) | Replace loading content with fixed-height placeholder + centered spinner; remove header spinner; add content animation |

## References

- Brainstorm: [2026-01-29-box-score-loading-ux-brainstorm.md](../brainstorms/2026-01-29-box-score-loading-ux-brainstorm.md)
- Preloading solution: [box-score-preloading-instant-expansion.md](../solutions/performance-issues/box-score-preloading-instant-expansion.md)
