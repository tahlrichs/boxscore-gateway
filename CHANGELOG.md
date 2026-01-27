# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Dark mode toggle in hamburger menu (OFF/ON/AUTO)
- AUTO mode syncs with iOS system appearance settings
- Custom dark theme with #1A1A1A background, black scorecards/box scores, white text
- Theme persists across app restarts via UserDefaults
- Theme updates when app returns to foreground (AUTO mode only)

### Changed
- All views now support light and dark themes
- Navigation bars stay black in both light and dark modes
- Theme changes apply immediately without restart

### Fixed
- Dark mode colors now display correctly (was showing inverted colors)
- All text now properly white in dark mode (fixed semantic color adaptation)
- Stats table backgrounds now use theme-aware colors instead of hardcoded black

### Security

### Removed
- Mock data feature flag (`useMockData`) - app always uses live gateway data
- All mock data checks from repositories (Scoreboard, Game, Standings, Roster)
