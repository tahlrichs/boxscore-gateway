/**
 * Player Ingestion Jobs
 *
 * Jobs to ingest player data from ESPN box scores and update stats
 */

import { logger } from '../utils/logger';
import { getESPNAdapter } from '../providers/espnAdapter';
import {
  processBoxScoreForPlayers,
  extractAndUpsertPlayersFromBoxScore,
  getSeasonFromGameDate,
} from '../providers/espnPlayerExtractor';
import {
  recomputeSeasonSummary,
  recomputeNBASplits,
} from '../db/repositories/playerRepository';
import { query } from '../db/pool';

interface IngestOptions {
  /** Skip recomputeSeasonSummary/recomputeNBASplits (used during backfill) */
  skipRecomputation?: boolean;
}

/**
 * Ingest players from a single game's box score
 *
 * @param gameId - Internal game ID (e.g., 'nba_401584701')
 * @param options - Ingestion options
 * @returns Array of player IDs that were upserted
 */
export async function ingestPlayersFromGame(
  gameId: string,
  options: IngestOptions = {}
): Promise<string[]> {
  const startTime = Date.now();

  try {
    logger.info('Starting player ingestion for game', { gameId });

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

    // Fetch raw summary from ESPN (rate-limited)
    const espnAdapter = getESPNAdapter();
    const summary = await espnAdapter.fetchRawSummary(gameId);

    let playerIds: string[];

    if (options.skipRecomputation) {
      // Extract and upsert players without recomputing stats
      playerIds = await extractAndUpsertPlayersFromBoxScore(summary, leaguePrefix, season);
    } else {
      // Full processing: extract, upsert, and recompute stats
      await processBoxScoreForPlayers(summary, leaguePrefix, season);
      playerIds = []; // processBoxScoreForPlayers doesn't return IDs but handles recomputation
    }

    const duration = Date.now() - startTime;
    logger.info('Completed player ingestion for game', {
      gameId,
      season,
      durationMs: duration,
    });

    return playerIds;

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
 */
export async function ingestPlayersFromDate(league: string, date: string): Promise<void> {
  const startTime = Date.now();

  try {
    logger.info('Starting player ingestion for date', { league, date });

    const gameRows = await query<{ id: string }>(
      'SELECT id FROM games WHERE league_id = $1 AND scoreboard_date = $2',
      [league, date]
    );

    logger.info('Found games for date', {
      league,
      date,
      gameCount: gameRows.length,
    });

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

export interface BackfillResult {
  processed: number;
  failed: number;
  failedGameIds: string[];
}

/**
 * Backfill player data for un-ingested final games.
 * Uses deferred recomputation: extracts players without recomputing per-game stats,
 * then does a single recomputation pass for all affected players at the end.
 */
export async function backfillPlayers(
  league: string = 'nba',
  season?: number,
  limit: number = 500
): Promise<BackfillResult> {
  const startTime = Date.now();

  // Default season: NBA 2025-26 season → 2025
  const effectiveSeason = season ?? 2025;

  try {
    logger.info('Starting player backfill', { league, season: effectiveSeason, limit });

    // Find un-ingested final games
    const gameRows = await query<{ id: string }>(
      `SELECT g.id FROM games g
       LEFT JOIN nba_player_game_logs gl ON gl.game_id = g.id
       WHERE g.league_id = $1 AND g.status = 'final'
       AND gl.game_id IS NULL
       ORDER BY g.scoreboard_date DESC
       LIMIT $2`,
      [league, limit]
    );

    logger.info('Found un-ingested games for backfill', {
      league,
      season: effectiveSeason,
      gameCount: gameRows.length,
    });

    let processed = 0;
    let failed = 0;
    const failedGameIds: string[] = [];
    const allPlayerIds = new Set<string>();

    for (const game of gameRows) {
      try {
        const playerIds = await ingestPlayersFromGame(game.id, { skipRecomputation: true });
        for (const id of playerIds) allPlayerIds.add(id);
        processed++;

        if (processed % 50 === 0) {
          logger.info('Backfill progress', { processed, failed, total: gameRows.length });
        }
      } catch (error) {
        failed++;
        failedGameIds.push(game.id);
        logger.error('Failed to backfill game', {
          gameId: game.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    // Deferred recomputation: recompute stats for all affected players once
    if (allPlayerIds.size > 0) {
      logger.info('Starting deferred recomputation', { playerCount: allPlayerIds.size });
      let recomputeSuccess = 0;
      let recomputeFail = 0;

      for (const playerId of allPlayerIds) {
        try {
          await recomputeSeasonSummary(playerId, effectiveSeason);
          await recomputeNBASplits(playerId, effectiveSeason);
          recomputeSuccess++;
        } catch (error) {
          recomputeFail++;
          logger.error('Failed to recompute stats for player', {
            playerId,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }

      logger.info('Completed deferred recomputation', { recomputeSuccess, recomputeFail });
    }

    const duration = Date.now() - startTime;
    logger.info('Completed player backfill', {
      league,
      season: effectiveSeason,
      processed,
      failed,
      uniquePlayers: allPlayerIds.size,
      durationMs: duration,
    });

    return { processed, failed, failedGameIds };

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Failed to backfill players', {
      league,
      season: effectiveSeason,
      durationMs: duration,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}
