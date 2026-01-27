# BoxScore

A sports scores iOS app with real-time game data, box scores, and standings.

## Project Overview

BoxScore is a native iOS application that displays live scores, detailed box scores, and standings for multiple sports leagues. The app uses a Node.js gateway backend to aggregate data from multiple sports data providers.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       BoxScore iOS App                            │
│  SwiftUI • MVVM • Combine                                        │
└────────────────────────────┬─────────────────────────────────────┘
                             │ HTTP REST
┌────────────────────────────▼─────────────────────────────────────┐
│                     Gateway (Node.js/Express)                     │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐  │
│  │ Rate Limiter│  │ Cache Layer  │  │ Provider Routing        │  │
│  │ (ESPN)      │  │ (Redis/File) │  │ NBA→ESPN, Others→APISp. │  │
│  └─────────────┘  └──────────────┘  └─────────────────────────┘  │
└────────────────────────────┬─────────────────────────────────────┘
              ┌──────────────┴──────────────┐
              ▼                             ▼
    ┌─────────────────┐           ┌─────────────────┐
    │   ESPN API      │           │   API-Sports    │
    │   (NBA only)    │           │  (NFL,NHL,MLB)  │
    │   Free, 60/min  │           │  100 req/day    │
    └─────────────────┘           └─────────────────┘
```

## Data Sources

| League | Data Provider | Rate Limits | Cost |
|--------|---------------|-------------|------|
| **NBA** | ESPN API | 60/min, 2,000/day | Free (unofficial) |
| **NFL** | API-Sports | 100/day shared | Free tier |
| **NHL** | API-Sports | 100/day shared | Free tier |
| **MLB** | API-Sports | 100/day shared | Free tier |
| **NCAAM** | API-Sports | 100/day shared | Free tier |
| **NCAAF** | API-Sports | 100/day shared | Free tier |

## Project Structure

```
BoxScore/
├── README.md                 # This file
├── XcodProject/              # Xcode project
│   └── BoxScore/
│       ├── BoxScore.xcodeproj
│       ├── Info.plist        # App configuration
│       └── BoxScore/         # App source code
│           ├── Core/         # Config, Network, Repositories
│           ├── Features/     # Home, Settings views
│           ├── Components/   # Reusable UI components
│           └── Sports/       # Sport-specific models
└── gateway/                  # Node.js backend
    ├── src/                  # TypeScript source
    │   ├── providers/        # ESPN & API-Sports adapters
    │   ├── quota/            # Rate limiting
    │   ├── cache/            # Caching layer
    │   └── routes/           # API endpoints
    └── data/                 # Persisted data
```

## Getting Started

### Prerequisites

- Xcode 15+
- Node.js 20+
- iOS 17+ Simulator or device

### 1. Start the Gateway

```bash
cd gateway
npm install
npm run dev
```

The gateway will start on `http://localhost:3001`.

### 2. Run the iOS App

1. Open `XcodProject/BoxScore/BoxScore.xcodeproj` in Xcode
2. Select a simulator (iPhone 15 Pro recommended)
3. Build and run (⌘R)

### Configuration

#### Gateway Environment Variables

Create `gateway/.env`:

```env
PORT=3001
API_SPORTS_KEY=your_api_key_here    # Required for NFL, NHL, MLB
REDIS_URL=redis://localhost:6379    # Optional
```

#### iOS App Configuration

The app configuration is in `BoxScore/Core/Config/AppConfig.swift`:

```swift
static let gatewayBaseURL = "http://localhost:3001"
```

For local development, ensure:
- Gateway is running on port 3001
- `Info.plist` has `NSAllowsLocalNetworking = YES`

## API Endpoints

### Health Check

```bash
GET /v1/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-14T03:00:00.000Z",
  "providers": [
    { "name": "espn", "status": "healthy", "errorCount": 0 },
    { "name": "api_sports", "status": "healthy", "errorCount": 0 }
  ]
}
```

### Scoreboard (Games by Date)

```bash
GET /v1/scoreboard?league=nba&date=2026-01-13
```

