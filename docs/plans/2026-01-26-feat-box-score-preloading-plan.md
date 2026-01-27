---
title: "feat: Box Score Background Preloading"
type: feat
date: 2026-01-26
linear-issue: BOX-15
brainstorm: docs/brainstorms/2026-01-26-dropdown-speed-brainstorm.md
---

# feat: Box Score Background Preloading

## Overview

Eliminate the two-step loading experience when expanding game cards. After scores load, immediately preload box scores for all games in the current view so tapping feels instant.

**Before:** Tap → spinner → team header → spinner → player stats (2-3 seconds)
**After:** Tap → full box score with player stats (~instant for preloaded games)

## Problem Statement

The current lazy-loading approach causes a noticeable delay when users tap to expand a game card. Users see:
1. Team header appears
2. Loading spinner
3. Player stats fill in

This feels sluggish. Speed is the app's core differentiator.

## Proposed Solution

**Two-phase loading strategy:**

```
Phase 1: Load scores (user sees this immediately)
    ↓
Phase 2: Preload box scores in background (invisible to user)
    ↓
User taps → Data already cached → Instant expansion
```

**Key behaviors:**
- Preload ALL games for the current day/sport (not just visible)
- Skip scheduled/future games (no box score data exists)
- If user taps before preload completes → show brief spinner (current behavior)
- Animation: collapsed → fully expanded with data (no intermediate states)

## Technical Approach

### Integration Points

| File | Location | Change |
|------|----------|--------|
| [HomeViewModel.swift](XcodProject/BoxScore/BoxScore/Features/Home/HomeViewModel.swift) | After line 342 | Trigger preload after `updateGames()` |
| [GameRepository.swift](XcodProject/BoxScore/BoxScore/Core/Repositories/GameRepository.swift) | New method | Add `preloadBoxScores()` batch method |
| [GameCardView.swift](XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift) | Lines 198-217 | No change needed (uses cached data) |

### Implementation

#### 1. Add preload method to GameRepository

```swift
// GameRepository.swift - new method after line 97

/// Preload box scores for multiple games (low priority, non-blocking)
/// Skips scheduled games and uses existing cache/deduplication
func preloadBoxScores(games: [Game]) async {
    let preloadableGames = games.filter { $0.status.isLive || $0.status.isFinal }

    // Serial with small delay to avoid rate limiting
    for game in preloadableGames {
        // getBoxScore already handles cache-first and deduplication
        _ = try? await getBoxScore(gameId: game.id, sport: game.sport)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between requests
    }
}
```

#### 2. Trigger preload in HomeViewModel

```swift
// HomeViewModel.swift - after line 342 in updateGames()

// After games are added to allGames:
Task.detached(priority: .utility) { [weak self] in
    guard let self = self else { return }
    await self.gameRepository.preloadBoxScores(games: newGames)
}
```

#### 3. Handle sport/date changes

Preload triggers automatically because `updateGames()` is called on:
- Sport tab change (line 176)
- Date change (line 188)
- Pull-to-refresh (line 200)

No additional changes needed — each triggers `loadGames()` → `updateGames()` → preload.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        HomeViewModel                             │
├─────────────────────────────────────────────────────────────────┤
│  loadGames()                                                     │
│      │                                                           │
│      ▼                                                           │
│  ScoreboardRepository.getGames()  ──────► UI renders scores      │
│      │                                                           │
│      ▼                                                           │
│  updateGames(newGames)                                           │
│      │                                                           │
│      ├──► Initialize expansion state                             │
│      │                                                           │
│      └──► [NEW] Task.detached {                                  │
│               gameRepository.preloadBoxScores(newGames)          │
│           }                                                      │
│               │                                                  │
│               ▼                                                  │
│           GameRepository                                         │
│               │                                                  │
│               ├── Filter: isLive || isFinal                      │
│               │                                                  │
│               └── For each game:                                 │
│                       getBoxScore() ◄── cache-first              │
│                           │             + deduplication          │
│                           ▼                                      │
│                       CacheManager                               │
│                           │                                      │
│                       ┌───┴───┐                                  │
│                       │ Hit?  │                                  │
│                       └───┬───┘                                  │
│                      yes/ \no                                    │
│                        /   \                                     │
│                    skip   GatewayClient                          │
│                            │                                     │
│                            ▼                                     │
│                        Gateway API                               │
│                        /v1/games/{id}/boxscore                   │
└─────────────────────────────────────────────────────────────────┘
```

## Technical Considerations

### Rate Limiting
- Serial preloading with 50ms delay between requests
- Circuit breaker in GatewayClient (3 failures → 30s cooldown) prevents hammering
- Gateway already caches responses in Redis

### Memory
- CacheManager has `maxMemoryCacheEntries = 100`
- Automatic eviction if exceeded
- Box score data is ~2-5KB per game

### Network
- Preload uses `.utility` task priority (won't block UI)
- Existing `inFlightBoxScoreRequests` prevents duplicate fetches
- If user taps during preload, same in-flight request is reused

### Battery
- Low priority background task
- Consider: only preload on WiFi? (future enhancement)

## Acceptance Criteria

- [x] Tapping a live/final game shows full box score instantly (95%+ of the time)
- [x] Scheduled games still show "No box score available" on tap (no change)
- [x] App startup time does not regress
- [x] No duplicate API calls (preload + user tap share cache)
- [x] Switching sports/dates triggers preload for new games
- [x] Pull-to-refresh triggers fresh preload

## Success Metrics

- **Primary:** Time from tap to full box score visible < 200ms (for preloaded games)
- **Secondary:** No regression in app launch time
- **Monitor:** API call volume increase (expected ~10x, all cached at gateway)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Tap before preload completes | Brief spinner, then data (current behavior) |
| Network failure during preload | Silent failure, on-demand fetch on tap |
| Circuit breaker trips | Preload stops, on-demand fetch still works |
| 50+ games (NCAAM tournament) | All preloaded serially, ~2.5s total preload time |
| App backgrounded during preload | iOS may suspend task, resumes when foregrounded |

## Files to Modify

1. **[GameRepository.swift](XcodProject/BoxScore/BoxScore/Core/Repositories/GameRepository.swift)**
   - Add `preloadBoxScores(games:)` method

2. **[HomeViewModel.swift](XcodProject/BoxScore/BoxScore/Features/Home/HomeViewModel.swift)**
   - Add preload trigger in `updateGames()`

## Testing

### Manual Testing
1. Open app → wait 2s → tap any final game → should expand instantly
2. Switch to NFL tab → wait 2s → tap game → should expand instantly
3. Force-kill app → reopen → tap game immediately → should show spinner briefly

### Automated Testing
- Unit test: `GameRepository.preloadBoxScores()` filters scheduled games
- Unit test: Preload uses existing cache (mock CacheManager)
- Integration test: Preload doesn't duplicate in-flight requests

## Rollback Plan

If issues arise:
1. Remove the `Task.detached` call in `updateGames()` (1 line)
2. App reverts to lazy-loading behavior

No data migrations or API changes required.

## References

- Brainstorm: [2026-01-26-dropdown-speed-brainstorm.md](../brainstorms/2026-01-26-dropdown-speed-brainstorm.md)
- Linear issue: [BOX-15](https://linear.app/boxscores/issue/BOX-15/dropdown-speed)
- Key files:
  - [HomeViewModel.swift:342](XcodProject/BoxScore/BoxScore/Features/Home/HomeViewModel.swift#L342)
  - [GameRepository.swift:74-97](XcodProject/BoxScore/BoxScore/Core/Repositories/GameRepository.swift#L74-L97)
