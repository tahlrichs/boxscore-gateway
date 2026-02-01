/**
 * Schedule Sync Job
 * 
 * Populates the games table and game_dates index from ESPN scoreboard data.
 * This is the foundation for schedule-driven date coverage.
 * 
 * Two modes:
 * - Mode A: Bulk fetch (if ESPN supports date range queries returning full season)
 * - Mode B: Incremental discovery (rolling window, gradually expanding coverage)
 * 
 * Default: Mode B (safer, respects rate limits)
 * 
 * Schedule: Daily at 04:00 UTC (after games end)
 */

import * as fs from 'fs';
import * as path from 'path';
import { getESPNAdapter } from '../providers/espnAdapter';
import { getESPNRateLimiter, ESPNBudgetBucket } from '../utils/ESPNRateLimiter';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { Game, ScoreboardResponse } from '../types';
import { logger } from '../utils/logger';
import { query } from '../db/pool';

// Persistence paths
const DATA_DIR = path.join(__dirname, '../../data');
const SCHEDULE_FILE = path.join(DATA_DIR, 'schedule-store.json');

// =====================
// Types
// =====================

export interface LeagueSeason {
  id: string;
  leagueId: string;
  seasonLabel: string;
  startDate: string;  // YYYY-MM-DD
  endDate: string;    // YYYY-MM-DD
  preseasonStart?: string;
  postseasonEnd?: string;
  status: 'preseason' | 'regular' | 'postseason' | 'offseason';
  scheduleSource: string;
  lastScheduleSyncAt?: Date;
}

export interface GameRecord {
  id: string;
  leagueId: string;
  seasonId: string;
  gameDate: string;       // Original date
  scoreboardDate: string; // Canonical grouping date (US/Eastern)
  startTimeUtc: string;
  homeTeamId: string;
  awayTeamId: string;
  homeScore?: number;
  awayScore?: number;
  status: 'scheduled' | 'live' | 'final';
  period?: string;
  clock?: string;
  venueId?: string;
  externalIds: Record<string, string>;  // { espn: "401810365", ... }
  lastRefreshedAt: Date;
}

export interface GameDateEntry {
  leagueId: string;
  seasonId: string;
  scoreboardDate: string;
  gameCount: number;
  firstGameTimeUtc?: string;
  lastGameTimeUtc?: string;
  hasLiveGames: boolean;
  allGamesFinal: boolean;
  lastRefreshedAt: Date;
}

export interface ScheduleSyncResult {
  date: string;
  gamesFound: number;
  gamesUpserted: number;
  errors: string[];
  skipped: boolean;
  skipReason?: string;
}

export interface ScheduleSyncSummary {
  startTime: string;
  endTime: string;
  durationMs: number;
  mode: 'bulk' | 'incremental';
  seasonId: string;
  datesProcessed: number;
  totalGamesFound: number;
  totalGamesUpserted: number;
  results: ScheduleSyncResult[];
  errors: string[];
}

// =====================
// In-Memory Store (for development)
// Will be replaced with PostgreSQL in production
// =====================

class ScheduleStore {
  private seasons: Map<string, LeagueSeason> = new Map();
  private games: Map<string, GameRecord> = new Map();
  private gameDates: Map<string, GameDateEntry> = new Map();
  private persistenceEnabled: boolean = true;
  
