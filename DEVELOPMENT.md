# BoxScore App - Development Documentation

> A living document tracking architecture decisions, implementation details, and project evolution.

---

## Project Overview

**Goal**: Build a fast, native iOS app for viewing NBA and NFL box scores with a focus on speed of access to scores and live information.

**App Name**: Italics (displayed in italic font in the top nav bar)

**Target**: iOS 17+ (to leverage `@Observable` for better performance)

**Current Status**: MVP with mock data, full navigation, expandable box scores

---

## How the App Works

### Navigation Flow

1. **Top Navigation Bar** (black)
   - Hamburger menu icon (left) - placeholder for future menu
   - "Italics" title (center, italic font)
   - Blue circle profile icon (right) - placeholder for future profile

2. **Sport Tabs** (black bar with yellow indicator)
   - Horizontally scrollable: NBA, NFL, NCCAF, NCAAM, NHL, MLB
   - Yellow bar on left indicates selected sport
   - Tapping a sport filters games to only show that sport

3. **Date Selector** (white bar)
   - Horizontally scrollable dates (±7 days from today)
   - Format: "MON\nJan 12"
   - Selected date highlighted with gray background
   - Tapping a date filters games to only show that date

4. **Game Cards** (main content area)
   - White cards with thin gray border
   - Shows: `AWAY_ABBR  SCORE  STATUS/@  SCORE  HOME_ABBR`
   - Tap left side (away team) to expand away box score
   - Tap right side (home team) to expand home box score
   - Only ONE box score open at a time per card
   - Tapping the other team replaces the currently open box score

5. **Bottom Tab Bar** (black)
   - Three tabs: Top | Scores | Standings
   - White text with vertical dividers
   - "Scores" is active, shows game cards
   - "Top" and "Standings" are placeholders (Coming Soon)

### Box Score Behavior

**NBA Box Score:**
- Black header with team name (e.g., "LOS ANGELES LAKERS")
- Column headers: MIN, PTS, FG (more columns available)
- **Starters section** (dark black header)
- **Bench section** (gray header) - includes DNP players at bottom
- DNP players show: `J. Vanderbilt    DNP - Injury - Foot`
- Player names formatted as "L. James" (First Initial. Last Name)

**NFL Box Score:**
- Tab-based interface: Offense | Defense | Special Teams
- Each tab shows relevant stat sections (Passing, Rushing, etc.)
- Sections always visible when tab is selected

### Filtering Logic

- Games filtered by BOTH selected sport AND selected date
- Empty state shown when no games match the filters
- Mock data has games on "today" for testing

---

## Architecture Decisions

### Initial Decisions (Project Setup)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | Native iOS (SwiftUI) | Best performance for "speed, speed, speed" requirement |
| Min iOS Version | iOS 17+ | Enables `@Observable` macro for simpler, faster state management |
| State Management | `@Observable` + `@State` | More performant than `ObservableObject`, automatic view updates |
| Data Architecture | Mock data first | Allows UI development without API dependency; easy to swap later |
| Sport Extensibility | Enum-based `BoxScorePayload` | Type-safe way to handle sport-specific data |

### UI Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Dark navigation bars | Black top/bottom bars | Matches mockup, provides visual hierarchy |
| Single box score expansion | Only one team visible at a time | Cleaner UX, less overwhelming |
| DNP in Bench section | No separate DNP header | Cleaner list, players are still on the bench |
| Tap-to-expand (no chevrons) | Tap score area to expand | Simpler, cleaner card design |

---

## Project Structure

```
BoxScore/
├── XcodProject/
│   └── BoxScore/
│       ├── BoxScore.xcodeproj
│       └── BoxScore/
│           ├── App/
│           │   └── BoxScoreApp.swift           # App entry point
│           ├── Features/
│           │   └── Home/
│           │       ├── HomeView.swift          # Main container with filtering
│           │       ├── HomeViewModel.swift     # @Observable state + filtering
│           │       └── GameCardView.swift      # Tappable game cards
│           ├── Components/
│           │   ├── Navigation/
│           │   │   ├── TopNavBar.swift         # Black bar: ☰ Italics 🔵
│           │   │   ├── SportTabBar.swift       # Black bar with yellow indicator
│           │   │   ├── DateSelector.swift      # White bar: MON Jan 12
│           │   │   └── BottomTabBar.swift      # Black bar: Top|Scores|Standings
│           │   ├── Disclosure/
│           │   │   └── TeamDisclosureHeader.swift
│           │   └── Tables/
│           │       ├── SimpleTableView.swift   # Reusable box score table
│           │       └── TableModels.swift       # Column/Row definitions
│           ├── Sports/
│           │   ├── NBA/
│           │   │   ├── NBAModels.swift         # Player stats, team totals
│           │   │   ├── NBABoxScoreView.swift   # Starters + Bench (with DNP)
│           │   │   └── NBAMockData.swift       # 3 mock games
│           │   └── NFL/
│           │       ├── NFLModels.swift         # Passing/Rushing/etc types
│           │       ├── NFLBoxScoreView.swift   # Tab-based group switcher
│           │       └── NFLMockData.swift       # 2 mock games
│           └── Shared/
│               └── Models/
│                   └── GameModels.swift        # Game, TeamInfo, GameStatus, Sport
└── DEVELOPMENT.md                              # This file
```

---

## UI Components

### TopNavBar
- **Background**: Black
- **Left**: White hamburger icon (☰)
- **Center**: "Italics" in italic white text
- **Right**: Blue filled circle (profile placeholder)