Response:
```json
{
  "games": [
    {
      "id": "nba_401810123",
      "startTime": "2026-01-14T00:00:00Z",
      "status": "final",
      "period": "Q4",
      "homeTeam": {
        "id": "nba_13",
        "abbrev": "LAL",
        "name": "Lakers",
        "city": "Los Angeles",
        "score": 112
      },
      "awayTeam": {
        "id": "nba_2",
        "abbrev": "BOS",
        "name": "Celtics",
        "city": "Boston",
        "score": 108
      },
      "externalIds": { "espn": "401810123" }
    }
  ],
  "league": "nba",
  "date": "2026-01-13",
  "provider": "espn"
}
```

### Box Score

```bash
GET /v1/games/nba_401810123/boxscore
```

Response:
```json
{
  "game": { ... },
  "boxScore": {
    "homeTeam": {
      "teamId": "nba_13",
      "teamName": "Lakers",
      "starters": [
        {
          "id": "player_3112335",
          "name": "A. Davis",
          "jersey": "3",
          "position": "PF",
          "isStarter": true,
          "stats": {
            "minutes": 38,
            "points": 32,
            "fgMade": 12,
            "fgAttempted": 20,
            "assists": 5,
            "rebounds": 14
          }
        }
      ],
      "bench": [...],
      "teamTotals": { ... }
    },
    "awayTeam": { ... }
  },
  "lastUpdated": "2026-01-14T03:00:00.000Z"
}
```

### Rate Limit Status

```bash
GET /v1/admin/quota
```

Response:
```json
{
  "espn": {
    "tokenBucket": { "tokens": 58, "capacity": 60 },
    "daily": { "used": 45, "softCap": 2000, "remaining": 1955 },
    "buckets": {
      "scoreboard": { "used": 10, "limit": 120, "remaining": 110 },
      "gameSummary": { "used": 35, "limit": 600, "remaining": 565 }
    },
    "backoff": { "active": false }
  }
}
```

## Features

### Current Features

- ✅ NBA live scores and schedules via ESPN API
- ✅ NBA box scores with full player statistics
- ✅ Game status tracking (scheduled, live, final)
- ✅ Date navigation for past/future games
- ✅ Expandable game cards with detailed stats
- ✅ Two-layer rate limiting (per-minute + daily)
- ✅ Adaptive backoff on API errors
- ✅ Request deduplication
- ✅ Tiered caching (Redis + file storage)
- ✅ Dark mode with OFF/ON/AUTO toggle (syncs with iOS system)

### Planned Features

- 📋 NFL, NHL, MLB game data
- 📋 League standings
- 📋 Player profiles
- 📋 Push notifications

## Development

### iOS App

The iOS app follows MVVM architecture with:
- **SwiftUI** for declarative UI
- **Combine** for reactive data flow
- **Codable** models for JSON parsing

Key files:
- `HomeViewModel.swift` - Main view model for scoreboard
- `ScoreboardRepository.swift` - Data fetching logic
- `GatewayClient.swift` - Network layer
- `GameModels.swift` - Core data models

### Gateway

See [gateway/README.md](gateway/README.md) for detailed gateway documentation.

## Troubleshooting

### Box Scores Not Loading

1. **Clear app cache**: Delete the app and rebuild, or clear Xcode derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/BoxScore-*
   ```
2. **Verify gateway is running**: `curl http://localhost:3001/v1/health`
3. **Check game IDs**: Ensure IDs start with `nba_401...` (ESPN format), not `nba_002...` (old format)

### Games Not Showing in App

1. Verify gateway is running: `curl http://localhost:3001/v1/health`
2. Check `AppConfig.swift` has correct URL (`http://localhost:3001`)
3. Verify `Info.plist` has `NSAllowsLocalNetworking = YES`
4. Pull down to refresh on Scores tab to trigger data fetch

### Gateway Issues

- **Port in use**: `lsof -i :3001` then `kill -9 <PID>`
- **Redis warning**: Safe to ignore - gateway works without Redis
- **Rate limit errors**: Check `/v1/admin/quota` for status, wait for backoff to expire

## License

Private - All rights reserved