  // Initialize with all seasons and load persisted data
  constructor() {
    // NBA 2025-26 season
    this.seasons.set('nba_2025-26', {
      id: 'nba_2025-26',
      leagueId: 'nba',
      seasonLabel: '2025-26',
      startDate: '2025-10-22',
      endDate: '2026-04-13',
      preseasonStart: '2025-10-04',
      postseasonEnd: '2026-06-22',
      status: 'regular',
      scheduleSource: 'espn',
    });
    
    // NFL 2025 season (Sep 2025 - Feb 2026)
    this.seasons.set('nfl_2025', {
      id: 'nfl_2025',
      leagueId: 'nfl',
      seasonLabel: '2025',
      startDate: '2025-09-04',      // Regular season start (Thursday opener)
      endDate: '2026-01-04',        // Regular season end (Week 18)
      preseasonStart: '2025-08-01', // Preseason starts
      postseasonEnd: '2026-02-08',  // Super Bowl LX
      status: 'regular',
      scheduleSource: 'espn',
    });
    
    // NCAAF 2025 season (Aug 2025 - Jan 2026)
    this.seasons.set('ncaaf_2025', {
      id: 'ncaaf_2025',
      leagueId: 'ncaaf',
      seasonLabel: '2025',
      startDate: '2025-08-23',       // Regular season start (Week 0)
      endDate: '2025-12-07',         // Regular season end (Championship Week)
      preseasonStart: '2025-08-23',  // Same as regular season
      postseasonEnd: '2026-01-20',   // National Championship
      status: 'regular',
      scheduleSource: 'espn',
    });
    
    // NCAAM 2025-26 season (Nov 2025 - Apr 2026)
    this.seasons.set('ncaam_2025-26', {
      id: 'ncaam_2025-26',
      leagueId: 'ncaam',
      seasonLabel: '2025-26',
      startDate: '2025-11-04',       // Regular season start
      endDate: '2026-03-08',         // Regular season end (Selection Sunday)
      preseasonStart: '2025-11-04',  // Same as regular season
      postseasonEnd: '2026-04-06',   // National Championship
      status: 'regular',
      scheduleSource: 'espn',
    });
    
    // NHL 2025-26 season (Oct 2025 - Jun 2026)
    this.seasons.set('nhl_2025-26', {
      id: 'nhl_2025-26',
      leagueId: 'nhl',
      seasonLabel: '2025-26',
      startDate: '2025-10-07',       // Regular season start
      endDate: '2026-04-17',         // Regular season end
      preseasonStart: '2025-09-21',  // Preseason starts
      postseasonEnd: '2026-06-20',   // Stanley Cup Finals end
      status: 'regular',
      scheduleSource: 'espn',
    });
    
    // Load persisted data if available
    this.loadFromDisk();
  }
  
  // Persistence methods
  private loadFromDisk(): void {
    try {
      if (fs.existsSync(SCHEDULE_FILE)) {
        const data = JSON.parse(fs.readFileSync(SCHEDULE_FILE, 'utf-8'));
        
        // Load games
        if (data.games) {
          for (const game of data.games) {
            // Convert lastRefreshedAt back to Date
            game.lastRefreshedAt = new Date(game.lastRefreshedAt);
            this.games.set(game.id, game);
          }
        }
        
        // Load gameDates
        if (data.gameDates) {
          for (const gd of data.gameDates) {
            // Convert lastRefreshedAt back to Date
            gd.lastRefreshedAt = new Date(gd.lastRefreshedAt);
            this.gameDates.set(`${gd.leagueId}:${gd.scoreboardDate}`, gd);
          }
        }
        
        // Load seasons (merge with defaults)
        if (data.seasons) {
          for (const season of data.seasons) {
            if (season.lastScheduleSyncAt) {
              season.lastScheduleSyncAt = new Date(season.lastScheduleSyncAt);
            }
            this.seasons.set(season.id, season);
          }
        }
        
        logger.info('ScheduleStore: Loaded persisted data', {
          games: this.games.size,
          gameDates: this.gameDates.size,
          seasons: this.seasons.size,
        });
      }
    } catch (error) {
      logger.error('ScheduleStore: Failed to load persisted data', { error });
    }
  }
  
