/**
 * Admin routes - internal monitoring endpoints
 */

import { Router, Request, Response, NextFunction } from 'express';
import {
  runIncrementalSync,
  getScheduleSyncStats,
  getLeagueSeason,
  getGameDateEntry,
  isDateInSeason,
} from '../jobs';
import { materializeGameDates, getGameDatesStats } from '../jobs';
import { getStorageStats } from '../cache/BoxScoreStorage';
import { backfillPlayers } from '../jobs/playerIngestion';
import { logger } from '../utils/logger';

export const adminRouter = Router();

/**
 * GET /v1/admin/health
 * Basic health check
 */
adminRouter.get('/health', async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json({
      data: {
        status: 'healthy',
        provider: 'espn',
        timestamp: new Date().toISOString(),
      },
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /v1/admin/storage/stats
 * Get persistent storage statistics
 */
adminRouter.get('/storage/stats', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const stats = getStorageStats();

    res.json({
      data: {
        ...stats,
        totalSizeMB: (stats.totalSizeBytes / (1024 * 1024)).toFixed(2),
      },
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});

// =====================
// Schedule Sync Endpoints
// =====================

/**
 * GET /v1/admin/schedule/stats
 * Get schedule sync and game_dates statistics
 */
adminRouter.get('/schedule/stats', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const seasonId = req.query.seasonId as string || 'nba_2025-26';

    const syncStats = getScheduleSyncStats();
    const gameDatesStats = getGameDatesStats(seasonId);
    const season = getLeagueSeason(seasonId);

    res.json({
      data: {
        season: season ? {
          id: season.id,
          leagueId: season.leagueId,
          seasonLabel: season.seasonLabel,
          startDate: season.startDate,
          endDate: season.endDate,
          status: season.status,
          lastScheduleSyncAt: season.lastScheduleSyncAt?.toISOString(),
        } : null,
        store: syncStats,
        gameDates: gameDatesStats,
      },
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /v1/admin/schedule/sync
 * Manually trigger schedule sync
 * Query params:
 *   - league: league to sync (default: "nba")
 *   - daysBack: days before today (default: 7)
 *   - daysForward: days after today (default: 30)
 *   - seasonId: season ID (default: "nba_2025-26")
 */
adminRouter.post('/schedule/sync', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = String(req.query.league || 'nba').toLowerCase();
    const daysBack = parseInt(String(req.query.daysBack || '7'), 10);
    const daysForward = parseInt(String(req.query.daysForward || '30'), 10);
    const seasonId = String(req.query.seasonId || 'nba_2025-26');

    logger.info('Admin: Manual schedule sync triggered', {
      league,
      daysBack,
      daysForward,
      seasonId
    });

    const result = await runIncrementalSync(league, daysBack, daysForward, seasonId);

    res.json({
      data: result,
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /v1/admin/schedule/materialize
 * Rebuild game_dates index from games table
 * Query params:
 *   - seasonId: season ID (default: "nba_2025-26")
 */
adminRouter.post('/schedule/materialize', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const seasonId = String(req.query.seasonId || 'nba_2025-26');

    logger.info('Admin: Manual game_dates materialization triggered', { seasonId });

    const result = await materializeGameDates(seasonId);

    res.json({
      data: result,
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /v1/admin/schedule/date/:date
 * Get game_dates entry for a specific date
 */
adminRouter.get('/schedule/date/:date', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const date = String(req.params.date);
    const league = String(req.query.league || 'nba').toLowerCase();

    const gameDateEntry = getGameDateEntry(league, date);
    const inSeason = isDateInSeason(league, date);

    res.json({
      data: {
        date,
        league,
        inSeason,
        gameDateEntry: gameDateEntry ? {
          leagueId: gameDateEntry.leagueId,
          seasonId: gameDateEntry.seasonId,
          scoreboardDate: gameDateEntry.scoreboardDate,
          gameCount: gameDateEntry.gameCount,
          firstGameTimeUtc: gameDateEntry.firstGameTimeUtc,
          lastGameTimeUtc: gameDateEntry.lastGameTimeUtc,
          hasLiveGames: gameDateEntry.hasLiveGames,
          allGamesFinal: gameDateEntry.allGamesFinal,
          lastRefreshedAt: gameDateEntry.lastRefreshedAt.toISOString(),
        } : null,
        wouldSkipEspnCall: !inSeason || (gameDateEntry?.gameCount === 0),
      },
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});

// =====================
// Player Backfill Endpoints
// =====================

/**
 * POST /v1/admin/backfill/players
 * Backfill player game logs for un-ingested final games.
 * Synchronous — waits until all games are processed, then returns results.
 *
 * Body params:
 *   - league: league to backfill (default: "nba")
 *   - season: season year (default: 2025)
 *   - limit: max games to process (default: 500)
 */
adminRouter.post('/backfill/players', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = String(req.body?.league || 'nba').toLowerCase();
    const season = req.body?.season ? parseInt(String(req.body.season), 10) : undefined;
    const limit = parseInt(String(req.body?.limit || '500'), 10);

    logger.info('Admin: Player backfill triggered', { league, season, limit });

    const result = await backfillPlayers(league, season, limit);

    res.json({
      data: result,
      meta: {
        requestId: req.requestId,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    next(error);
  }
});
