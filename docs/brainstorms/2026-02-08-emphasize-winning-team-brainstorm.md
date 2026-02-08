# Emphasize Winning Team

**Date:** 2026-02-08
**Linear:** BOX-44

## What We're Building

Visually emphasize the winning team on final game cards so you can tell who won at a glance — without comparing numbers yourself. This adds a small triangle indicator pointing at the winner, bolds the winning score, and slightly dims the losing team.

**Applies to final games only.** Live and scheduled games stay as-is.

## Key Decisions

1. **Winner indicator**: Small filled triangle (SF Symbol `arrowtriangle.left.fill` / `arrowtriangle.right.fill`) positioned between the "FINAL" status text and the winning team's score. Base faces inward (toward center), point faces outward (toward the winner).
2. **Triangle style**: Small and subtle, matches the score text color (`.primary`) — no accent or team colors.
3. **Losing team dimming**: Score and team abbreviation dimmed to ~70% opacity. Logo stays full brightness.
4. **Tied final games**: Both teams get the winner treatment (bold + triangle on both sides). Neither team is dimmed.
5. **Rendering approach**: SF Symbols for the triangle — native, scalable, automatic dark/light mode support.

## What Exists

- `GameCardView.swift` — `liveOrFinalGameLayout` (line 136) renders scores identically for both teams with Oswald-Bold font and `.primary` color.
- `GameModels.swift` — `Game` has `awayScore: Int?`, `homeScore: Int?`, and `status.isFinal` but no winner-determination logic.
- `Theme.swift` — `displayFont(size:)` is already Oswald-Bold. `Theme.green` exists labeled "wins" but won't be used here.
- Team colors are loaded for box score headers but not relevant to this feature.

## Visual Spec

```
FINAL GAME (away team wins):
  [AwayLogo] [AwayAbbr]  [AwayScore] ◀ FINAL ▶ [HomeScore]  [HomeAbbr] [HomeLogo]
  ─── full opacity ────  ── bold ───              ── 70% ──  ── 70% ──  full opacity

FINAL GAME (home team wins):
  [AwayLogo] [AwayAbbr]  [AwayScore]   FINAL ▶ [HomeScore]  [HomeAbbr] [HomeLogo]
  full opacity ── 70% ──  ── 70% ───           ── bold ────  full opacity

TIED FINAL:
  [AwayLogo] [AwayAbbr]  [AwayScore] ◀ FINAL ▶ [HomeScore]  [HomeAbbr] [HomeLogo]
  ─── full opacity ────  ── bold ───              ── bold ──  ─── full opacity ────
```

## Open Questions

None — ready for planning.

## Next Step

Run `/workflows:plan` to create the implementation plan.