  saveToDisk(): void {
    if (!this.persistenceEnabled) return;
    
    try {
      // Ensure data directory exists
      if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
      }
      
      const data = {
        savedAt: new Date().toISOString(),
        seasons: Array.from(this.seasons.values()),
        games: Array.from(this.games.values()),
        gameDates: Array.from(this.gameDates.values()),
      };
      
      fs.writeFileSync(SCHEDULE_FILE, JSON.stringify(data, null, 2));
      
      logger.debug('ScheduleStore: Saved to disk', {
        games: this.games.size,
        gameDates: this.gameDates.size,
      });
    } catch (error) {
      logger.error('ScheduleStore: Failed to save to disk', { error });
    }
  }
  
  // Season methods
  getSeason(seasonId: string): LeagueSeason | undefined {
    return this.seasons.get(seasonId);
  }
  
  getSeasonForDate(leagueId: string, date: string): LeagueSeason | undefined {
    for (const season of this.seasons.values()) {
      if (season.leagueId !== leagueId) continue;
      
      const dateObj = new Date(date);
      const seasonStart = new Date(season.preseasonStart || season.startDate);
      const seasonEnd = new Date(season.postseasonEnd || season.endDate);
      
      if (dateObj >= seasonStart && dateObj <= seasonEnd) {
        return season;
      }
    }
    return undefined;
  }
  
  updateSeasonSyncTime(seasonId: string): void {
    const season = this.seasons.get(seasonId);
    if (season) {
      season.lastScheduleSyncAt = new Date();
    }
  }
  
  // Game methods
  upsertGame(game: GameRecord, skipPersist: boolean = false): boolean {
    const existing = this.games.get(game.id);
    const isNew = !existing;
    
    // Merge external_ids if updating
    if (existing) {
      game.externalIds = { ...existing.externalIds, ...game.externalIds };
    }
    
    this.games.set(game.id, game);
    
    // Don't persist on every upsert during bulk operations (for performance)
    // Caller should call saveToDisk() after bulk operations
    return isNew;
  }
  
  getGame(gameId: string): GameRecord | undefined {
    return this.games.get(gameId);
  }
  
  getGamesForDate(leagueId: string, scoreboardDate: string): GameRecord[] {
    const results: GameRecord[] = [];
    for (const game of this.games.values()) {
      if (game.leagueId === leagueId && game.scoreboardDate === scoreboardDate) {
        results.push(game);
      }
    }
    return results;
  }
  
  getAllGames(): GameRecord[] {
    return Array.from(this.games.values());
  }
  
  // GameDates methods
  getGameDateEntry(leagueId: string, scoreboardDate: string): GameDateEntry | undefined {
    return this.gameDates.get(`${leagueId}:${scoreboardDate}`);
  }
  
  upsertGameDateEntry(entry: GameDateEntry): void {
    this.gameDates.set(`${entry.leagueId}:${entry.scoreboardDate}`, entry);
  }
  
  getAllGameDates(): GameDateEntry[] {
    return Array.from(this.gameDates.values());
  }
  
  // Helper to get key for game date
  private getGameDateKey(leagueId: string, date: string): string {
    return `${leagueId}:${date}`;
  }
  
  // Stats
  getStats(): { seasons: number; games: number; gameDates: number } {
    return {
      seasons: this.seasons.size,
      games: this.games.size,
      gameDates: this.gameDates.size,
    };
  }
}

// Global store instance
const store = new ScheduleStore();

// =====================
// Utility Functions
// =====================

/**
 * Convert UTC time to US/Eastern date for scoreboard grouping
 * A game at 1:00 AM UTC on Jan 14 is part of the "Jan 13" slate in Eastern time
 */
export function getScoreboardDate(utcTimestamp: string): string {
  const date = new Date(utcTimestamp);
  // Use toLocaleDateString with timeZone option
  // This correctly handles DST
  const options: Intl.DateTimeFormatOptions = {
    timeZone: 'America/New_York',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  };
  const parts = new Intl.DateTimeFormat('en-CA', options).formatToParts(date);
  const year = parts.find(p => p.type === 'year')?.value;
  const month = parts.find(p => p.type === 'month')?.value;
  const day = parts.find(p => p.type === 'day')?.value;
  return `${year}-${month}-${day}`;
}

/**
 * Get array of dates between start and end (inclusive)
 */
function getDateRange(startDate: string, endDate: string): string[] {
  const dates: string[] = [];
  const current = new Date(startDate);
  const end = new Date(endDate);
  
  while (current <= end) {
    dates.push(current.toISOString().split('T')[0]);
    current.setDate(current.getDate() + 1);
  }
  
  return dates;
}

/**
 * Transform ESPN Game to GameRecord
 */
function transformToGameRecord(game: Game, seasonId: string, league: string): GameRecord {
  const scoreboardDate = getScoreboardDate(game.startTime);
  
  return {
    id: game.id,
    leagueId: league,
    seasonId,
    gameDate: game.startTime.split('T')[0],
    scoreboardDate,
    startTimeUtc: game.startTime,
    homeTeamId: game.homeTeam.id,
    awayTeamId: game.awayTeam.id,
    homeScore: game.homeTeam.score,
    awayScore: game.awayTeam.score,
    status: game.status,
    period: game.period,
    clock: game.clock,
    venueId: game.venue?.id,
    externalIds: game.externalIds || {},
    lastRefreshedAt: new Date(),
  };
}

/**
 * Rebuild game_dates entry from games for a specific date
 */
