---
title: "fix: Empty box scores for Jan 31st games"
type: fix
date: 2026-02-03
---

# fix: Empty box scores for Jan 31st games

Games on Saturday Jan 31st show "No box score available" even though they display "FINAL" with real scores. This is caused by corrupted cache files that were stored when ESPN returned `status: "final"` before populating player statistics.

## Problem

A race condition during ESPN API timing:
1. Gateway fetched box scores when ESPN reported `status: "final"`
2. ESPN had not yet populated player statistics at that moment
3. `storeBoxScore()` only checks `status === "final"` before permanent storage
4. Empty box scores (`starters: []`, `score: 0`) were permanently stored
5. iOS receives cached empty data and shows "No box score available"

**Corrupted files:**
- `nba_401810506.json`
- `nba_401810507.json`

## Acceptance Criteria

- [x] Delete corrupted box score files
- [x] Add validation guard to prevent storing empty box scores
- [ ] Jan 31st games display box scores correctly after fix

## MVP

### Task 1: Delete corrupted files

```bash
rm gateway/data/boxscores/nba_401810506.json gateway/data/boxscores/nba_401810507.json
```

### Task 2: Add inline validation guard

**File:** `gateway/src/cache/BoxScoreStorage.ts`

Add after the existing status check in `storeBoxScore()`:

```typescript
export async function storeBoxScore(gameId: string, boxScore: BoxScoreResponse): Promise<void> {
  // Only store final games
  if (boxScore.game.status !== 'final') {
    logger.debug('BoxScoreStorage: Skipping non-final game', { gameId, status: boxScore.game.status });
    return;
  }

  // Reject empty box scores (ESPN race condition protection)
  const league = gameId.split('_')[0];
  if ((league === 'nba' || league === 'ncaam') &&
      (boxScore.boxScore.homeTeam as any).starters?.length < 5) {
    logger.warn('BoxScoreStorage: Rejecting empty box score', { gameId });
    return;
  }

  // ... rest of existing storage logic
```

## Verification

1. Delete the corrupted files
2. Start gateway: `cd gateway && npm run dev`
3. In iOS app, navigate to Jan 31st and tap a previously broken game
4. Box score should now load fresh from ESPN

## References

- Brainstorm: [docs/brainstorms/2026-02-03-empty-box-scores-jan31-brainstorm.md](../brainstorms/2026-02-03-empty-box-scores-jan31-brainstorm.md)
- Storage logic: [gateway/src/cache/BoxScoreStorage.ts](../../gateway/src/cache/BoxScoreStorage.ts)
