# BoxScore Data Gateway

A Node.js/TypeScript backend that fetches sports data from ESPN and serves it to the BoxScore iOS app.

## Features

- **ESPN Integration**: Sports data via ESPN's unofficial API (free, no API key)
- **Two-Layer Rate Limiting**: Token bucket (60/min) + daily budget (2,000/day)
- **Adaptive Backoff**: Automatic slowdown on 429, 403, 5xx, or timeouts
- **Three-Tier Caching**: Redis cache + permanent file storage
- **Request Deduplication**: Multiple concurrent requests share one API call
- **Health Monitoring**: Track provider status, quota usage, and cache performance

## Quick Start

### Prerequisites

- Node.js 20+
- Redis (optional, for caching)
- PostgreSQL database (Supabase)

### Installation

```bash
cd gateway
npm install
```

### Configuration

Create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
PORT=3001
DATABASE_URL=postgresql://...
REDIS_URL=redis://localhost:6379    # Optional
```

### Running

```bash
# Development (with hot reload)
npm run dev

# Production
npm run build
npm start
```

## ESPN API Integration

### Endpoints Used

| Endpoint | Purpose | URL |
|----------|---------|-----|
| **Scoreboard** | Daily games list | `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=YYYYMMDD` |
| **Summary** | Box score + game detail | `https://site.web.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event={eventId}` |
| **Athletes** | Player profiles + stats | `https://site.web.api.espn.com/apis/common/v3/sports/basketball/nba/athletes/{id}` |

> **Note:** These are unofficial, undocumented ESPN endpoints. They are free and require no API key, but may change without notice.

## API Reference

### Health

```http
GET /v1/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-14T03:00:00.000Z",
  "provider": "espn",
  "cache": { "connected": true }
}
```

### Scoreboard

```http
GET /v1/scoreboard?league={league}&date={YYYY-MM-DD}
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `league` | Yes | `nba` (more leagues coming) |
| `date` | No | Date in YYYY-MM-DD format (defaults to today) |

### Box Score

```http
GET /v1/games/{id}/boxscore
```

Returns detailed player stats for a game.

### Players

```http
GET /v1/players/search?q={name}
GET /v1/players/{id}
```

Search for players and get profile with current season stats.

## Architecture

```
┌─────────────────┐
│  iOS App        │
└────────┬────────┘
         │ HTTP
┌────────▼────────────────────────────────────────────────────┐
│  Gateway (Express.js)                                        │
│                                                              │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐  │
│  │ Request        │  │ Cache Policy    │  │ ESPN         │  │
│  │ Deduplicator   │  │ (TTL by status) │  │ Adapter      │  │
│  └────────────────┘  └─────────────────┘  └──────────────┘  │
│                                                              │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐  │
│  │ ESPN Rate      │  │ Redis Cache     │  │ File Storage │  │
│  │ Limiter        │  │ (optional)      │  │ (permanent)  │  │
│  └────────────────┘  └─────────────────┘  └──────────────┘  │
└────────┬────────────────────────────────────────────────────┘
         │
    ┌────▼─────┐
    │ ESPN API │
    └──────────┘
```

## Rate Limiting

Two-layer throttling protects against upstream rate limiting:

| Layer | Limit | Algorithm |
|-------|-------|-----------|
| **Per-minute** | 60 req/min | Token bucket (1 token/sec, 10 burst) |
| **Daily** | 2,000 soft / 2,200 hard | Counter with UTC midnight reset |

### Adaptive Backoff

| Trigger | Initial | Max |
|---------|---------|-----|
| 429 Too Many Requests | 30s | 5 min |
| 403 Forbidden | 60s | 10 min |
| Timeout (>10s) | 15s | 2 min |
| 5xx Server Error | 30s | 5 min |

## Caching

### TTL Policy

| Data Type | Game Status | TTL |
|-----------|-------------|-----|
| Scoreboard | Has live games | 60 seconds |
| Scoreboard | All scheduled (today) | 5 minutes |
| Scoreboard | All final (today) | 6 hours |
| Box Score | Live game | 60-120 seconds |
| Box Score | Final | 7 days → Permanent |

### Request Deduplication

Multiple concurrent requests for the same resource share a single upstream API call:

```
User 1 → cache miss → start API call
User 2-50 (within 30s) → cache miss → await same promise
API completes → cache result → all users receive response

Result: 1 upstream call, not 50
```

## Project Structure

```
gateway/
├── src/
│   ├── index.ts              # Entry point
│   ├── config/               # Configuration
│   ├── cache/
│   │   ├── redis.ts          # Redis operations
│   │   ├── CachePolicy.ts    # TTL logic
│   │   └── RequestDeduplicator.ts
│   ├── providers/
│   │   ├── index.ts          # Provider factory
│   │   ├── espnAdapter.ts    # ESPN adapter
│   │   └── espnPlayerService.ts  # Player stats
│   ├── routes/               # API endpoints
│   ├── db/                   # Database access
│   └── utils/                # Utilities
├── data/
│   └── boxscores/            # Permanent storage
└── package.json
```

## Deployment

The gateway is deployed on **Railway** and connects to **Supabase** for the database.

Production URL: `https://boxscore-gateway-production.up.railway.app`

## License

Private - BoxScore App
