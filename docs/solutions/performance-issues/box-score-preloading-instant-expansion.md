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
module: Home Feature
symptoms:
  - "Box score data loads slowly when user taps to expand game card"
  - "Two-step loading: spinner appears, then team header, then player stats"
  - "Users must wait for API call before seeing stats"
related_issues:
  - BOX-15
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
        // Small delay between requests to avoid rate limiting
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
}
```

**Key design decisions:**
- Filters to only `isLive || isFinal` games (scheduled games have no data)
- Checks `Task.isCancelled` for early exit when user switches context
- Reuses existing `getBoxScore()` with cache and request deduplication
- 50ms delay prevents rate limiting

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
| `GameRepository.swift` | Added `preloadBoxScores()` method |
| `HomeViewModel.swift` | Added `preloadTask` property, cancellation in `updateGames()` |

## Testing

1. **Cache hit**: Open app → wait 2s → tap final game → should expand instantly
2. **Cancellation**: Switch sports mid-preload → previous preload should cancel
3. **Edge case**: Tap game immediately after load → may show brief spinner (acceptable)

## Future Improvements

- [BOX-16](https://linear.app/boxscores/issue/BOX-16): Parallel fetching with concurrency limit for faster preloading
- [BOX-17](https://linear.app/boxscores/issue/BOX-17): Prune old games from memory during long sessions

## References

- Linear: [BOX-15](https://linear.app/boxscores/issue/BOX-15/dropdown-speed)
- Brainstorm: `docs/brainstorms/2026-01-26-dropdown-speed-brainstorm.md`
- Plan: `docs/plans/2026-01-26-feat-box-score-preloading-plan.md`