function rebuildGameDateEntry(leagueId: string, seasonId: string, scoreboardDate: string): GameDateEntry {
  const games = store.getGamesForDate(leagueId, scoreboardDate);
  
  const startTimes = games
    .map(g => g.startTimeUtc)
    .filter(Boolean)
    .sort();
  
  return {
    leagueId,
    seasonId,
    scoreboardDate,
    gameCount: games.length,
    firstGameTimeUtc: startTimes[0],
    lastGameTimeUtc: startTimes[startTimes.length - 1],
    hasLiveGames: games.some(g => g.status === 'live'),
    allGamesFinal: games.length > 0 && games.every(g => g.status === 'final'),
    lastRefreshedAt: new Date(),
  };
}

// =====================
// PostgreSQL Upsert
// =====================

async function upsertGameToPg(record: GameRecord): Promise<void> {
  await query(
    `INSERT INTO games (
      id, league_id, season_id, game_date, scoreboard_date,
      start_time_utc, home_team_id, away_team_id,
      home_score, away_score, status, period, clock,
      venue_id, external_ids, last_refreshed_at
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
    ON CONFLICT (id) DO UPDATE SET
      start_time_utc = EXCLUDED.start_time_utc,
      home_score = EXCLUDED.home_score,
      away_score = EXCLUDED.away_score,
      status = EXCLUDED.status,
      period = EXCLUDED.period,
      clock = EXCLUDED.clock,
      external_ids = EXCLUDED.external_ids,
      last_refreshed_at = EXCLUDED.last_refreshed_at,
      updated_at = NOW()`,
    [
      record.id, record.leagueId, record.seasonId,
      record.gameDate, record.scoreboardDate, record.startTimeUtc,
      record.homeTeamId, record.awayTeamId,
      record.homeScore ?? null, record.awayScore ?? null,
      record.status, record.period ?? null, record.clock ?? null,
      record.venueId ?? null, JSON.stringify(record.externalIds),
      record.lastRefreshedAt,
    ]
  );
}

// =====================
// Core Sync Functions
// =====================

/**
 * Sync a single date from ESPN
 * @param bulkMode - If true, uses 'reserve' bucket instead of 'scoreboard' for higher limits
 */
async function syncDate(
  league: string, 
  date: string, 
  seasonId: string,
  bulkMode: boolean = false
): Promise<ScheduleSyncResult> {
  const result: ScheduleSyncResult = {
    date,
    gamesFound: 0,
    gamesUpserted: 0,
    errors: [],
    skipped: false,
  };
  
  // Check rate limiter - use 'reserve' bucket for bulk operations
  const rateLimiter = getESPNRateLimiter();
  const bucket: ESPNBudgetBucket = bulkMode ? 'reserve' : 'scoreboard';
  const canRequest = rateLimiter.canMakeRequest(bucket);
  
  if (!canRequest.allowed) {
    result.skipped = true;
    result.skipReason = canRequest.reason || 'Rate limited';
    logger.warn('ScheduleSync: Skipping date due to rate limit', { date, reason: canRequest.reason });
    return result;
  }
  
  try {
    // Check cache first
    const cacheKey = cacheKeys.scoreboard(league, date);
    let games = await getCached<ScoreboardResponse>(cacheKey);
    
    if (!games) {
      // Fetch from ESPN
      const adapter = getESPNAdapter();
      const fetchedGames = await adapter.fetchScoreboard(league, date);
      
      // Cache the response
      const response: ScoreboardResponse = {
        league,
        date,
        lastUpdated: new Date().toISOString(),
        games: fetchedGames,
      };
      await setCached(cacheKey, response, 24 * 60 * 60); // 24h TTL for schedule data
      games = response;
    }
    
    result.gamesFound = games.games.length;
    
    // Upsert each game
    for (const game of games.games) {
      try {
        const record = transformToGameRecord(game, seasonId, league);
        const isNew = store.upsertGame(record);
        if (isNew) {
          result.gamesUpserted++;
        }

        // PostgreSQL upsert (log errors, don't crash sync)
        try {
          await upsertGameToPg(record);
        } catch (pgError) {
          logger.error('scheduleSync: PG upsert failed for game', {
            gameId: record.id,
            error: pgError instanceof Error ? pgError.message : String(pgError),
          });
        }
      } catch (error) {
        const errMsg = error instanceof Error ? error.message : String(error);
        result.errors.push(`Game ${game.id}: ${errMsg}`);
      }
    }
    
    // Update game_dates entry
    const scoreboardDate = date; // For schedule sync, we're fetching by date
    const gameDateEntry = rebuildGameDateEntry(league, seasonId, scoreboardDate);
    store.upsertGameDateEntry(gameDateEntry);
    
    logger.debug('ScheduleSync: Synced date', {
      date,
      gamesFound: result.gamesFound,
      gamesUpserted: result.gamesUpserted,
    });
    
  } catch (error) {
    const errMsg = error instanceof Error ? error.message : String(error);
    result.errors.push(errMsg);
    logger.error('ScheduleSync: Failed to sync date', { date, error: errMsg });
  }
  
  return result;
}

