/**
 * GameDates Materialization Job
 * 
 * Rebuilds the game_dates index from the games table.
 * This ensures the game_dates index is always consistent with the games data.
 * 
 * Two modes:
 * - Full rebuild: Rebuilds all game_dates for a season
 * - Incremental: Updates only changed dates (triggered by game upserts)
 * 
 * Schedule: Nightly at 02:00 UTC (before schedule sync at 04:00 UTC)
 */

import { 
  getScheduleStore, 
  GameDateEntry, 
  GameRecord,
  getLeagueSeason,
} from './scheduleSync';
import { logger } from '../utils/logger';

// =====================
// Types
// =====================

export interface MaterializationResult {
  seasonId: string;
  datesProcessed: number;
  datesCreated: number;
  datesUpdated: number;
  durationMs: number;
  errors: string[];
}

// =====================
// Core Functions
// =====================

/**
 * Build a single game_dates entry from games
 */
function buildGameDateEntry(
  leagueId: string,
  seasonId: string,
  scoreboardDate: string,
  games: GameRecord[]
): GameDateEntry {
  const filteredGames = games.filter(
    g => g.leagueId === leagueId && g.scoreboardDate === scoreboardDate
  );
  
  const startTimes = filteredGames
    .map(g => g.startTimeUtc)
    .filter(Boolean)
    .sort();
  
  return {
    leagueId,
    seasonId,
    scoreboardDate,
    gameCount: filteredGames.length,
    firstGameTimeUtc: startTimes[0],
    lastGameTimeUtc: startTimes[startTimes.length - 1],
    hasLiveGames: filteredGames.some(g => g.status === 'live'),
    allGamesFinal: filteredGames.length > 0 && filteredGames.every(g => g.status === 'final'),
    lastRefreshedAt: new Date(),
  };
}

/**
 * Full rebuild of game_dates for a season
 */
export async function materializeGameDates(
  seasonId: string = 'nba_2025-26'
): Promise<MaterializationResult> {
  const startTime = Date.now();
  const result: MaterializationResult = {
    seasonId,
    datesProcessed: 0,
    datesCreated: 0,
    datesUpdated: 0,
    durationMs: 0,
    errors: [],
  };
  
  logger.info('MaterializeGameDates: Starting rebuild', { seasonId });
  
  const store = getScheduleStore();
  const season = getLeagueSeason(seasonId);
  
  if (!season) {
    result.errors.push(`Season not found: ${seasonId}`);
    result.durationMs = Date.now() - startTime;
    return result;
  }
  
  try {
    // Get all games for this season
    const allGames = store.getAllGames().filter(g => g.seasonId === seasonId);
    
    // Group games by scoreboard_date
    const gamesByDate = new Map<string, GameRecord[]>();
    for (const game of allGames) {
      const existing = gamesByDate.get(game.scoreboardDate) || [];
      existing.push(game);
      gamesByDate.set(game.scoreboardDate, existing);
    }
    
    logger.debug('MaterializeGameDates: Grouped games', {
      totalGames: allGames.length,
      uniqueDates: gamesByDate.size,
    });
    
    // Build and upsert game_dates entries
    for (const [scoreboardDate, games] of gamesByDate) {
      try {
        const existing = store.getGameDateEntry(season.leagueId, scoreboardDate);
        const entry = buildGameDateEntry(season.leagueId, seasonId, scoreboardDate, games);
        
        store.upsertGameDateEntry(entry);
        result.datesProcessed++;
        
        if (!existing) {
          result.datesCreated++;
        } else {
          result.datesUpdated++;
        }
      } catch (error) {
        const errMsg = error instanceof Error ? error.message : String(error);
        result.errors.push(`Date ${scoreboardDate}: ${errMsg}`);
      }
    }
    
  } catch (error) {
    const errMsg = error instanceof Error ? error.message : String(error);
    result.errors.push(errMsg);
    logger.error('MaterializeGameDates: Failed', { error: errMsg });
  }
  
  result.durationMs = Date.now() - startTime;
  
  logger.info('MaterializeGameDates: Completed', {
    seasonId,
    datesProcessed: result.datesProcessed,
    datesCreated: result.datesCreated,
    datesUpdated: result.datesUpdated,
    durationMs: result.durationMs,
    errorCount: result.errors.length,
  });
  
  return result;
}

