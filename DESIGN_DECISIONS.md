# BoxScore Design Decisions

This document tracks design decisions made for the BoxScore iOS app.

## Game Cards

### Card Layout
- **Separated cards**: Each game card is visually separated with spacing between cards
- **Rounded corners**: 6px corner radius
- **Shadow**: Subtle shadow (`opacity: 0.08, radius: 4, y: 2`) for depth
- **Horizontal padding**: 10px from screen edges
- **Vertical spacing**: 8px between cards
- **Background**: White cards on grouped background

### Score Display

#### Live/Final Games
- Team logo (36pt) above abbreviation (13pt semibold)
- Logo+abbreviation in fixed 50pt width columns on edges
- Scores centered between logo column and status column
- Status/@ in center fixed 50pt width column

#### Final Games vs Live Games
| Element | Final | Live |
|---------|-------|------|
| Score size | 32pt | 28pt |
| Score weight | Heavy | Bold |
| Status text | Bold | Medium |
| Status color | Primary | Red |

#### Scheduled Games
- Same logo+abbreviation layout as live/final
- No scores shown
- Time displayed in center
- Teams are tappable to expand box score (for roster preview)

### Expandable Box Scores
- Tap team logo/abbreviation to expand that team's box score
- Only one team's box score visible at a time per card
- Yellow highlight (15% opacity) on expanded team's logo area
- Smooth animation on expand/collapse (0.2s ease-in-out)

## Navigation

### Sport Tab Bar (Top)
- Black background
- White text for sport names
- Selected sport: Bold weight
- Unselected sport: Medium weight
- **Star button**: Yellow star icon on left side for favorites (separate from sport tabs)

### Bottom Tab Bar
- Black background
- Selected tab: White, bold
- Unselected tab: Gray, regular weight

## Typography

### Game Cards
- Team abbreviation: 13pt semibold
- Score (final): 32pt heavy
- Score (live): 28pt bold
- Status text: 11pt (bold for final, medium for live)
- @ symbol: 11pt regular, secondary color

### Box Scores
- Section headers: 9pt semibold
- Player names: 10pt regular
- Stats: 10pt regular (semibold for highlighted values)
- Column headers: 9pt medium

## Colors

### Primary UI
- Card background: White
- App background: System grouped background
- Primary text: System primary
- Secondary text: System secondary
- Tertiary text: System tertiary

### Accents
- Live game indicator: Red
- Favorites star: Yellow
- Expanded team highlight: Yellow at 15% opacity

### Box Score Headers
- Starters section: Black background, white text
- Bench section: System gray4 background

## Spacing

### Game Cards
- Card internal padding: 16px horizontal, 16px vertical
- Logo size: 36pt
- Team column width: 50pt (fixed)
- Status column width: 50pt (fixed)
- Logo to abbreviation spacing: 2pt

### Box Scores
- Row height: 24pt
- Section header height: 22pt
- Player name column: 85pt width
- Horizontal padding in rows: 6pt

## Animations
- Box score expand/collapse: 0.2s ease-in-out
- Scroll to expanded content: 0.15s delay after expand