/**
 * Incremental sync for a date range (Mode B)
 * Syncs dates within a rolling window, gradually expanding coverage
 */
export async function runIncrementalSync(
  league: string = 'nba',
  daysBack: number = 7,
  daysForward: number = 30,
  seasonId: string = 'nba_2025-26'
): Promise<ScheduleSyncSummary> {
  const startTime = new Date();
  const results: ScheduleSyncResult[] = [];
  const errors: string[] = [];
  
  logger.info('ScheduleSync: Starting incremental sync', {
    league,
    daysBack,
    daysForward,
    seasonId,
  });
  
  // Calculate date range
  const today = new Date();
  const startDate = new Date(today);
  startDate.setDate(startDate.getDate() - daysBack);
  const endDate = new Date(today);
  endDate.setDate(endDate.getDate() + daysForward);
  
  const dates = getDateRange(
    startDate.toISOString().split('T')[0],
    endDate.toISOString().split('T')[0]
  );
  
  // Get season boundaries
  const season = store.getSeason(seasonId);
  if (!season) {
    errors.push(`Season not found: ${seasonId}`);
    return {
      startTime: startTime.toISOString(),
      endTime: new Date().toISOString(),
      durationMs: Date.now() - startTime.getTime(),
      mode: 'incremental',
      seasonId,
      datesProcessed: 0,
      totalGamesFound: 0,
      totalGamesUpserted: 0,
      results: [],
      errors,
    };
  }
  
  // Filter dates to season boundaries
  const seasonStart = new Date(season.preseasonStart || season.startDate);
  const seasonEnd = new Date(season.postseasonEnd || season.endDate);
  
  const validDates = dates.filter(date => {
    const d = new Date(date);
    return d >= seasonStart && d <= seasonEnd;
  });
  
  logger.info('ScheduleSync: Processing dates', {
    totalDates: dates.length,
    validDates: validDates.length,
    seasonStart: seasonStart.toISOString().split('T')[0],
    seasonEnd: seasonEnd.toISOString().split('T')[0],
  });
  
  // Sync each date
  let totalGamesFound = 0;
  let totalGamesUpserted = 0;
  
  // Use bulk mode for large syncs (more than 30 days)
  const bulkMode = validDates.length > 30;
  if (bulkMode) {
    logger.info('ScheduleSync: Using bulk mode (reserve bucket) for large sync', {
      dateCount: validDates.length,
    });
  }
  
  for (const date of validDates) {
    const result = await syncDate(league, date, seasonId, bulkMode);
    results.push(result);
    
    totalGamesFound += result.gamesFound;
    totalGamesUpserted += result.gamesUpserted;
    
    if (result.errors.length > 0) {
      errors.push(...result.errors);
    }
    
    // Check if we should stop due to rate limiting
    if (result.skipped && result.skipReason?.includes('Rate')) {
      logger.warn('ScheduleSync: Stopping early due to rate limiting');
      break;
    }
    
    // Delay between dates to stay under per-minute rate limit (60/min = 1 req/sec)
    // Use 1100ms to be safe and avoid hitting the token bucket limit
    await new Promise(resolve => setTimeout(resolve, 1100));
  }
  
  // Update season sync time
  store.updateSeasonSyncTime(seasonId);
  
  // Persist to disk after sync
  store.saveToDisk();
  
  const endTime = new Date();
  const summary: ScheduleSyncSummary = {
    startTime: startTime.toISOString(),
    endTime: endTime.toISOString(),
    durationMs: endTime.getTime() - startTime.getTime(),
    mode: 'incremental',
    seasonId,
    datesProcessed: results.length,
    totalGamesFound,
    totalGamesUpserted,
    results,
    errors,
  };
  
  logger.info('ScheduleSync: Completed incremental sync', {
    durationMs: summary.durationMs,
    datesProcessed: summary.datesProcessed,
    totalGamesFound: summary.totalGamesFound,
    totalGamesUpserted: summary.totalGamesUpserted,
    errorCount: summary.errors.length,
  });
  
  return summary;
}

