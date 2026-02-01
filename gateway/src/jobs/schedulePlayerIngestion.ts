/**
 * Scheduled Player Ingestion
 *
 * Runs hourly at :30 to ingest player data from newly-finalized NBA games.
 * Finds games with status='final' that have no rows in nba_player_game_logs.
 */

import { logger } from '../utils/logger';
import { ingestPlayersFromGame } from './playerIngestion';
import { query } from '../db/pool';

const ONE_HOUR = 60 * 60 * 1000;

/**
 * Run a single ingestion pass: find un-ingested final games and process them.
 */
async function runPlayerIngestion(): Promise<void> {
  const startTime = Date.now();

  try {
    const gameRows = await query<{ id: string }>(
      `SELECT g.id FROM games g
       LEFT JOIN nba_player_game_logs gl ON gl.game_id = g.id
       WHERE g.league_id = 'nba' AND g.status = 'final'
       AND gl.game_id IS NULL
       ORDER BY g.scoreboard_date DESC`,
      []
    );

    if (gameRows.length === 0) {
      logger.debug('PlayerIngestion: No un-ingested games found');
      return;
    }

    logger.info('PlayerIngestion: Found un-ingested games', { count: gameRows.length });

    let successCount = 0;
    let errorCount = 0;

    for (const game of gameRows) {
      try {
        await ingestPlayersFromGame(game.id);
        successCount++;
      } catch (error) {
        errorCount++;
        logger.error('PlayerIngestion: Failed to ingest game', {
          gameId: game.id,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const duration = Date.now() - startTime;
    logger.info('PlayerIngestion: Completed hourly run', {
      totalGames: gameRows.length,
      successCount,
      errorCount,
      durationMs: duration,
    });
  } catch (error) {
    logger.error('PlayerIngestion: Hourly run failed', {
      durationMs: Date.now() - startTime,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Schedule hourly player ingestion at :30 past each hour UTC.
 * Follows the same setTimeout → setInterval pattern as scheduleScheduleSync.
 */
export function schedulePlayerIngestion(): NodeJS.Timeout {
  const now = new Date();

  // Calculate next :30 mark
  const nextRun = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
    now.getUTCHours(),
    30,
    0,
    0
  ));

  // If we've passed :30 this hour, schedule for next hour
  if (now.getTime() > nextRun.getTime()) {
    nextRun.setTime(nextRun.getTime() + ONE_HOUR);
  }

  const msUntilNextRun = nextRun.getTime() - now.getTime();

  logger.info('PlayerIngestion: Scheduled hourly run', {
    nextRun: nextRun.toISOString(),
    msUntilNextRun,
  });

  const firstTimeout = setTimeout(async () => {
    await runPlayerIngestion();

    setInterval(async () => {
      await runPlayerIngestion();
    }, ONE_HOUR);
  }, msUntilNextRun);

  return firstTimeout;
}
