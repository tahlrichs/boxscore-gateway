/**
 * Player API Routes
 *
 * Endpoints:
 * - GET /search - Player search by name
 * - GET /:id/stat-central - Season-by-season stats + career averages
 * - GET /:id - Player header (bio + current season stats)
 */

import { Router, Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import {
  getPlayerById,
  searchPlayers,
} from '../db/repositories/playerRepository';
import { query } from '../db/pool';
import { getPlayerStats } from '../providers/espnPlayerService';
import { buildStatCentral } from '../providers/playerStatCentral';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';
import { StatCentralResponse } from '../types/statCentral';
import { getCurrentSeason } from '../utils/seasonUtils';

const router = Router();

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * GET /v1/players/search
 */
router.get('/search', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const queryStr = req.query.q as string;
    const sport = req.query.sport as string | undefined;
    const limit = parseInt(req.query.limit as string) || 20;

    if (!queryStr || queryStr.trim().length === 0) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Query parameter "q" is required',
      });
      return;
    }

    if (queryStr.trim().length < 2) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Query must be at least 2 characters',
      });
      return;
    }

    logger.debug('Searching players', { query: queryStr, sport, limit });

    const players = await searchPlayers(queryStr.trim(), sport, Math.min(limit, 50));

    const response = {
      players: players.map(p => ({
        id: p.id,
        sport: p.sport,
        displayName: p.display_name,
        position: p.position,
        currentTeamId: p.current_team_id,
      })),
      meta: {
        query: queryStr,
        sport: sport || null,
        count: players.length,
        limit: Math.min(limit, 50),
      },
    };

    res.set('Cache-Control', 'public, max-age=3600, s-maxage=7200');
    res.json(response);

  } catch (error) {
    logger.error('Error searching players', {
      query: req.query.q,
      sport: req.query.sport,
      error: error instanceof Error ? error.message : String(error),
    });
    next(error);
  }
});

/**
 * GET /v1/players/:id/stat-central
 *
 * Returns player bio, all historical seasons, and career averages.
 * Cached in Redis for 1 hour.
 */
router.get('/:id/stat-central', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const playerId = req.params.id as string;
    if (!playerId || !UUID_RE.test(playerId)) {
      throw new BadRequestError('Invalid player ID format');
    }

    // Check Redis cache
    const cacheKey = cacheKeys.playerStatCentral(playerId);
    const cached = await getCached<StatCentralResponse>(cacheKey);
    if (cached) {
      res.set('Cache-Control', 'public, max-age=3600');
      res.json(cached);
      return;
    }

    const data = await buildStatCentral(playerId);

    const response: StatCentralResponse = {
      data,
      meta: { lastUpdated: new Date().toISOString() },
    };

    await setCached(cacheKey, response, 3600);
    res.set('Cache-Control', 'public, max-age=3600');
    res.json(response);
  } catch (error) {
    next(error);
  }
});

/**
 * GET /v1/players/:id
 *
 * Player header - Bio + current season stats from ESPN
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const playerId = req.params.id as string;
    if (!playerId || !UUID_RE.test(playerId)) {
      throw new BadRequestError('Invalid player ID format');
    }

    logger.debug('Fetching player header', { playerId });

    const player = await getPlayerById(playerId);
    if (!player) {
      throw new NotFoundError(`Player not found: ${playerId}`);
    }

    const espnStats = await getPlayerStats(playerId);
    const isLive = await isPlayerLive(playerId);
    const currentSeason = getCurrentSeason();

    const response = {
      player: {
        id: player.id,
        sport: player.sport,
        displayName: player.display_name,
        firstName: player.first_name,
        lastName: player.last_name,
        position: espnStats?.position || player.position,
        heightIn: player.height_in,
        weightLb: player.weight_lb,
        school: espnStats?.college || player.school,
        hometown: player.hometown,
        headshotUrl: espnStats?.headshot || player.headshot_url,
        currentTeamId: player.current_team_id,
        isActive: player.is_active,
        jersey: espnStats?.jersey || player.jersey,
      },
      currentSeason: espnStats?.currentSeasonStats ? {
        season: currentSeason,
        gamesPlayed: espnStats.currentSeasonStats.gamesPlayed,
        gamesStarted: espnStats.currentSeasonStats.gamesStarted,
        ppg: espnStats.currentSeasonStats.points,
        rpg: espnStats.currentSeasonStats.rebounds,
        apg: espnStats.currentSeasonStats.assists,
        fgPct: espnStats.currentSeasonStats.fgPct,   // 0-100 scale
        fg3Pct: espnStats.currentSeasonStats.fg3Pct, // 0-100 scale
        ftPct: espnStats.currentSeasonStats.ftPct,   // 0-100 scale
        spg: espnStats.currentSeasonStats.steals,
        bpg: espnStats.currentSeasonStats.blocks,
        mpg: espnStats.currentSeasonStats.minutesPerGame,
      } : {
        season: currentSeason,
        gamesPlayed: 0,
        gamesStarted: 0,
        ppg: 0,
        rpg: 0,
        apg: 0,
        fgPct: 0,
        fg3Pct: 0,
        ftPct: 0,
      },
      meta: {
        isLive,
        lastUpdated: player.updated_at,
      },
    };

    setCacheHeaders(res, isLive);
    res.json(response);

  } catch (error) {
    logger.error('Error fetching player header', {
      playerId: req.params.id,
      error: error instanceof Error ? error.message : String(error),
    });
    next(error);
  }
});

// ===== HELPER FUNCTIONS =====

async function isPlayerLive(playerId: string): Promise<boolean> {
  try {
    const result = await query<{ is_player_live: boolean }>(
      'SELECT is_player_live($1) as is_player_live',
      [playerId]
    );
    return result[0]?.is_player_live || false;
  } catch (error) {
    logger.error('Failed to check player live status', {
      playerId,
      error: error instanceof Error ? error.message : String(error),
    });
    return false;
  }
}

function setCacheHeaders(res: Response, isLive: boolean): void {
  if (isLive) {
    res.set('Cache-Control', 'public, max-age=60, s-maxage=120');
  } else {
    res.set('Cache-Control', 'public, max-age=21600, s-maxage=43200');
  }
}

export default router;
