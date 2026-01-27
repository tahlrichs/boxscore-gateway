---
title: "Box Score Preloading: Instant Expansion Experience"
date: 2026-01-26
category: performance-issues
tags:
  - ios
  - swift
  - box-scores
  - background-loading
  - caching
  - ux-optimization
  - yagni
  - simplicity
module: Home Feature
symptoms:
  - "Box score data loads slowly when user taps to expand game card"
  - "Two-step loading: spinner appears, then team header, then player stats"
  - "Users must wait for API call before seeing stats"
related_issues:
  - BOX-15
  - BOX-16
  - BOX-17
---

# Box Score Preloading: Instant Expansion Experience

## Problem

Users experienced a noticeable delay when expanding game cards to view box score details. The app showed a two-step loading experience:

1. User taps game card → team header appears with spinner
2. Wait for API request (~200-500ms)
3. Player stats render

This felt sluggish. Speed is the app's core differentiator.

## Root Cause

Box scores were only fetched **on-demand** when a user expanded a game card. Every expansion required a fresh network request, creating visible loading states even though the data was predictably needed.

## Solution

Implemented **background preloading** of box scores immediately after games load.

### Architecture

```
Phase 1: Load scores (user sees immediately)
    ↓
Phase 2: Preload box scores in background (invisible)
    ↓
User taps → Data already cached → Instant expansion
```

### 1. Background Preload Task (GameRepository.swift)

```swift
/// Preload box scores for multiple games in background
/// Skips scheduled games (no box score data) and uses existing cache/deduplication
func preloadBoxScores(games: [Game]) async {
    let preloadableGames = games.filter { $0.status.isLive || $0.status.isFinal }

    for game in preloadableGames {
        // Check for cancellation (e.g., user switched sports/dates)
        if Task.isCancelled { return }

        // getBoxScore already handles cache-first and deduplication
        _ = try? await getBoxScore(gameId: game.id, sport: game.sport)
    }
}
```

**Key design decisions:**
- Filters to only `isLive || isFinal` games (scheduled games have no data)
- Checks `Task.isCancelled` for early exit when user switches context
- Reuses existing `getBoxScore()` with cache and request deduplication
- No artificial delays - existing deduplication and circuit breaker provide protection

### 2. Cancellation Handling (HomeViewModel.swift)

```swift
/// Background task for preloading box scores (cancellable)
private var preloadTask: Task<Void, Never>?

// In updateGames():
preloadTask?.cancel()  // Cancel in-flight preload
preloadTask = Task.detached(priority: .utility) { [weak self] in
    guard let self = self else { return }
    await self.gameRepository.preloadBoxScores(games: newGames)
}
```

**Why `Task.detached`?**
- `Task {}` would inherit `@MainActor` context
- We want background work, so `Task.detached` with `.utility` priority is correct
- `weak self` prevents retain cycles

## Results

| Before | After |
|--------|-------|
| Tap → spinner → data (500ms) | Tap → instant data |
| Every expansion = network call | Most expansions = cache hit |
| Wasted calls on sport switch | Cancellation stops irrelevant fetches |

## Files Modified

| File | Change |
|------|--------|
| `GameRepository.swift` | Added `preloadBoxScores()` method (~10 lines) |
| `HomeViewModel.swift` | Added `preloadTask` property, cancellation (~8 lines) |

**Total: ~18 lines of code**

## Testing

1. **Cache hit**: Open app → wait 2s → tap final game → should expand instantly
2. **Cancellation**: Switch sports mid-preload → previous preload should cancel
3. **Edge case**: Tap game immediately after load → may show brief spinner (acceptable)

## Lessons Learned: YAGNI in Action

This implementation demonstrates the value of starting simple and adding complexity only when needed.

### What Was Proposed vs. What Was Shipped

| Proposed Feature | Lines | Decision | Rationale |
|------------------|-------|----------|-----------|
| TaskGroup with concurrency limit | +30 | **Rejected** | Serial is fast enough (~200ms for 10 games) |
| Memory pruning with age tiers | +20 | **Deferred** | No evidence of memory issues |
| Age-based cache staleness (3 tiers) | +20 | **Deferred** | Existing TTL is sufficient |
| 50ms artificial delay | +1 | **Removed** | No rate limiting observed |

**Original proposal:** 70+ lines
**Final implementation:** 18 lines (74% reduction)

### Review Feedback That Drove Simplification

> "You're optimizing based on vibes and theoretical worst-cases. 50 games in memory is ~250KB. Your iPhone has 4-8GB RAM." — DHH-style reviewer

> "Delete one line. Ship it. Add complexity only when you have evidence you need it." — Simplicity reviewer

### Key Principles Applied

1. **Reuse existing infrastructure** — The preload loop just calls `getBoxScore()`, automatically getting cache, deduplication, and error handling for free.

2. **Add complexity with evidence** — Memory pruning and parallel fetching were deferred because testing showed no problems.

3. **Remove unnecessary code** — The 50ms delay was removed when no ESPN rate limiting was observed.

## What to Monitor

| Concern | How to Check | Action if Problem |
|---------|--------------|-------------------|
| ESPN rate limiting | Watch for 429 errors in Xcode console | Add 10ms delay back |
| Memory growth | Profile with Xcode Instruments | Add pruning in `updateGames()` |
| Stale data | User complaints about wrong stats | Adjust cache TTL |

## Deferred Work

- **BOX-16 (Parallel fetching)**: Rejected for now. Serial loading is fast enough, and parallel adds complexity without measurable user benefit.
- **BOX-17 (Memory pruning)**: Deferred until evidence of a problem. Current memory usage is within acceptable bounds.

## References

- Linear: [BOX-15](https://linear.app/boxscores/issue/BOX-15/dropdown-speed), [BOX-16](https://linear.app/boxscores/issue/BOX-16), [BOX-17](https://linear.app/boxscores/issue/BOX-17)
- Brainstorm: `docs/brainstorms/2026-01-26-dropdown-speed-brainstorm.md`
- Plan: `docs/plans/2026-01-26-feat-box-score-preloading-plan.md`
- Optimization Plan: `docs/plans/2026-01-26-feat-box-score-memory-and-preloading-optimization-plan.md`
