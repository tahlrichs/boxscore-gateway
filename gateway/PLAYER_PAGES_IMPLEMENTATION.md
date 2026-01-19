# Player Pages v1 (NBA) - Implementation Summary

## Overview

This document summarizes the implementation of the Player Pages v1 feature for NBA statistics. The implementation provides fast, cacheable player statistics with progressive loading and precomputed aggregates.

## Architecture

### Database Schema
**Location**: `/Users/timahlrichs/Documents/Projects/BoxScore/gateway/src/db/migrations/001_player_stats_tables.sql`

**Tables Added**:
1. **Enhanced `players` table** - Added bio fields (height, weight, school, hometown, headshot, etc.)
2. **`nba_player_season_summary`** - Precomputed season aggregates per player
3. **`nba_player_game_logs`** - Individual game performance records
4. **`nba_player_splits`** - Precomputed splits (home/away, last N, by month)
5. **`nba_player_career_summary`** - Historical season-by-season summaries
6. **`team_live_status`** - Tracks team live game status for cache TTL decisions

**Helper Functions**:
- `is_player_live(player_id)` - Determines if player is in "live window" for cache TTL

### Data Access Layer
**Location**: `/Users/timahlrichs/Documents/Projects/BoxScore/gateway/src/db/repositories/playerRepository.ts`

**Key Functions**:
- `upsertPlayer()` - Atomic player creation/update with provider mapping (transaction-safe)
- `upsertNBAGameLog()` - Insert/update game performance with calculated percentages
- `recomputeSeasonSummary()` - Aggregate stats from game logs using SQL
- `recomputeNBASplits()` - Compute HOME_AWAY, LAST_N (5,10,20), and BY_MONTH splits
- `getPlayerById()`, `getNBASeasonSummary()`, `getNBAGameLogs()`, `getNBASplits()`, `getCareerSummaries()`

### Ingestion Pipeline
**Location**: `/Users/timahlrichs/Documents/Projects/BoxScore/gateway/src/providers/espnPlayerExtractor.ts`

**Key Functions**:
- `extractAndUpsertPlayersFromBoxScore()` - Extract all players from ESPN box score
- `processBoxScoreForPlayers()` - Process box score and recompute stats
- `getSeasonFromGameDate()` - Determine season from game date (handles NBA/NCAAM cross-year seasons)

**Location**: `/Users/timahlrichs/Documents/Projects/BoxScore/gateway/src/jobs/playerIngestion.ts`

**Ingestion Jobs**:
- `ingestPlayersFromGame(gameId)` - Ingest players from a single game
- `ingestPlayersFromDate(league, date)` - Ingest players from all games on a date
- `backfillPlayersFromExistingGames(league, season, limit)` - Backfill historical data

**CLI Script**: `/Users/timahlrichs/Documents/Projects/BoxScore/gateway/src/scripts/ingestPlayers.ts`
```bash
npm run ingest-players game nba_401584701
npm run ingest-players date nba 2025-01-15
npm run ingest-players backfill nba 2025 10
```

### API Endpoints
**Location**: `/Users/timahlrichs/Documents/Projects/BoxScore/gateway/src/routes/playerRoutes.ts`

**Progressive Loading Endpoints**:

1. **GET `/v1/players/:id`** - Player header (fast bio + current season headline stats)
   - Bio: name, position, height, weight, school, hometown, headshot
   - Current season: PPG, RPG, APG, FG%, 3P%, FT%
   - Cache: 60-120s if live, 6-12h if not live

2. **GET `/v1/players/:id/season/:season/summary`** - Full season stats
   - Complete season aggregates
   - All shooting splits, rebounds, assists, etc.
   - Cache: Same as header

3. **GET `/v1/players/:id/season/:season/gamelog`** - Game-by-game performance
   - Up to 82 games (configurable via `?limit=N`)
   - Sorted by date descending
   - Includes DNP (Did Not Play) reasons

4. **GET `/v1/players/:id/season/:season/splits`** - Statistical splits
   - HOME_AWAY: Home vs Away performance
   - LAST_N: Last 5, 10, 20 games
   - BY_MONTH: Monthly breakdowns (OCT, NOV, DEC, etc.)

5. **GET `/v1/players/:id/career/summary`** - Career history
   - Season-by-season summaries across entire career
   - Does NOT include full career game log (too large)

## Key Design Decisions

### 1. Canonical Player IDs
- **Internal ID**: UUID v4 (e.g., `550e8400-e29b-41d4-a716-446655440000`)
- **Provider Mapping**: `external_ids` table maps internal ID ↔ ESPN player ID
- **Benefits**: Future-proof for multi-provider support, stable IDs independent of data source

### 2. Precomputed Aggregates
- **Season summaries** computed from game logs during ingestion (not at request time)
- **Splits** computed during ingestion using SQL aggregation
- **Benefits**: Fast API responses, predictable latency, reduced database load

### 3. Cache Strategy
- **Live Window**: 60-120s TTL (team playing or game ended <3 hours ago)
- **Non-Live**: 6-12h TTL (stable data)
- **Detection**: `is_player_live()` function checks `team_live_status` table
- **Headers**: `Cache-Control: public, max-age=X, s-maxage=Y`

### 4. Progressive Loading
- **Header endpoint**: Fast initial load (~100ms target)
- **Detail endpoints**: Load on demand (game logs, splits, career)
- **Benefits**: Perceived performance, reduces unnecessary data transfer

