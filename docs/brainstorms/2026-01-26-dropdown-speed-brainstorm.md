---
date: 2026-01-26
topic: dropdown-speed
linear-issue: BOX-15
---

# Dropdown Speed: Instant Box Score Expansion

## What We're Building

Eliminate the two-step loading experience when expanding game cards. Currently, tapping a game shows the team header first with a spinner, then loads player stats separately. Users should see the full box score instantly when they tap.

**Goal:** When a user taps a game card, the dropdown expands fully with all player stats visible—no intermediate loading states.

## Why This Approach

We evaluated three approaches:

| Approach | Verdict |
|----------|---------|
| **A: Background Preloading** | ✅ Chosen - Simple, flexible, solves the problem |
| B: Bundled API Response | Rejected - Slower first paint, less flexible |
| C: Optimistic UI/Streaming | Rejected - More complex, masks latency but doesn't fix it |

**Background Preloading** wins because:
- Keeps current architecture intact
- Easy to adjust preload scope later (visible games → all games)
- Minimal changes required
- 95%+ of taps will feel instant

## Key Decisions

1. **Two-phase loading strategy**
   - Phase 1: Load scores as fast as possible (user sees this first)
   - Phase 2: Preload box scores for visible games immediately after
   - Rationale: Scores are visible; box scores are hidden until tapped

2. **Preload scope: Visible games only (~6)**
   - Minimizes API calls while ESPN is the data source
   - Rationale: User can't tap what they can't see
   - **Flexibility note:** Architecture should support expanding to "all games" later when API costs are controlled

3. **Animation behavior: Expand fully with data**
   - No intermediate states (team header only, spinner, etc.)
   - Dropdown goes from collapsed → fully expanded with stats
   - Rationale: This is the perceived "instant" experience

4. **Edge case: Tap before preload completes**
   - Show brief spinner (current behavior)
   - Rationale: Honest UX for rare edge case; avoids complexity of skeleton UI

## Open Questions

- Should we prioritize preloading live games over final games? (Live = more likely to be tapped)
- What's the right cache TTL for preloaded box scores? (Current: different for live vs final)
- Should scroll position affect preload priority? (Preload games at top of list first)

## Success Criteria

- Tapping a visible game card shows full box score with no spinner (95%+ of the time)
- App startup time does not regress
- No duplicate API calls (preload + user tap should share cache)

## Next Steps

→ `/workflows:plan` for implementation details
