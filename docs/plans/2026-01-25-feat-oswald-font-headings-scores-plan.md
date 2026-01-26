---
title: Add Oswald Font for Headings and Scores
type: feat
date: 2026-01-25
linear: BOX-11
---

# Add Oswald Font for Headings and Scores

## Overview

Replace the system font with **Oswald Bold** for high-impact text elements: game scores, sport tabs, team abbreviations, and section headings. Small text (stats, captions, player names) stays with the system font for readability.

## Scope

**IN SCOPE (Oswald Bold):**
- Game scores (the big numbers like 120-138)
- Sport tab names (NBA, NFL, NHL, etc.)
- Team abbreviations (LAL, BOS, etc.)
- Conference/section headers (Eastern Conference, etc.)

**OUT OF SCOPE (keep system font):**
- App title "Italics" (preserves italic styling)
- Box score stats tables
- Player names
- Captions and small labels
- Status text (FINAL, LIVE, etc.)

## Technical Approach

### Phase 1: Add Oswald Font to Project

1. Download `Oswald-Bold.ttf` from Google Fonts
2. Add to `XcodProject/BoxScore/BoxScore/Resources/Fonts/`
3. Register in `Info.plist`:

```xml
<key>UIAppFonts</key>
<array>
    <string>Oswald-Bold.ttf</string>
</array>
```

### Phase 2: Create Font Helper in Theme.swift

Add centralized font function to [Theme.swift](../../XcodProject/BoxScore/BoxScore/Core/Config/Theme.swift):

```swift
// MARK: - Fonts

/// Oswald Bold for headings and scores
static func displayFont(size: CGFloat) -> Font {
    .custom("Oswald-Bold", size: size)
}
```

### Phase 3: Replace Fonts in Key Files

| File | Element | Current | New |
|------|---------|---------|-----|
| [GameCardView.swift](../../XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift) | Scores (L157, L176) | `.system(size: 28-32, weight: .bold)` | `Theme.displayFont(size: 28-32)` |
| [GameCardView.swift](../../XcodProject/BoxScore/BoxScore/Features/Home/GameCardView.swift) | Team abbrevs (L87, L119, L148, L189) | `.system(size: 13, weight: .semibold)` | `Theme.displayFont(size: 13)` |
| [SportTabBar.swift](../../XcodProject/BoxScore/BoxScore/Components/Navigation/SportTabBar.swift) | Sport names (L55) | `.system(size: 14, weight: .bold)` | `Theme.displayFont(size: 14)` |
| [StandingsView.swift](../../XcodProject/BoxScore/BoxScore/Features/Standings/StandingsView.swift) | Conference headers (L104) | `.headline.fontWeight(.bold)` | `Theme.displayFont(size: 17)` |
| [GolfLeaderboardView.swift](../../XcodProject/BoxScore/BoxScore/Sports/Golf/GolfLeaderboardView.swift) | Total scores (L180) | `.system(size: 14, weight: .bold)` | `Theme.displayFont(size: 14)` |

## Acceptance Criteria

- [x] Oswald Bold font file added to project
- [x] Font registered in Info.plist
- [x] `Theme.displayFont()` helper created
- [x] Game scores use Oswald Bold
- [x] Sport tabs use Oswald Bold
- [x] Team abbreviations use Oswald Bold
- [x] Conference headers use Oswald Bold
- [x] App title "Italics" unchanged (system font with italic)
- [x] Small text unchanged (captions, stats, player names)

## Fallback Behavior

iOS automatically falls back to the system font if a custom font fails to load. No explicit error handling needed.

## Files to Modify

1. `Info.plist` - Register font
2. `Theme.swift` - Add font helper
3. `GameCardView.swift` - Scores + team abbreviations
4. `SportTabBar.swift` - Sport tab names
5. `StandingsView.swift` - Conference headers
6. `GolfLeaderboardView.swift` - Golf scores

## References

- [Google Fonts - Oswald](https://fonts.google.com/specimen/Oswald)
- Linear: BOX-11
