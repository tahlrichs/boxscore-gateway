---
title: "feat: Emphasize Winning Team"
type: feat
date: 2026-02-08
linear: BOX-44
brainstorm: docs/brainstorms/2026-02-08-emphasize-winning-team-brainstorm.md
deepened: 2026-02-08
---

# feat: Emphasize Winning Team

## Enhancement Summary

**Deepened on:** 2026-02-08
**Review agents used:** code-simplicity-reviewer, pattern-recognition-specialist, performance-oracle, architecture-strategist, learnings-researcher

### Key Improvements
1. Renamed view-level flags from `awayWins`/`homeWins` to `showAwayIndicator`/`showHomeIndicator` for semantic clarity
2. Added HStack layout stability guidance — use fixed-width placeholders to prevent layout drift between game states
3. Incorporated dark mode testing guidance from BOX-27 learnings and font-mismatch awareness from Oswald custom font docs

### Review Agent Consensus
- **Architecture:** `GameResult` enum on the `Game` model is the correct placement — keeps domain logic testable and separated from the view. Do NOT couple to `TeamSide` (different architectural layers).
- **Performance:** All clear at 15 cards. Computed property is O(1), SF Symbols are vector-cached, `.opacity(1.0)` is a GPU no-op.
- **Simplicity:** Plan is already lean. The enum is justified for testability/reusability despite the YAGNI argument for inline booleans.

---

## Overview

When a game is final, visually distinguish the winning team from the losing team on the scoreboard game card. A small triangle indicator points at the winner, and the losing team's score + abbreviation are dimmed. This lets users see who won at a glance without comparing numbers.

**Scope:** iOS only. Final games only. No gateway changes.

## Proposed Solution

Add winner-determination logic to the `Game` model and update `GameCardView.liveOrFinalGameLayout` to conditionally style the winning and losing sides.

### Changes by File

#### 1. `GameModels.swift` — Add winner logic

**File:** `XcodProject/BoxScore/BoxScore/Shared/Models/GameModels.swift` (~line 265, on the `Game` struct)

Add a nested enum and computed property that returns which side won:

```swift
// GameModels.swift — nested inside Game struct
enum GameResult: Equatable {
    case awayWin
    case homeWin
    case tie
}

var result: GameResult? {
    guard status.isFinal,
          let away = awayScore,
          let home = homeScore else { return nil }
    if away > home { return .awayWin }
    if home > away { return .homeWin }
    return .tie
}
```

Returns `nil` for live/scheduled games or if scores are missing — the view treats `nil` as "no emphasis."

**Research Insights:**

- **Placement is correct.** `GameModels.swift` already hosts domain enums (`GameStatus`, `Sport`, `BoxScorePayload`). A `GameResult` that answers "who won?" is pure domain logic with no UI dependency. Placing it on the model enables testability (construct a `Game`, assert `.result`) and future reuse (notifications, statistics, sharing).
- **Do NOT couple to `TeamSide`.** `TeamSide` lives in `HomeViewModel.swift` and serves a UI coordination role (which box score panel is expanded). Referencing it from the model layer would create an upward dependency violation.
- **`Equatable` conformance** is explicit for clarity, though Swift auto-synthesizes it for simple enums. Enables clean SwiftUI diffing.

#### 2. `GameCardView.swift` — Update `liveOrFinalGameLayout`

**File:** `XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift` (lines 136-194)

Modify the layout to:

1. **Compute emphasis flags** at the top of the layout:

```swift
let result = game.result
let showAwayIndicator = result == .awayWin || result == .tie
let showHomeIndicator = result == .homeWin || result == .tie
let awayDimmed = result == .homeWin
let homeDimmed = result == .awayWin
```

> **Naming note:** Use `showAwayIndicator`/`showHomeIndicator` instead of `awayWins`/`homeWins` — in a tie, both are `true`, and "wins" would be semantically misleading.

2. **Add triangle indicators** between score and center column:

```swift
// After away score, before center VStack
if showAwayIndicator {
    Image(systemName: "arrowtriangle.left.fill")
        .font(.system(size: 8))
        .foregroundStyle(.primary)
        .accessibilityLabel("\(game.awayTeam.abbreviation) wins")
} else if game.status.isFinal {
    Color.clear.frame(width: 8)
}

// After center VStack, before home score
if showHomeIndicator {
    Image(systemName: "arrowtriangle.right.fill")
        .font(.system(size: 8))
        .foregroundStyle(.primary)
        .accessibilityLabel("\(game.homeTeam.abbreviation) wins")
} else if game.status.isFinal {
    Color.clear.frame(width: 8)
}
```

3. **Dim losing team's score and abbreviation** (not logo):

```swift
// Away score
Text("\(game.awayScore ?? 0)")
    .font(Theme.displayFont(size: scoreSize))
    .foregroundStyle(.primary)
    .opacity(awayDimmed ? 0.7 : 1.0)
    .fixedSize()
    .frame(maxWidth: .infinity)

// Away abbreviation
Text(game.awayTeam.abbreviation)
    .font(Theme.displayFont(size: 13))
    .foregroundStyle(.primary)
    .opacity(awayDimmed ? 0.7 : 1.0)

// (Same pattern for home score and home abbreviation with homeDimmed)
```

4. **Logos stay full brightness** — no opacity change on `teamLogo()` calls.

**Research Insights:**

