/**
 * Player Ingestion Jobs
 *
 * Jobs to ingest player data from ESPN box scores and update stats
 */

import { logger } from '../utils/logger';
import { getESPNAdapter } from '../providers/espnAdapter';
import {
  processBoxScoreForPlayers,
  getSeasonFromGameDate,
} from '../providers/espnPlayerExtractor';
import { query } from '../db/pool';

/**
 * Ingest players from a single game's box score
 *
 * @param gameId - Internal game ID (e.g., 'nba_401584701')
 */
export async function ingestPlayersFromGame(gameId: string): Promise<void> {
  const startTime = Date.now();

  try {
    logger.info('Starting player ingestion for game', { gameId });

    // Parse league from game ID
    const leaguePrefix = gameId.split('_')[0];

    // Fetch game info to get game date
    const gameRows = await query<{ game_date: Date; scoreboard_date: Date }>(
      'SELECT game_date, scoreboard_date FROM games WHERE id = $1',
      [gameId]
    );

    if (!gameRows.length) {
      throw new Error(`Game not found: ${gameId}`);
    }

    const gameDate = new Date(gameRows[0].game_date);
    const season = getSeasonFromGameDate(gameDate, leaguePrefix);

    // Fetch box score from ESPN
    const espnAdapter = getESPNAdapter();
    const boxScoreResponse = await espnAdapter.fetchBoxScore(gameId, leaguePrefix);

    // Extract ESPN summary from the response
    // The fetchBoxScore method returns BoxScoreResponse, but internally it fetches ESPNSummaryResponse
    // We need to call the ESPN API directly to get the raw response
    const espnId = gameId.split('_').slice(1).join('_');
    const sportPath = getSportPath(leaguePrefix);
    const url = `https://site.web.api.espn.com/apis/site/v2/sports/${sportPath}/summary?event=${espnId}`;

    logger.debug('Fetching ESPN summary for player ingestion', { url, gameId });

    const axios = require('axios');
    const response = await axios.get(url, {
      timeout: 15000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'BoxScore/1.0',
      },
    });

    const summary = response.data;

    // Process box score to extract players and update stats
    await processBoxScoreForPlayers(summary, leaguePrefix, season);

    const duration = Date.now() - startTime;
    logger.info('Completed player ingestion for game', {
      gameId,
      season,
      durationMs: duration,
    });

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Failed to ingest players from game', {
      gameId,
      durationMs: duration,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

/**
 * Ingest players from all games on a specific date
 *
 * @param league - League identifier (e.g., 'nba')
 * @param date - Date in YYYY-MM-DD format
 */
export async function ingestPlayersFromDate(league: string, date: string): Promise<void> {
  const startTime = Date.now();

  try {
    logger.info('Starting player ingestion for date', { league, date });

    // Fetch all games for this date
    const gameRows = await query<{ id: string }>(
      'SELECT id FROM games WHERE league_id = $1 AND scoreboard_date = $2',
      [league, date]
    );

    logger.info('Found games for date', {
      league,
      date,
      gameCount: gameRows.length,
    });

    // Process each game
    let successCount = 0;
    let errorCount = 0;

    for (const game of gameRows) {
      try {
        await ingestPlayersFromGame(game.id);
        successCount++;
      } catch (error) {
        errorCount++;
        logger.error('Failed to ingest players from game', {
          gameId: game.id,
          error: error instanceof Error ? error.message : String(error),
        });
        // Continue processing other games
      }
    }

    const duration = Date.now() - startTime;
    logger.info('Completed player ingestion for date', {
      league,
      date,
      totalGames: gameRows.length,
      successCount,
      errorCount,
      durationMs: duration,
    });

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Failed to ingest players from date', {
      league,
      date,
      durationMs: duration,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

/**
 * Backfill players from all existing box scores in the database
 *
 * @param league - League identifier (e.g., 'nba')
 * @param season - Season year (e.g., 2025)
 * @param limit - Maximum number of games to process (default: no limit)
 */
export async function backfillPlayersFromExistingGames(
  league: string,
  season: number,
  limit?: number
): Promise<void> {
  const startTime = Date.now();

  try {
    logger.info('Starting player backfill', { league, season, limit });

    // Fetch all games for this season
    const query_text = limit
      ? 'SELECT id FROM games WHERE league_id = $1 AND season_id LIKE $2 ORDER BY game_date DESC LIMIT $3'
      : 'SELECT id FROM games WHERE league_id = $1 AND season_id LIKE $2 ORDER BY game_date DESC';

    const params = limit
      ? [league, `${league}_${season}%`, limit]
      : [league, `${league}_${season}%`];

    const gameRows = await query<{ id: string }>(query_text, params);

    logger.info('Found games for backfill', {
      league,
      season,
      gameCount: gameRows.length,
    });

    // Process each game
    let successCount = 0;
    let errorCount = 0;

    for (const game of gameRows) {
      try {
        await ingestPlayersFromGame(game.id);
        successCount++;

        // Add small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 500));
      } catch (error) {
        errorCount++;
        logger.error('Failed to backfill players from game', {
          gameId: game.id,
          error: error instanceof Error ? error.message : String(error),
        });
        // Continue processing other games
      }
    }

    const duration = Date.now() - startTime;
    logger.info('Completed player backfill', {
      league,
      season,
      totalGames: gameRows.length,
      successCount,
      errorCount,
      durationMs: duration,
    });

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Failed to backfill players', {
      league,
      season,
      durationMs: duration,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

/**
 * Helper to get ESPN sport path from league prefix
 */
function getSportPath(leaguePrefix: string): string {
  switch (leaguePrefix.toLowerCase()) {
    case 'nba':
      return 'basketball/nba';
    case 'nfl':
      return 'football/nfl';
    case 'ncaaf':
      return 'football/college-football';
    case 'ncaam':
      return 'basketball/mens-college-basketball';
    case 'mlb':
      return 'baseball/mlb';
    case 'nhl':
      return 'hockey/nhl';
    default:
      throw new Error(`Unsupported league: ${leaguePrefix}`);
  }
}
