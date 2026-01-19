/**
 * Player API Routes
 *
 * Progressive loading endpoints for player pages:
 * 1. Header endpoint - Fast bio + current season headline stats
 * 2. Game log endpoint - Current season game-by-game performance
 * 3. Splits endpoint - Common splits (home/away, last N, by month)
 * 4. Career endpoint - Historical season-by-season summaries
 */

import { Router, Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import {
  getPlayerById,
  searchPlayers,
} from '../db/repositories/playerRepository';
import { query } from '../db/pool';
import { getPlayerStats } from '../providers/espnPlayerService';

const router = Router();

/**
 * GET /v1/players/search
 *
 * Player search endpoint - Search players by name
 * Query params:
 *   - q: Search query (required)
 *   - sport: Filter by sport (optional, e.g., 'nba', 'nfl')
 *   - limit: Max results (optional, default 20)
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

    // Long cache for search results (1 hour)
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
 * GET /v1/players/:id
 *
 * Player header endpoint - Bio + current season stats fetched from ESPN on-demand
 * Returns: Bio, current team, position, current season PPG/RPG/APG
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const playerId = req.params.id as string;

    logger.debug('Fetching player header', { playerId });

    const player = await getPlayerById(playerId);

    if (!player) {
      res.status(404).json({
        error: 'Not Found',
        message: `Player not found: ${playerId}`,
      });
      return;
    }

    // Fetch stats directly from ESPN (on-demand, no local computation)
    const espnStats = await getPlayerStats(playerId);

    // Check if player is in "live window" for cache TTL
    const isLive = await isPlayerLive(playerId);
    const currentSeason = getCurrentSeason();

    // Return header data with ESPN stats
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
        // ESPN returns percentages as 0-100, iOS expects 0-1 (decimal)
        fgPct: espnStats.currentSeasonStats.fgPct / 100,
        fg3Pct: espnStats.currentSeasonStats.fg3Pct / 100,
        ftPct: espnStats.currentSeasonStats.ftPct / 100,
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
        source: 'espn',
        lastUpdated: player.updated_at,
      },
    };

    // Set cache headers based on live status
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

/**
 * GET /v1/players/:id/season/:season/summary
 *
 * Season summary endpoint - Full season stats
 * Note: Current season stats are available via GET /v1/players/:id
 * Historical seasons require ESPN historical data endpoint (not yet implemented)
 */
router.get('/:id/season/:season/summary', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const playerId = req.params.id as string;
    const season = parseInt(req.params.season as string, 10);
    const currentSeason = getCurrentSeason();

    if (isNaN(season)) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Invalid season parameter',
      });
      return;
    }

    // For current season, redirect to main player endpoint which has ESPN stats
    if (season === currentSeason) {
      res.redirect(307, `/v1/players/${playerId}`);
      return;
    }

    // Historical seasons not yet implemented with ESPN
    res.status(501).json({
      error: 'Not Implemented',
      message: 'Historical season stats are fetched from ESPN on-demand. Use GET /v1/players/:id for current season.',
    });

  } catch (error) {
    logger.error('Error fetching season summary', {
      playerId: req.params.id,
      season: req.params.season,
      error: error instanceof Error ? error.message : String(error),
    });
    next(error);
  }
});

/**
 * GET /v1/players/:id/season/:season/gamelog
 *
 * Game log endpoint - Game-by-game performance
 * Note: Game logs are available via ESPN game box scores.
 * This endpoint is not implemented - use box score endpoints instead.
 */
router.get('/:id/season/:season/gamelog', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const season = parseInt(req.params.season as string, 10);

    if (isNaN(season)) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Invalid season parameter',
      });
      return;
    }

    // Game logs are fetched from ESPN box scores on-demand
    // Individual game stats are available via /games/:id/boxscore
    res.status(501).json({
      error: 'Not Implemented',
      message: 'Game logs are available via individual box scores. Use GET /games/:id/boxscore for game stats.',
    });

  } catch (error) {
    logger.error('Error fetching game log', {
      playerId: req.params.id,
      season: req.params.season,
      error: error instanceof Error ? error.message : String(error),
    });
    next(error);
  }
});

/**
 * GET /v1/players/:id/season/:season/splits
 *
 * Splits endpoint - Common splits (home/away, last N, by month)
 * Note: Splits data requires local computation from game logs.
 * This endpoint is not implemented with ESPN on-demand fetching.
 */
router.get('/:id/season/:season/splits', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const season = parseInt(req.params.season as string, 10);

    if (isNaN(season)) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Invalid season parameter',
      });
      return;
    }

    // Splits require local computation which we're not doing
    res.status(501).json({
      error: 'Not Implemented',
      message: 'Splits data is not available. Current season averages available via GET /v1/players/:id.',
    });

  } catch (error) {
    logger.error('Error fetching splits', {
      playerId: req.params.id,
      season: req.params.season,
      error: error instanceof Error ? error.message : String(error),
    });
    next(error);
  }
});

/**
 * GET /v1/players/:id/career/summary
 *
 * Career endpoint - Historical season-by-season summaries
 * Note: Career stats require historical data from ESPN.
 * This endpoint is not implemented - current season available via GET /v1/players/:id.
 */
router.get('/:id/career/summary', async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Career summaries require historical ESPN data
    res.status(501).json({
      error: 'Not Implemented',
      message: 'Career summaries are not available. Current season stats available via GET /v1/players/:id.',
    });

  } catch (error) {
    logger.error('Error fetching career summary', {
      playerId: req.params.id,
      error: error instanceof Error ? error.message : String(error),
    });
    next(error);
  }
});

// ===== HELPER FUNCTIONS =====

/**
 * Get current NBA season based on current date
 */
function getCurrentSeason(): number {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth(); // 0-indexed

  // October-December = current year's season
  // January-September = previous year's season
  return month >= 9 ? year : year - 1;
}

/**
 * Check if a player is in "live window" for cache TTL
 */
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


/**
 * Set cache headers based on live status
 * Live window: 60-120s cache
 * Non-live: 6-12 hours cache
 */
function setCacheHeaders(res: Response, isLive: boolean): void {
  if (isLive) {
    // Live window: short TTL (60-120s)
    res.set('Cache-Control', 'public, max-age=60, s-maxage=120');
  } else {
    // Non-live: long TTL (6-12 hours)
    res.set('Cache-Control', 'public, max-age=21600, s-maxage=43200'); // 6h/12h
  }
}

export default router;
