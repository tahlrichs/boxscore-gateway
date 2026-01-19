/**
 * CachePolicy - Tiered caching with game-status-aware TTLs
 * 
 * TTL Strategy (aligned with ESPN rate limiting plan):
 * - Live games: 60s (frequent updates during active games)
 * - Scheduled games (today): 5 min (check for status changes)
 * - Final games (today): 6h (might get stat corrections)
 * - Historical: 24h+ (won't change)
 * - Standings: 18-24h (change overnight)
 * - Schedule: 24h (rarely changes)
 */

import { Game, BoxScoreResponse } from '../types';

export interface CacheTTLs {
  liveScoreboard: number;
  scheduledScoreboardToday: number;
  finalScoreboardSameDay: number;
  finalScoreboardHistorical: number;
  liveBoxScore: number;
  finalBoxScoreSameDay: number;
  finalBoxScore: number;
  standings: number;
  schedule: number;
  // No-games TTLs (new for schedule-driven approach)
  noGamesVerified: number;
  noGamesOffSeason: number;
  noGamesUnknownInSeason: number;
}

// Default TTLs in seconds (aligned with ESPN rate limiting plan)
export const DEFAULT_CACHE_TTLS: CacheTTLs = {
  liveScoreboard: 60,                    // 1 minute (poll frequently during live)
  scheduledScoreboardToday: 5 * 60,      // 5 minutes (check for status changes)
  finalScoreboardSameDay: 6 * 60 * 60,   // 6 hours (may get stat corrections)
  finalScoreboardHistorical: 24 * 60 * 60, // 24 hours (won't change)
  liveBoxScore: 90,                       // 90 seconds (active game updates)
  finalBoxScoreSameDay: 6 * 60 * 60,     // 6 hours (stat corrections possible)
  finalBoxScore: 7 * 24 * 60 * 60,       // 7 days (effectively permanent)
  standings: 18 * 60 * 60,               // 18 hours
  schedule: 24 * 60 * 60,                // 24 hours
  // No-games TTLs - avoid re-checking ESPN for dates with no games
  noGamesVerified: 24 * 60 * 60,         // 24 hours (verified via game_dates index)
  noGamesOffSeason: 7 * 24 * 60 * 60,    // 7 days (off-season, won't change)
  noGamesUnknownInSeason: 6 * 60 * 60,   // 6 hours (in-season but unknown, re-check)
};

/**
 * Determine the appropriate TTL for scoreboard data
 * 
 * TTL hierarchy:
 * 1. Has live games -> 60s (frequent updates)
 * 2. Today, all scheduled -> 5 min (status changes expected)
 * 3. Today, all final -> 6 hours (may get corrections)
 * 4. Historical -> 24 hours (won't change)
 */
export function getScoreboardTTL(games: Game[], requestDate: string): number {
  // Check for live games first
  const hasLiveGames = games.some(g => g.status === 'live');
  if (hasLiveGames) {
    return DEFAULT_CACHE_TTLS.liveScoreboard;
  }
  
  // Check if this is today's date
  const today = new Date().toISOString().split('T')[0];
  const isToday = requestDate === today;
  
  if (isToday) {
    // Check if any games are scheduled (not yet started)
    const hasScheduledGames = games.some(g => g.status === 'scheduled');
    if (hasScheduledGames) {
      return DEFAULT_CACHE_TTLS.scheduledScoreboardToday;
    }
    // All games are final
    return DEFAULT_CACHE_TTLS.finalScoreboardSameDay;
  }
  
  // Historical date
  return DEFAULT_CACHE_TTLS.finalScoreboardHistorical;
}

/**
 * Determine the appropriate TTL for box score data
 * 
 * TTL hierarchy:
 * 1. Live game -> 90s (active updates)
 * 2. Final, same day -> 6 hours (corrections possible)
 * 3. Final, historical -> 7 days (permanent)
 */
export function getBoxScoreTTL(boxScore: BoxScoreResponse): number {
  if (boxScore.game.status === 'live') {
    return DEFAULT_CACHE_TTLS.liveBoxScore;
  }
  
  // Check if this is today's game (final games may get corrections)
  const gameDate = new Date(boxScore.game.startTime).toISOString().split('T')[0];
  const today = new Date().toISOString().split('T')[0];
  
  if (gameDate === today) {
    return DEFAULT_CACHE_TTLS.finalBoxScoreSameDay;
  }
  
  return DEFAULT_CACHE_TTLS.finalBoxScore;
}

/**
 * Check if a game should be stored permanently (final games)
 */
export function shouldStorePermanently(game: Game): boolean {
  return game.status === 'final';
}

/**
 * Get TTL for standings data
 */
export function getStandingsTTL(): number {
  return DEFAULT_CACHE_TTLS.standings;
}

/**
 * Get TTL for schedule data
 */
export function getScheduleTTL(): number {
  return DEFAULT_CACHE_TTLS.schedule;
}

/**
 * Get TTL for "no games" responses based on reason
 * 
 * This is key to the schedule-driven approach:
 * - Verified no-games: 24h (we know from game_dates there are no games)
 * - Off-season: 7 days (won't change until next season)
 * - Unknown in-season: 6h (might be a newly added game day)
 */
export function getNoGamesTTL(reason: string): number {
  switch (reason) {
    case 'no-games-verified':
      return DEFAULT_CACHE_TTLS.noGamesVerified;
    case 'off-season':
      return DEFAULT_CACHE_TTLS.noGamesOffSeason;
    case 'unknown-in-season':
      return DEFAULT_CACHE_TTLS.noGamesUnknownInSeason;
    default:
      // Default to shorter TTL for unknown reasons
      return DEFAULT_CACHE_TTLS.noGamesUnknownInSeason;
  }
}

/**
 * Get TTL for scoreboard based on game_dates metadata
 * Enhanced version that considers game_dates index data
 */
export function getScoreboardTTLWithGameDates(
  games: Game[],
  requestDate: string,
  gameDateEntry?: {
    hasLiveGames: boolean;
    allGamesFinal: boolean;
    lastRefreshedAt?: Date;
  }
): number {
  // If game_dates says there are live games, use live TTL
  if (gameDateEntry?.hasLiveGames) {
    return DEFAULT_CACHE_TTLS.liveScoreboard;
  }
  
  // If game_dates says all games are final, use appropriate final TTL
  if (gameDateEntry?.allGamesFinal) {
    const today = new Date().toISOString().split('T')[0];
    if (requestDate === today) {
      return DEFAULT_CACHE_TTLS.finalScoreboardSameDay;
    }
    return DEFAULT_CACHE_TTLS.finalScoreboardHistorical;
  }
  
  // Fall back to standard TTL calculation
  return getScoreboardTTL(games, requestDate);
}
