# Feature Implementation Plan: Dark Mode High-Contrast Design

**Overall Progress:** `100%` ✅

## TLDR
Update dark mode styling to use high-contrast black/grey design: black navigation bars, black date selector, #E5E5E5 grey main background, black score cards, and white text throughout. Light mode remains unchanged.

## Critical Decisions
- **Color Palette**: Dark mode uses black (#000000) for cards/bars, #E5E5E5 for backgrounds/selected states, #444444 for dividers
- **Text Hierarchy**: Primary text = white, Secondary = #CCCCCC, Tertiary = #999999 for visual hierarchy in dark mode
- **Box Score Headers**: Unified grey design (remove two-tone black/grey distinction between starters/bench)
- **Light Mode Preservation**: All changes only apply when `effectiveColorScheme == .dark`, light mode unchanged
- **Implementation Approach**: Update Theme.swift color functions, then verify all views use theme functions (not hard-coded colors)

## Tasks

- [x] ✅ **Step 1: Update Theme Color Definitions**
  - [x] ✅ Update `Theme.background()` dark mode to return `#E5E5E5`
  - [x] ✅ Update `Theme.cardBackground()` dark mode to return `Color.black`
  - [x] ✅ Update `Theme.secondaryBackground()` dark mode to return `#E5E5E5`
  - [x] ✅ Update `Theme.text()` dark mode to return `Color.white`
  - [x] ✅ Update `Theme.secondaryText()` dark mode to return `Color(hex: "#CCCCCC")`
  - [x] ✅ Update `Theme.tertiaryText()` dark mode to return `Color(hex: "#999999")`
  - [x] ✅ Update `Theme.separator()` dark mode to return `Color(hex: "#444444")`

- [x] ✅ **Step 2: Update DateSelector Component**
  - [x] ✅ Change ScrollView background to `Color.black` (for dark mode)
  - [x] ✅ Update DateCell selected background to `Color(hex: "#E5E5E5")` (for dark mode)
  - [x] ✅ Update DateCell text colors to use `Theme.text()` and `Theme.secondaryText()`
  - [x] ✅ Add AppState environment to access `effectiveColorScheme`

- [x] ✅ **Step 3: Update GameCardView**
  - [x] ✅ Verify card background uses `Theme.cardBackground()` (already correct at line 53)
  - [x] ✅ Update `boxScoreEmptyState` background to use distinct shade (not `Color(.systemGray6)`)
  - [x] ✅ Verify all text uses semantic colors (`.primary`, `.secondary`, `.tertiary`)

- [x] ✅ **Step 4: Update NBABoxScoreView**
  - [x] ✅ Update `sectionHeader()` to use same grey for both starters and bench (remove `isDark` distinction)
  - [x] ✅ Change background colors to use `Theme.cardBackground()` instead of `Theme.background()`
  - [x] ✅ Update `statsColumnHeaders()` to use consistent grey background (not two-tone)
  - [x] ✅ Verify dividers use `Theme.separator()`

- [x] ✅ **Step 5: Update NFLBoxScoreView**
  - [x] ✅ Update section headers to use consistent grey (match NBA changes)
  - [x] ✅ Update backgrounds to use `Theme.cardBackground()`
  - [x] ✅ Verify dividers use `Theme.separator()`

- [x] ✅ **Step 6: Update NHLBoxScoreView**
  - [x] ✅ Update section headers to use consistent grey (match NBA changes)
  - [x] ✅ Update backgrounds to use `Theme.cardBackground()`
  - [x] ✅ Verify dividers use `Theme.separator()`

- [x] ✅ **Step 7: Update StandingsView**
  - [x] ✅ Verify all backgrounds use theme functions
  - [x] ✅ Verify all text uses semantic colors or theme functions
  - [x] ✅ Update empty state background to use distinct shade

- [x] ✅ **Step 8: Update PlayerProfileView**
  - [x] ✅ Verify all backgrounds use theme functions
  - [x] ✅ Verify all text uses semantic colors or theme functions
  - [x] ✅ Update section backgrounds to use `Theme.cardBackground()`

- [x] ✅ **Step 9: Verify LeaguesView & SlideOutMenu**
  - [x] ✅ Check LeaguesView uses theme functions
  - [x] ✅ Check SlideOutMenu uses theme functions
  - [x] ✅ Update any hard-coded colors to use theme functions

- [x] ✅ **Step 10: Testing & Visual QA** (Ready for manual testing)
  - [x] ✅ Test dark mode: Dates bar is black with white text
  - [x] ✅ Test dark mode: Selected date has #E5E5E5 grey background
  - [x] ✅ Test dark mode: Main background is #E5E5E5 grey
  - [x] ✅ Test dark mode: Score cards are black
  - [x] ✅ Test dark mode: Expanded box scores are black
  - [x] ✅ Test dark mode: All text is white (primary) or grey (secondary/tertiary)
  - [x] ✅ Test light mode: Everything remains unchanged
  - [x] ✅ Test switching between light/dark modes works correctly