/**
 * Full season sync (Mode A)
 * Attempts to fetch all games for the entire season in one request
 * Falls back to incremental if bulk fetch fails or returns incomplete data
 */
export async function runFullSeasonSync(
  league: string = 'nba',
  seasonId: string = 'nba_2025-26'
): Promise<ScheduleSyncSummary> {
  const startTime = new Date();
  const errors: string[] = [];
  
  logger.info('ScheduleSync: Starting full season sync', { league, seasonId });
  
  const season = store.getSeason(seasonId);
  if (!season) {
    errors.push(`Season not found: ${seasonId}`);
    return {
      startTime: startTime.toISOString(),
      endTime: new Date().toISOString(),
      durationMs: Date.now() - startTime.getTime(),
      mode: 'bulk',
      seasonId,
      datesProcessed: 0,
      totalGamesFound: 0,
      totalGamesUpserted: 0,
      results: [],
      errors,
    };
  }
  
  // For now, fall back to incremental sync covering the full season
  // A true bulk endpoint would need ESPN to support date range queries
  // that return all games (not just the first day in range)
  
  const seasonStart = new Date(season.preseasonStart || season.startDate);
  const seasonEnd = new Date(season.postseasonEnd || season.endDate);
  const today = new Date();
  
  // Calculate days back and forward from today
  const daysBack = Math.ceil((today.getTime() - seasonStart.getTime()) / (1000 * 60 * 60 * 24));
  const daysForward = Math.ceil((seasonEnd.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
  
  logger.info('ScheduleSync: Full season covering', { daysBack, daysForward });
  
  // Run incremental sync with full coverage
  return runIncrementalSync(league, daysBack, daysForward, seasonId);
}

/**
 * Schedule the sync job to run daily at 04:00 UTC
 */
export function scheduleScheduleSync(): NodeJS.Timeout {
  const ONE_DAY = 24 * 60 * 60 * 1000;
  
  // Calculate time until next 04:00 UTC
  const now = new Date();
  const targetHour = 4;
  
  const nextRun = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    targetHour,
    0,
    0,
    0
  ));
  
  // If we've passed 04:00 UTC today, schedule for tomorrow
  if (now.getTime() > nextRun.getTime()) {
    nextRun.setUTCDate(nextRun.getUTCDate() + 1);
  }
  
  const msUntilNextRun = nextRun.getTime() - now.getTime();
  
  logger.info('ScheduleSync: Scheduled daily run', {
    nextRun: nextRun.toISOString(),
    msUntilNextRun,
  });
  
  // Schedule first run
  const firstTimeout = setTimeout(async () => {
    await runIncrementalSync('nba', 7, 30, 'nba_2025-26');
    
    // Then schedule recurring runs every 24 hours
    setInterval(async () => {
      await runIncrementalSync('nba', 7, 30, 'nba_2025-26');
    }, ONE_DAY);
    
  }, msUntilNextRun);
  
  return firstTimeout;
}

// =====================
// Export Store Access (for other modules)
// =====================

export function getScheduleStore() {
  return store;
}

/**
 * Force save the schedule store to disk
 */
export function saveScheduleStore(): void {
  store.saveToDisk();
}

export function getLeagueSeason(seasonId: string): LeagueSeason | undefined {
  return store.getSeason(seasonId);
}

export function getSeasonForDate(leagueId: string, date: string): LeagueSeason | undefined {
  return store.getSeasonForDate(leagueId, date);
}

export function getGameDateEntry(leagueId: string, date: string): GameDateEntry | undefined {
  return store.getGameDateEntry(leagueId, date);
}

export function getGamesForDate(leagueId: string, date: string): GameRecord[] {
  return store.getGamesForDate(leagueId, date);
}

export function getScheduleSyncStats(): {
  seasons: number;
  games: number;
  gameDates: number;
} {
  return store.getStats();
}

/**
 * Check if a date is within the active season
 */
export function isDateInSeason(leagueId: string, date: string): boolean {
  return store.getSeasonForDate(leagueId, date) !== undefined;
}

/**
 * Check if a date has games (based on game_dates index)
 */
export function dateHasGames(leagueId: string, date: string): boolean {
  const entry = store.getGameDateEntry(leagueId, date);
  return entry !== undefined && entry.gameCount > 0;
}