### 5. Transaction Safety
- **Player upserts**: Use PostgreSQL transactions for atomicity
- **Pattern**: BEGIN → INSERT player → INSERT provider mapping → COMMIT
- **Rollback** on error to maintain data integrity

## Usage Examples

### 1. Apply Database Migration
```bash
psql $DATABASE_URL -f src/db/migrations/001_player_stats_tables.sql
```

### 2. Ingest Players from Today's Games
```bash
npm run ingest-players date nba 2025-01-17
```

### 3. Backfill Current Season (Limited to 10 games for testing)
```bash
npm run ingest-players backfill nba 2025 10
```

### 4. Fetch Player Data via API
```bash
# Header (bio + current season headline)
curl http://localhost:3001/v1/players/{playerId}

# Full season stats
curl http://localhost:3001/v1/players/{playerId}/season/2025/summary

# Game log
curl http://localhost:3001/v1/players/{playerId}/season/2025/gamelog

# Splits
curl http://localhost:3001/v1/players/{playerId}/season/2025/splits

# Career
curl http://localhost:3001/v1/players/{playerId}/career/summary
```

## Monitoring & Observability

### Current Logging
- All ingestion jobs log: start time, duration, success/error counts
- Player extraction logs: player count, game ID
- API endpoints log: request params, errors
- Uses Winston logger with structured JSON logging

### Recommended Metrics (Phase 6)
- **Ingestion metrics**: Games processed, players upserted, errors
- **API metrics**: Latency by endpoint, cache hit rate, error rate
- **Data quality**: Missing stats, DNP rates, coverage

## Testing Recommendations (Phase 6)

### Unit Tests
- `playerRepository.ts`: Test upsert logic, aggregation correctness, split computation
- `espnPlayerExtractor.ts`: Test player extraction, season detection, name parsing
- Player ID mapping: Test ESPN ID → internal ID resolution

### Integration Tests
- End-to-end ingestion: Box score → database → API response
- Cache behavior: Verify TTL changes based on live status
- Transaction rollback: Verify player upsert rollback on error

### Manual Testing Checklist
- [ ] Ingest a live game and verify short cache TTL
- [ ] Ingest a completed game and verify long cache TTL
- [ ] Verify splits computation (home/away, last N, by month)
- [ ] Verify career summaries span multiple seasons
- [ ] Test DNP (Did Not Play) handling in game logs

## Deployment Checklist

1. **Database Migration**
   ```bash
   psql $DATABASE_URL -f src/db/migrations/001_player_stats_tables.sql
   ```

2. **Environment Variables**
   - Ensure `DATABASE_URL` is set
   - Verify PostgreSQL connection pool settings

3. **Initial Backfill**
   ```bash
   npm run ingest-players backfill nba 2025
   ```

4. **Ongoing Ingestion**
   - Option A: Add hook to existing box score ingestion
   - Option B: Run nightly job to ingest previous day's games
   - Option C: Trigger on-demand via admin endpoint

5. **Monitor**
   - Check logs for ingestion errors
   - Verify API response times (<200ms for header endpoint)
   - Monitor cache hit rates

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Header endpoint latency | <100ms | Bio + headline stats only |
| Season summary latency | <150ms | Full season aggregates |
| Game log latency | <200ms | Up to 82 games |
| Splits latency | <150ms | Precomputed splits |
| Career latency | <200ms | Multiple seasons |
| Cache hit rate (non-live) | >90% | 6-12h TTL |
| Ingestion throughput | >10 games/min | Parallel processing |

## Known Limitations

1. **NBA Only**: Current implementation is NBA-specific. NCAAM/NFL/NHL require sport-specific logic.
2. **ESPN Only**: Only ESPN provider supported. Other providers need adapter implementation.
3. **No Advanced Stats**: Only basic box score stats (no PER, true shooting %, etc.)
4. **No Play-by-Play**: Game logs have final stats only, no possession-level data.
5. **Manual Backfill**: No automatic historical data ingestion on player creation.

## Future Enhancements

### Multi-Sport Support
- Add NFL/NCAAM/NHL-specific game log tables
- Implement sport-specific stat computations
- Extend splits to support football (home/away, vs ranked, etc.)

### Advanced Stats
- True shooting percentage (TS%)
- Player efficiency rating (PER)
- Usage rate, assist rate, turnover rate
- Defensive rating

### Real-Time Updates
- WebSocket support for live stat updates
- Pub/sub pattern for cache invalidation
- Incremental stat updates (not full recomputation)

### Player Search
- Full-text search by name
- Filter by team, position, school
- Autocomplete for player lookup

## File Reference

| File | Purpose |
|------|---------|
| `src/db/migrations/001_player_stats_tables.sql` | Database schema migration |
| `src/db/pool.ts` | PostgreSQL connection pool |
| `src/db/repositories/playerRepository.ts` | Player data access layer |
| `src/providers/espnPlayerExtractor.ts` | ESPN box score → player data |
| `src/jobs/playerIngestion.ts` | Ingestion jobs |
| `src/scripts/ingestPlayers.ts` | CLI for manual ingestion |
| `src/routes/playerRoutes.ts` | API endpoints |
| `src/index.ts` | Express app (routes registered) |

## Support

For questions or issues:
1. Check logs: `winston` logger outputs structured JSON
2. Verify database: Query `players`, `nba_player_game_logs`, `nba_player_season_summary`
3. Test ingestion: Run `npm run ingest-players` with a known game ID
4. Check cache: Verify `team_live_status` table for live detection

---

**Implementation Date**: January 2026
**Version**: v1.0 (NBA only)
**Status**: Ready for production testing
