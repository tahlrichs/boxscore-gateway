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
  getHistoricalSeasons,
} from '../db/repositories/playerRepository';
import { query } from '../db/pool';
import { getPlayerStats, getStatCentralFromESPN, ESPNPlayerProfile } from '../providers/espnPlayerService';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { StatCentralResponse, StatCentralPlayer, SeasonRow, seasonLabel } from '../types/statCentral';

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
 * GET /v1/players/:id/stat-central
 *
 * Returns everything needed for the Stat Central tab:
 * - Player bio (from DB)
 * - All historical seasons (from Supabase) + current season (from ESPN)
 * - Career averages (from ESPN)
 *
 * Cached in Redis for 5 minutes.
 */
router.get('/:id/stat-central', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const playerId = req.params.id as string;

    // Validate player ID is a UUID
    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!playerId || !UUID_RE.test(playerId)) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Invalid player ID format',
      });
      return;
    }

    // Check Redis cache
    const cacheKey = cacheKeys.playerStatCentral(playerId);
    const cached = await getCached<StatCentralResponse>(cacheKey);
    if (cached) {
      res.set('Cache-Control', 'public, max-age=300');
      res.json(cached);
      return;
    }

    // Fetch in parallel: player bio, historical seasons from DB, current data from ESPN
    const [player, historicalSeasons, espnData] = await Promise.all([
      getPlayerById(playerId),
      getHistoricalSeasons(playerId),
      getStatCentralFromESPN(playerId),
    ]);

    if (!player) {
      res.status(404).json({
        error: 'Not Found',
        message: `Player not found: ${playerId}`,
      });
      return;
    }

    // Build player bio
    const currentSeason = getCurrentSeason();
    const statCentralPlayer: StatCentralPlayer = {
      id: player.id,
      displayName: player.display_name,
      jersey: espnData?.profile.jersey || player.jersey || '',
      position: espnData?.profile.position || player.position || '',
      teamName: espnData?.profile.team?.name || '',
      teamAbbreviation: espnData?.profile.team?.abbreviation || '',
      headshot: espnData?.profile.headshot || player.headshot_url || null,
      college: espnData?.profile.college || player.school || null,
      hometown: player.hometown || null,
      draftSummary: buildDraftSummary(espnData?.profile),
    };

    // Build season rows: merge historical (Supabase) + current (ESPN)
    const seasons: SeasonRow[] = [];

    // Add historical seasons from Supabase (completed seasons only)
    for (const hs of historicalSeasons) {
      if (hs.season >= currentSeason) continue; // skip current season from DB, ESPN has fresher data
      seasons.push({
        seasonLabel: seasonLabel(hs.season),
        teamAbbreviation: !hs.team_id || hs.team_id === 'TOTAL' ? null : hs.team_id,
        gamesPlayed: hs.games_played || 0,
        ppg: round1(hs.ppg),
        rpg: round1(hs.rpg),
        apg: round1(hs.apg),
        spg: round1(hs.games_played && hs.stl ? hs.stl / hs.games_played : 0),
        fgPct: round1((hs.fg_pct || 0) * 100), // DB stores 0-1, API returns 0-100
        ftPct: round1((hs.ft_pct || 0) * 100),
      });
    }

    // Add current season + any ESPN seasons not in Supabase
    if (espnData) {
      for (const es of espnData.seasons) {
        // Check if this season is already covered by Supabase data
        const alreadyInDb = historicalSeasons.some(
          hs => hs.season === es.season && hs.season < currentSeason
        );
        if (alreadyInDb) continue;

        seasons.push({
          seasonLabel: seasonLabel(es.season),
          teamAbbreviation: es.teamAbbreviation || null,
          gamesPlayed: es.gamesPlayed,
          ppg: round1(es.ppg),
          rpg: round1(es.rpg),
          apg: round1(es.apg),
          spg: round1(es.spg),
          fgPct: round1(es.fgPct),
          ftPct: round1(es.ftPct),
        });
      }
    }

    // Sort descending by season label
    seasons.sort((a, b) => b.seasonLabel.localeCompare(a.seasonLabel));

    // Career row
    let career: SeasonRow;
    if (espnData?.career) {
      career = {
        seasonLabel: 'Career',
        teamAbbreviation: null,
        gamesPlayed: espnData.career.gamesPlayed,
        ppg: round1(espnData.career.ppg),
        rpg: round1(espnData.career.rpg),
        apg: round1(espnData.career.apg),
        spg: round1(espnData.career.spg),
        fgPct: round1(espnData.career.fgPct),
        ftPct: round1(espnData.career.ftPct),
      };
    } else {
      // Fallback: compute from available seasons (TOTAL rows only)
      career = computeCareerFromSeasons(seasons);
    }

    const response: StatCentralResponse = {
      data: {
        player: statCentralPlayer,
        seasons,
        career,
      },
      meta: {
        lastUpdated: new Date().toISOString(),
      },
    };

    // Cache for 5 minutes
    await setCached(cacheKey, response, 300);

    res.set('Cache-Control', 'public, max-age=300');
    res.json(response);
  } catch (error) {
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

// ===== STAT CENTRAL HELPERS =====

/**
 * Round a number to 1 decimal place
 */
function round1(val: number | undefined | null): number {
  if (val === undefined || val === null || isNaN(val)) return 0;
  return Math.round(val * 10) / 10;
}

/**
 * Build draft summary string from ESPN profile data.
 * Returns "2020 · Round 1 · Pick 21" or null if undrafted/unknown.
 */
function buildDraftSummary(profile: ESPNPlayerProfile | undefined | null): string | null {
  if (!profile) return null;

  // ESPN athlete endpoint includes draft info
  const draft = profile.draft;
  if (!draft) return null;

  const year = draft.year;
  const round = draft.round;
  const pick = draft.selection;

  if (!year) return null;
  if (!round && !pick) return `${year}`;
  if (round && pick) return `${year} · Round ${round} · Pick ${pick}`;
  if (round) return `${year} · Round ${round}`;
  return `${year}`;
}

/**
 * Compute career averages from season rows when ESPN doesn't provide them.
 * Simple weighted average by games played.
 */
function computeCareerFromSeasons(seasons: SeasonRow[]): SeasonRow {
  // Only use TOTAL rows (teamAbbreviation === null) to avoid double-counting traded players
  const totalRows = seasons.filter(s => s.teamAbbreviation === null);
  const rows = totalRows.length > 0 ? totalRows : seasons;

  const totalGP = rows.reduce((sum, s) => sum + s.gamesPlayed, 0);

  if (totalGP === 0) {
    return {
      seasonLabel: 'Career',
      teamAbbreviation: null,
      gamesPlayed: 0,
      ppg: 0, rpg: 0, apg: 0, spg: 0, fgPct: 0, ftPct: 0,
    };
  }

  const weightedAvg = (field: keyof SeasonRow) =>
    round1(rows.reduce((sum, s) => sum + (s[field] as number) * s.gamesPlayed, 0) / totalGP);

  return {
    seasonLabel: 'Career',
    teamAbbreviation: null,
    gamesPlayed: totalGP,
    ppg: weightedAvg('ppg'),
    rpg: weightedAvg('rpg'),
    apg: weightedAvg('apg'),
    spg: weightedAvg('spg'),
    fgPct: weightedAvg('fgPct'),
    ftPct: weightedAvg('ftPct'),
  };
}

export default router;
