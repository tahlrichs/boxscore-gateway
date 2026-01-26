---
title: Custom Oswald Bold Font Implementation for iOS App
category: ios-development
tags:
  - ios
  - swiftui
  - fonts
  - theme
  - custom-fonts
  - typography
module: BoxScore iOS App
symptoms: wanting distinctive typography for scores/headings
created_date: 2026-01-25
solution_summary: |
  Added Oswald Bold custom font to iOS app for high-impact text rendering.
  Implemented font registration via Info.plist, created Theme helper function,
  and updated 4 views with validation and fallback handling.
key_learnings:
  - iOS silently falls back to system font if custom font fails to load
  - Font name in .custom() must match the font's internal name, not filename
  - Debug validation helps catch font loading issues during development
---

# Custom Oswald Bold Font Implementation for iOS App

## Problem

Needed distinctive typography for high-impact text elements (game scores, team abbreviations, sport tabs, conference headers) to give the app a more distinctive visual identity separate from the standard iOS system font.

## Solution

### 1. Download Font File

Download the desired font file from [Google Fonts](https://fonts.google.com/) or their GitHub repository:
- Font: Oswald Bold
- Format: `.ttf` (TrueType Font)
- File size: ~108KB
- Source: `https://github.com/googlefonts/OswaldFont/raw/main/fonts/ttf/Oswald-Bold.ttf`

### 2. Add Font to Project

1. Create folder structure: `Resources/Fonts/`
2. Place font file (e.g., `Oswald-Bold.ttf`) in the Fonts folder
3. Verify the font is added to your app target in Xcode

### 3. Register Font in Info.plist

```xml
<key>UIAppFonts</key>
<array>
    <string>Oswald-Bold.ttf</string>
</array>
```

### 4. Create Font Helper in Theme.swift

```swift
struct Theme {
    // MARK: - Fonts

    /// Oswald Bold for headings and scores (high-impact text)
    static func displayFont(size: CGFloat) -> Font {
        .custom("Oswald-Bold", size: size)
    }
}
```

### 5. Add Debug Validation

```swift
// MARK: - Font Validation (Debug Only)

#if DEBUG
/// Validates that custom fonts are properly loaded. Call from app init.
static func validateFonts() {
    let fontName = "Oswald-Bold"
    if UIFont(name: fontName, size: 12) == nil {
        assertionFailure("Font '\(fontName)' not loaded. Check Info.plist and bundle.")
    }
}
#endif
```

### 6. Use in Views

```swift
// Game scores (dynamic size based on game state)
let scoreSize: CGFloat = game.status.isFinal ? 32 : 28
Text("\(game.awayScore ?? 0)")
    .font(Theme.displayFont(size: scoreSize))

// Team abbreviations
Text(game.awayTeam.abbreviation)
    .font(Theme.displayFont(size: 13))

// Sport tabs
Text(sport.displayName)
    .font(Theme.displayFont(size: 14))

// Conference headers
Text(conference)
    .font(Theme.displayFont(size: 17))
```

## Files Modified

| File | Change |
|------|--------|
| `Resources/Fonts/Oswald-Bold.ttf` | New font file (108KB) |
| `Info.plist` | Added UIAppFonts array |
| `Theme.swift` | Added displayFont() helper + debug validation |
| `GameCardView.swift` | Scores + team abbreviations |
| `SportTabBar.swift` | Sport tab names |
| `StandingsView.swift` | Conference headers |
| `GolfLeaderboardView.swift` | Golf total scores |

## Key Learnings

1. **Silent fallback** - iOS doesn't warn if a font fails to load; it just uses the system font
2. **PostScript name** - Use the font's internal PostScript name in `.custom()`, not the filename
3. **Debug validation** - Add assertionFailure in DEBUG builds to catch font issues early
4. **Centralize access** - Use a Theme helper to avoid hardcoding font names throughout codebase

## Prevention Strategies

### 1. Always Validate at Startup

```swift
#if DEBUG
static func validateFonts() {
    if UIFont(name: "Oswald-Bold", size: 12) == nil {
        assertionFailure("Font not loaded")
    }
}
#endif
```

### 2. Verify PostScript Name

The font's internal name may differ from the filename. Check in Font Book on macOS:
- Right-click font file → "Get Info" → Look for "PostScript name"

### 3. Test on Fresh Install

1. Delete app from simulator
2. Clean build folder (⌘⇧K)
3. Rebuild and verify fonts appear correctly

### 4. Remove Dead Code

When switching from system fonts to custom fonts, remove unused weight variables:

```swift
// BEFORE (dead code after migration)
let scoreWeight: Font.Weight = game.status.isFinal ? .heavy : .bold  // Unused!

// AFTER (clean)
let scoreSize: CGFloat = game.status.isFinal ? 32 : 28
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Font not appearing | Verify Info.plist has correct filename including `.ttf` |
| Assertion failure | Check font file is in app target's Copy Bundle Resources |
| Wrong font rendering | Verify PostScript name matches what's in `.custom()` |

## Related

- [Google Fonts - Oswald](https://fonts.google.com/specimen/Oswald)
- Linear: BOX-11
- Branch: `feat/oswald-font-headings-scores`
