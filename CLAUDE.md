# BoxScore

> **Important**: The user is non-technical. Explain concepts clearly, avoid jargon, and provide step-by-step instructions when needed. When something goes wrong, explain what happened in plain English before diving into fixes.

A native iOS sports scores app with a Node.js gateway backend for aggregating data from ESPN and API-Sports.

## Quick Start

### Gateway (Node.js backend)
```bash
cd gateway
npm install
npm run dev   # Starts on http://localhost:3001
```

### iOS App
1. Open `XcodProject/BoxScore/BoxScore.xcodeproj` in Xcode
2. Select iPhone 17 Pro simulator
3. Build and run (⌘R)

### Verify Everything Works
```bash
curl http://localhost:3001/v1/health
```

## Architecture

- **iOS App**: SwiftUI + MVVM + Combine (iOS 17+ for `@Observable`)
- **Gateway**: Node.js/Express with TypeScript
- **Data Sources**: ESPN (NBA, free) + API-Sports (NFL/NHL/MLB, 100 req/day)

## Project Structure

```
BoxScore/
├── XcodProject/BoxScore/BoxScore/   # iOS app source
│   ├── Core/                        # Config, Networking, Security
│   ├── Features/Home/               # HomeView, HomeViewModel, GameCardView
│   ├── Components/                  # Navigation bars, tables
│   └── Sports/NBA/, Sports/NFL/     # Sport-specific views & models
└── gateway/                         # Node.js backend
    └── src/
        ├── providers/               # ESPN & API-Sports adapters
        ├── routes/                  # API endpoints
        ├── cache/                   # Redis/file caching
        └── quota/                   # Rate limiting
```

## Key Files

| Purpose | File |
|---------|------|
| Main view model | `Features/Home/HomeViewModel.swift` |
| Network client | `Core/Networking/GatewayClient.swift` |
| App config | `Core/Config/AppConfig.swift` |
| Game models | `Shared/Models/GameModels.swift` |
| ESPN adapter | `gateway/src/providers/espnAdapter.ts` |
| Scoreboard API | `gateway/src/routes/scoreboard.ts` |

## API Endpoints

- `GET /v1/health` - Health check
- `GET /v1/scoreboard?league=nba&date=2026-01-15` - Games by date
- `GET /v1/games/{id}/boxscore` - Box score details
- `GET /v1/admin/quota` - Rate limit status

## Environment Variables (gateway/.env)

```env
PORT=3001
API_SPORTS_KEY=your_key    # Required for NFL/NHL/MLB
REDIS_URL=redis://localhost:6379   # Optional
```

## Conventions

- iOS uses `@Observable` macro (iOS 17+) for state management
- Game IDs format: `{league}_{provider_id}` (e.g., `nba_401810123`)
- Player names displayed as "F. LastName" format
- Only one box score expanded at a time per game card

## Common Issues

- **Port conflict**: `lsof -i :3001` then `kill -9 <PID>`
- **Games not showing**: Check `AppConfig.swift` has `useMockData = false`
- **Box scores failing**: Ensure game IDs start with `nba_401...` (ESPN format)