/**
 * Incremental update for specific dates
 * Called when games are upserted to keep game_dates in sync
 */
export async function updateGameDatesForDates(
  leagueId: string,
  seasonId: string,
  dates: string[]
): Promise<void> {
  const store = getScheduleStore();
  
  for (const scoreboardDate of dates) {
    const games = store.getGamesForDate(leagueId, scoreboardDate);
    const entry = buildGameDateEntry(leagueId, seasonId, scoreboardDate, games);
    store.upsertGameDateEntry(entry);
  }
  
  logger.debug('MaterializeGameDates: Incremental update', {
    leagueId,
    seasonId,
    datesUpdated: dates.length,
  });
}

/**
 * Update game_dates status flags for a specific date
 * Called during live game updates to refresh has_live_games and all_games_final
 */
export async function refreshGameDateStatus(
  leagueId: string,
  scoreboardDate: string
): Promise<GameDateEntry | null> {
  const store = getScheduleStore();
  const existing = store.getGameDateEntry(leagueId, scoreboardDate);
  
  if (!existing) {
    return null;
  }
  
  const games = store.getGamesForDate(leagueId, scoreboardDate);
  
  const updated: GameDateEntry = {
    ...existing,
    hasLiveGames: games.some(g => g.status === 'live'),
    allGamesFinal: games.length > 0 && games.every(g => g.status === 'final'),
    lastRefreshedAt: new Date(),
  };
  
  store.upsertGameDateEntry(updated);
  return updated;
}

/**
 * Schedule nightly materialization at 02:00 UTC
 */
export function scheduleNightlyMaterialization(): NodeJS.Timeout {
  const ONE_DAY = 24 * 60 * 60 * 1000;
  
  // Calculate time until next 02:00 UTC
  const now = new Date();
  const targetHour = 2;
  
  const nextRun = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    targetHour,
    0,
    0,
    0
  ));
  
  // If we've passed 02:00 UTC today, schedule for tomorrow
  if (now.getTime() > nextRun.getTime()) {
    nextRun.setUTCDate(nextRun.getUTCDate() + 1);
  }
  
  const msUntilNextRun = nextRun.getTime() - now.getTime();
  
  logger.info('MaterializeGameDates: Scheduled nightly run', {
    nextRun: nextRun.toISOString(),
    msUntilNextRun,
  });
  
  // Schedule first run
  const firstTimeout = setTimeout(async () => {
    await materializeGameDates('nba_2025-26');
    
    // Then schedule recurring runs every 24 hours
    setInterval(async () => {
      await materializeGameDates('nba_2025-26');
    }, ONE_DAY);
    
  }, msUntilNextRun);
  
  return firstTimeout;
}

/**
 * Get game_dates statistics
 */
export function getGameDatesStats(seasonId?: string): {
  totalDates: number;
  datesWithGames: number;
  datesWithLiveGames: number;
  datesAllFinal: number;
  totalGameCount: number;
} {
  const store = getScheduleStore();
  const allGameDates = store.getAllGameDates();
  
  const filtered = seasonId 
    ? allGameDates.filter(gd => gd.seasonId === seasonId)
    : allGameDates;
  
  return {
    totalDates: filtered.length,
    datesWithGames: filtered.filter(gd => gd.gameCount > 0).length,
    datesWithLiveGames: filtered.filter(gd => gd.hasLiveGames).length,
    datesAllFinal: filtered.filter(gd => gd.allGamesFinal).length,
    totalGameCount: filtered.reduce((sum, gd) => sum + gd.gameCount, 0),
  };
}
