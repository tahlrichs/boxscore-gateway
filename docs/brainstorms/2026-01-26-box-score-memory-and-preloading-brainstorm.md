# Box Score Memory and Preloading Optimization

**Date:** 2026-01-26
**Linear Issues:** BOX-16, BOX-17
**Status:** Ready for Planning

## What We're Building

Two related optimizations for better performance and memory management:

1. **Parallel box score preloading** - Load multiple game stats at once instead of one-by-one
2. **Smart memory management** - Keep recent games in fast memory, save older games to disk

## Why This Approach

### The Problems

**Preloading is slow:** Currently loads game stats one at a time with 50ms delays. With 10 games, that's 500ms minimum before all stats are ready.

**Memory grows unbounded:** The `allGames` array keeps every game you've viewed during a session. Switching between dates and sports causes memory to accumulate indefinitely.

### Our Solution

Leverage the existing two-layer cache (memory + disk) that's already in place for box scores. Rather than inventing new infrastructure, we extend it to handle games intelligently.

**For preloading:** Load 3 games in parallel. This balances speed (3x faster) with being respectful to ESPN's servers.

**For memory:** Keep today's games in fast memory. Automatically save older games to disk. When you tap an old game, it loads from disk (nearly instant) and refreshes from ESPN if stale.

## Key Decisions

### 1. Parallel Preloading Concurrency: 3

**Decision:** Load 3 box scores simultaneously using Swift's `TaskGroup`.

**Rationale:**
- Conservative enough to not overwhelm ESPN
- Still 3x faster than serial loading
- Easy to adjust later if needed

### 2. Memory Retention: Today's Games Only

**Decision:** Keep games from today (and any game currently being viewed) in the `allGames` memory array. Older games get evicted but remain accessible via disk cache.

**Rationale:**
- Most users care about today's games
- Disk cache provides near-instant access to older games
- Follows the existing `CacheManager` pattern already in the app

### 3. Staleness Policy for Finished Games

Stats can be corrected after games end, so we need a refresh strategy:

| Game Age | Refresh If Cached Data Is Older Than |
|----------|--------------------------------------|
| Ended today/yesterday | 30 minutes |
| Ended 2-7 days ago | 6 hours |
| Ended 1+ weeks ago | 24 hours |

**Rationale:**
- Most stat corrections happen within 24-48 hours
- After a week, stats are essentially final
- Minimizes ESPN API calls for old games

### 4. Live Games: No Change

**Decision:** Live games continue to poll for updates every few seconds as they do now.

**Rationale:** Real-time updates during games are the core value proposition.

## Implementation Notes

### Files to Modify

- `HomeViewModel.swift` - Memory pruning for `allGames` array
- `GameRepository.swift` - Parallel preloading with `TaskGroup`
- `CachePolicy.swift` - Age-based staleness thresholds

### Existing Infrastructure to Use

- `CacheManager` already handles two-layer caching (memory + disk)
- `CachePolicy` already supports different TTL values
- Box scores already persist to disk with the `finalBoxScore` policy

## Open Questions

1. **Expansion state cleanup:** The `expansionState` dictionary also grows unboundedly. Should we prune it alongside `allGames`?

2. **Background cleanup timing:** When should we run memory cleanup - on date change, sport change, or periodically?

3. **Loading indicator for old games:** Should we show a loading state when fetching an old game from disk + ESPN, or is it fast enough to skip?

## Next Steps

Run `/workflows:plan` to create implementation tasks for these changes.