- **HStack layout stability (MEDIUM concern).** The current HStack has 5 children with `.frame(maxWidth: .infinity)` on scores. Adding conditional triangle `Image` elements changes how flexible space is distributed between game states (live vs final). The `Color.clear.frame(width: 8)` placeholder in the `else if game.status.isFinal` branch ensures the HStack always has the same number of elements for final games, preventing layout shift when one team wins vs the other. For non-final games (live), no placeholder is needed — neither triangle appears and the layout matches the existing behavior.
- **`.opacity(1.0)` is a GPU no-op.** Core Animation skips compositing entirely when opacity is 1.0, so the ternary adds zero overhead for the winning side.
- **`.opacity(0.7)` on individual Text views is ideal.** Applying opacity to individual views (not a container) avoids group compositing overhead. At 2-4 Text views per card across 15 cards, the GPU composites at most 60 tiny layers — negligible.
- **Font mismatch awareness.** Scores use `Theme.displayFont(size: 32)` (Oswald Bold custom font). The triangle SF Symbol renders in the system font. At 8pt the triangle is small enough that the font difference is not visually jarring — it reads as a distinct indicator element, not as typography.
- **Accessibility.** Use team-specific labels like `"\(game.awayTeam.abbreviation) wins"` instead of generic `"Winner"` for better VoiceOver context.

#### 3. `NBAMockData.swift` — Add tied final mock game

**File:** `XcodProject/BoxScore/BoxScore/Sports/NBA/NBAMockData.swift`

Add one mock game with equal final scores (e.g., 105-105 FINAL) so SwiftUI previews can verify the tied-final treatment.

> **Note:** While ties don't occur in NBA/NFL/NHL regulation, they are possible in data edge cases (corrupted scores, suspended games) and the user explicitly requested this behavior in the brainstorm. The mock game enables visual verification of the tie path in Xcode previews.

### Layout Structure (After Changes)

```
Away wins (final):
[AwayLogo+Abbr] [AwayScore] [◀] [FINAL/@] [·] [HomeScore] [HomeLogo+Abbr]
── full opacity ── full ───       center   clear  ── 70% ──   ── 70%+full ──

Home wins (final):
[AwayLogo+Abbr] [AwayScore] [·] [FINAL/@] [▶] [HomeScore] [HomeLogo+Abbr]
── 70%+full ───  ── 70% ──  clear  center       ── full ──  ── full opacity ──

Tied final:
[AwayLogo+Abbr] [AwayScore] [◀] [FINAL/@] [▶] [HomeScore] [HomeLogo+Abbr]
── full opacity ── full ───       center        ── full ──  ── full opacity ──

Live/Scheduled: no triangles, no placeholders, no dimming (unchanged)
```

`[·]` = `Color.clear.frame(width: 8)` placeholder — keeps HStack element count consistent for all final games.

## Technical Considerations

- **Dark mode contrast:** 70% opacity on `.primary` text over pure black card backgrounds (`#000000`) produces ~`#B3B3B3` in dark mode — still readable against the `#1A1A1A` screen background. Per BOX-27 learnings, always use `Theme.*` methods for background colors and test against the established color hierarchy (nav=black, card=black, screen=#1A1A1A).
- **Layout stability:** Fixed-width `Color.clear` placeholders prevent HStack flex-space redistribution between winner/loser states. The triangle itself is ~6-8px wide at 8pt. Test with 3-digit NBA scores (e.g., 156) on iPhone SE to confirm no clipping.
- **Animation:** SwiftUI implicitly animates opacity changes during state transitions (live → final on data refresh). No explicit animation code needed — `Theme.standardAnimation` (`.easeInOut(duration: 0.3)`) will apply through existing `.animation()` modifiers on the parent. The triangle appearance will also be implicitly animated.
- **Accessibility:** Triangles get team-specific labels (`"\(team.abbreviation) wins"`). Dimmed text is still readable by VoiceOver since the actual `Text` content is unchanged.
- **Guard rail:** `game.result` returns `nil` for non-final games, so the view naturally falls through to the current behavior. No risk of affecting live games.
- **Performance:** All changes are O(1) per card. SF Symbols are vector-cached after first use. At 15 cards on screen, the total overhead is negligible — cheaper than the existing raster team logo lookups.

## Acceptance Criteria

- [x] Final game cards show a small left-pointing triangle next to the away score when away team wins
- [x] Final game cards show a small right-pointing triangle next to the home score when home team wins
- [x] Tied final games show triangles on both sides, no dimming
- [x] Losing team's score and abbreviation are dimmed (~70% opacity)
- [x] Losing team's logo remains full brightness
- [x] Live games show no triangles and no dimming (unchanged)
- [x] Scheduled games show no triangles and no dimming (unchanged)
- [ ] Works correctly in both light and dark mode
- [ ] No layout clipping with 3-digit scores on smallest device
- [x] Triangle has team-specific VoiceOver accessibility label
- [x] HStack layout is stable — no visual shift between winner/loser states for final games

## References

- Brainstorm: `docs/brainstorms/2026-02-08-emphasize-winning-team-brainstorm.md`
- Current layout: [GameCardView.swift:136-194](XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift#L136-L194)
- Game model: [GameModels.swift:265](XcodProject/BoxScore/BoxScore/Shared/Models/GameModels.swift#L265)
- Theme colors: [Theme.swift](XcodProject/BoxScore/BoxScore/Core/Config/Theme.swift)
- Dark mode contrast learnings: `docs/solutions/ui-bugs/dark-mode-card-contrast.md`
- Gradient overlay pattern: `docs/solutions/ui-bugs/season-stats-order-gradient-overlay-box45.md`
- Custom font docs: `docs/solutions/ios-development/custom-font-implementation-oswald.md`