### SportTabBar
- **Background**: Black
- **Left edge**: Yellow indicator bar (24px wide)
- **Tabs**: NBA, NFL, NCCAF, NCAAM, NHL, MLB (white text)
- **Behavior**: Tap to filter games by sport

### DateSelector
- **Background**: White
- **Cell format**: "MON\nJan 12" (day of week + date)
- **Selected state**: Gray background
- **Behavior**: Tap to filter games by date, auto-scrolls to selected date

### BottomTabBar
- **Background**: Black
- **Tabs**: "Top", "Scores", "Standings" (white text)
- **Dividers**: Gray vertical lines between tabs
- **Active tab**: Scores (others show "Coming Soon" placeholder)

### GameCardView
- **Background**: White with thin gray border
- **Layout**: `ABR  SCORE  STATUS/@  SCORE  ABR`
- **Score font**: 28pt bold
- **Status**: "FINAL", "Q4 5:15", etc. with "@" below
- **Expansion**: Tap left half for away team, right half for home team
- **One at a time**: Tapping other team replaces current box score

### NBABoxScoreView
- **Team header**: Black background, white uppercase text
- **Column headers**: Gray background (MIN, PTS, FG)
- **Starters header**: Dark black/gray background
- **Bench header**: Light gray background
- **DNP players**: Listed in Bench section with "DNP - Reason" text
- **Player names**: "L. James" format

---

## Data Models

### Shared Models

```swift
enum Sport: String, CaseIterable {
    case nba, nfl, nccaf, ncaam, nhl, mlb
}

enum GameStatus {
    case scheduled(date: Date)
    case live(period: String, clock: String)
    case final
    case finalOvertime(periods: Int)
}

struct Game: Identifiable {
    let id: String
    let sport: Sport
    let gameDate: Date        // Used for date filtering
    let status: GameStatus
    let awayTeam, homeTeam: TeamInfo
    let awayScore, homeScore: Int
    let awayBoxScore, homeBoxScore: BoxScorePayload
}

enum BoxScorePayload {
    case nba(NBATeamBoxScore)
    case nfl(NFLTeamBoxScore)
}
```

### NBA Models

- `NBATeamBoxScore`: Contains starters, bench, dnp arrays + team totals
- `NBAPlayerLine`: Player info + optional stats + dnpReason
- `NBAStatLine`: All individual stat categories
- `NBATeamTotals`: Aggregated team statistics

### NFL Models

- `NFLTeamBoxScore`: Contains array of `NFLGroup`
- `NFLGroup`: Offense/Defense/Special Teams with sections
- `NFLSection`: Passing/Rushing/etc with columns + rows
- Uses generic `TableRow`/`TableColumn` for flexibility

---

## Mock Data

### NBA Games (3)
1. Lakers 122 @ Celtics 117 (FINAL) - Today
2. Warriors 70 @ Nuggets 68 (Q3 4:22 - LIVE) - Today
3. Heat 106 @ Knicks 104 (FINAL/OT) - Yesterday

### NFL Games (2)
1. Chiefs 38 @ Eagles 35 (FINAL) - Today
2. 49ers 24 @ Cowboys 17 (3RD 8:42 - LIVE) - Today

---

## Features Implemented

- [x] Black navigation bars (top and bottom)
- [x] Sport tabs with yellow indicator
- [x] Date selector with MON/Jan 12 format
- [x] Game cards with tap-to-expand
- [x] Single box score open at a time per card
- [x] NBA: Starters + Bench sections (DNP in Bench)
- [x] NFL: Tab-based Offense/Defense/Special Teams
- [x] Sport filtering
- [x] Date filtering
- [x] Auto-scroll to expanded card
- [x] Player name formatting (F. LastName)
- [x] DNP players show "DNP - Reason" in stats area

---

## Future Enhancements

### Near-term
- [ ] Add frozen first column to tables (horizontal scroll)
- [ ] Add team logos/colors
- [ ] Implement Top tab functionality
- [ ] Implement Standings tab functionality
- [ ] Hamburger menu functionality
- [ ] Profile screen

### API Integration
- [ ] Connect to sports data API
- [ ] Implement live score updates
- [ ] Add caching layer for offline access
- [ ] Background refresh
- [ ] Pull-to-refresh

### Additional Sports
- [ ] MLB box scores
- [ ] NHL box scores
- [ ] College sports (NCAA) box scores

### UI Polish
- [ ] Dark mode optimization
- [ ] iPad layout
- [ ] Haptic feedback on interactions
- [ ] Skeleton loading states

---

## Development Notes

### Xcode Project Setup
- Created in `/BoxScore/XcodProject/BoxScore/`
- Files referenced (not copied) for single source of truth
- Edit in Cursor or Xcode - changes sync automatically

### Key Files for Common Changes
- **Navigation bars**: `Components/Navigation/` folder
- **Score card layout**: `GameCardView.swift` → `scoreCard`
- **NBA box score**: `NBABoxScoreView.swift`
- **NFL box score**: `NFLBoxScoreView.swift`
- **Mock data**: `NBAMockData.swift`, `NFLMockData.swift`
- **Filtering logic**: `HomeViewModel.swift` → `filteredGames`

### Running the App
1. Open `XcodProject/BoxScore/BoxScore.xcodeproj` in Xcode
2. Select an iPhone simulator (e.g., iPhone 17 Pro)
3. Press Cmd + R to build and run

---

*Last Updated: January 2026*
