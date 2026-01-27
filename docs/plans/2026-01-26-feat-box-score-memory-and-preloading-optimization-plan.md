---
title: Box Score Preloading Speed Improvement
type: feat
date: 2026-01-26
linear: BOX-16, BOX-17
---

# Box Score Preloading Speed Improvement

## Overview

Remove the artificial 50ms delay between preload requests to achieve ~3x faster box score preloading. Monitor for actual problems before adding complexity.

## Problem Statement

Preloading game stats has a 50ms delay between each request. With 10 games, that's 500ms of artificial waiting. The delay was likely added as a precaution against ESPN rate limiting, but:

1. ESPN's free API is permissive
2. The app already has request deduplication
3. The app already has a circuit breaker

## Proposed Solution

Delete one line of code.

**Current code** ([GameRepository.swift:109-123](XcodProject/BoxScore/BoxScore/Core/Repositories/GameRepository.swift#L109-L123)):
```swift
func preloadBoxScores(games: [Game]) async {
    let preloadableGames = games.filter { $0.status.isLive || $0.status.isFinal }
    for game in preloadableGames {
        if Task.isCancelled { return }
        _ = try? await getBoxScore(gameId: game.id, sport: game.sport)
        try? await Task.sleep(nanoseconds: 50_000_000) // DELETE THIS LINE
    }
}
```

**After:**
```swift
func preloadBoxScores(games: [Game]) async {
    let preloadableGames = games.filter { $0.status.isLive || $0.status.isFinal }
    for game in preloadableGames {
        if Task.isCancelled { return }
        _ = try? await getBoxScore(gameId: game.id, sport: game.sport)
    }
}
```

## Why Not the Original Plan?

The original plan proposed:
- TaskGroup with manual concurrency tracking (+30 lines)
- Memory pruning with expansion state cleanup (+20 lines)
- Age-based cache staleness with 3 tiers (+20 lines)

**Review feedback:**
- **DHH:** "You're optimizing based on vibes and theoretical worst-cases. 50 games in memory is ~250KB. Your iPhone has 4-8GB RAM."
- **Kieran:** "The age-based staleness feature is only half-designed - the function exists but nothing uses it."
- **Simplicity:** "Delete one line. Ship it. Add complexity only when you have evidence you need it."

## Acceptance Criteria

- [x] Remove the 50ms sleep from `preloadBoxScores()`
- [ ] Verify preloading still works (tap game, see box score)
- [ ] Monitor for ESPN 429 errors in console logs

## What to Monitor After Shipping

| Concern | How to Check | Action if Problem |
|---------|--------------|-------------------|
| ESPN rate limiting | Watch for 429 errors in Xcode console | Add 10ms delay back, or implement TaskGroup |
| Memory growth | Profile with Xcode Instruments after extended use | Add pruning in `updateGames()` |
| Stale data complaints | User feedback | Adjust `finalBoxScore` TTL in AppConfig |

## Files to Modify

| File | Change |
|------|--------|
| [GameRepository.swift:121](XcodProject/BoxScore/BoxScore/Core/Repositories/GameRepository.swift#L121) | Delete the `Task.sleep` line |

## Deferred Work (BOX-17)

Memory pruning (BOX-17) is deferred until we have evidence of a problem:
- Current `allGames` array is not causing memory issues
- Existing `updateGames()` already removes games when switching dates
- Will revisit if Instruments shows memory growth

## References

- Brainstorm: [docs/brainstorms/2026-01-26-box-score-memory-and-preloading-brainstorm.md](../brainstorms/2026-01-26-box-score-memory-and-preloading-brainstorm.md)
- Linear: [BOX-16](https://linear.app/boxscores/issue/BOX-16), [BOX-17](https://linear.app/boxscores/issue/BOX-17)
