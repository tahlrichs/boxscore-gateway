import { Router, Request, Response, NextFunction } from 'express';
import { getAdapterForLeague } from '../providers';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { getRequestDeduplicator } from '../cache/RequestDeduplicator';
import { getScoreboardTTL, getNoGamesTTL } from '../cache/CachePolicy';
import { config, leagueConfig, LeagueId } from '../config';
import { ScoreboardResponse, Game } from '../types';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import {
  getGameDateEntry,
  isDateInSeason,
  getGamesForDate,
  getSeasonForDate,
  getScheduleStore,
} from '../jobs';
import { validateLeague as validateLeagueMiddleware, validateDate as validateDateMiddleware, validateDateRange } from '../middleware/validation';

export const scoreboardRouter = Router();

/**
 * Check if we should skip the ESPN call based on game_dates index
 * Returns the response if we can skip, or null if we need to fetch
 */
async function checkGameDatesIndex(
  league: string,
  date: string,
  cacheKey: string
): Promise<{ skip: boolean; response?: ScoreboardResponse; reason?: string }> {
  // Check game_dates index
  const gameDateEntry = getGameDateEntry(league, date);
  
  if (gameDateEntry) {
    // We have data about this date
    if (gameDateEntry.gameCount === 0) {
      // Verified: no games on this date
      logger.debug(`GameDates: No games for ${league}/${date} (verified)`);
      return {
        skip: true,
        response: {
          league,
          date,
          lastUpdated: gameDateEntry.lastRefreshedAt.toISOString(),
          games: [],
        },
        reason: 'no-games-verified',
      };
    }
    
    // Games exist - check if we have fresh data
    // If game_dates says there are games, we might have them in the store
    const storedGames = getGamesForDate(league, date);
    if (storedGames.length > 0) {
      // We have game data - check freshness based on status
      const hasLiveGames = storedGames.some(g => g.status === 'live');
      const allFinal = storedGames.every(g => g.status === 'final');
      
      // For historical final games, we can use stored data without refresh
      const today = new Date().toISOString().split('T')[0];
      if (allFinal && date < today) {
        logger.debug(`GameDates: Using stored games for ${league}/${date} (all final, historical)`);
        // Return stored games transformed to API format
        return {
          skip: false, // Still go through normal flow to get full Game objects
          reason: 'games-exist-refresh-check',
        };
      }
    }
    
    // Games exist but may need refresh
    return { skip: false, reason: 'games-exist-refresh-needed' };
  }
  
  // No game_dates entry - check if date is in season
  const inSeason = isDateInSeason(league, date);
  
  if (!inSeason) {
    // Off-season date - return empty without ESPN call
    logger.debug(`GameDates: Off-season date ${league}/${date}`);
    return {
      skip: true,
      response: {
        league,
        date,
        lastUpdated: new Date().toISOString(),
        games: [],
      },
      reason: 'off-season',
    };
  }
  
  // In-season but unknown date - need to fetch from ESPN
  // This will happen for dates not yet synced
  logger.debug(`GameDates: Unknown in-season date ${league}/${date}, will fetch`);
  return { skip: false, reason: 'unknown-in-season' };
}

scoreboardRouter.get('/', validateLeagueMiddleware, validateDateMiddleware, validateDateRange(365, 365), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = (req.query.league as string).toLowerCase();
    const date = req.query.date as string;
    
    const cacheKey = cacheKeys.scoreboard(league, date);
    
    // Try Redis cache first
    const cached = await getCached<ScoreboardResponse>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for scoreboard: ${league}/${date}`);
      res.cacheHit = true;
      res.json({
        data: cached,
        meta: {
          requestId: req.requestId,
          provider: config.provider,
          cacheHit: true,
        },
      });
      return;
    }
    
    // Check game_dates index to potentially skip ESPN call
    const gameDatesCheck = await checkGameDatesIndex(league, date, cacheKey);
    
    if (gameDatesCheck.skip && gameDatesCheck.response) {
      // We can return early without calling ESPN
      logger.debug(`Skipped ESPN call for ${league}/${date}: ${gameDatesCheck.reason}`);
      
      // Cache the empty response with appropriate TTL
      const ttl = getNoGamesTTL(gameDatesCheck.reason || 'no-games');
      await setCached(cacheKey, gameDatesCheck.response, ttl);
      
      res.cacheHit = false;
      res.json({
        data: gameDatesCheck.response,
        meta: {
          requestId: req.requestId,
          provider: 'game_dates_index',
          cacheHit: false,
          skipReason: gameDatesCheck.reason,
        },
      });
      return;
    }
    
    // Need to fetch from provider
    const deduplicator = getRequestDeduplicator();
    const dedupeKey = `scoreboard:${league}:${date}`;
    
    logger.debug(`Cache miss for scoreboard: ${league}/${date}, reason: ${gameDatesCheck.reason}`);
    
    // Get the ESPN adapter for this league
    const adapter = getAdapterForLeague(league);
    const providerName = adapter.name;
    
    const games = await deduplicator.dedupe(dedupeKey, async () => {
      return adapter.fetchScoreboard(league, date);
    });
    
    const response: ScoreboardResponse = {
      league,
      date,
      lastUpdated: new Date().toISOString(),
      games,
    };
    
    // Use tiered TTL based on game status and date
    const ttl = getScoreboardTTL(games, date);
    
    // Cache the response
    await setCached(cacheKey, response, ttl);
    
    res.cacheHit = false;
    res.json({
      data: response,
      meta: {
        requestId: req.requestId,
        provider: providerName,
        cacheHit: false,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /v1/scoreboard/dates?league=nba
 *
 * Returns list of dates that have games for the specified league
 * Only includes dates where games are actually scheduled
 */
scoreboardRouter.get('/dates', validateLeagueMiddleware, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = (req.query.league as string).toLowerCase();

    const cacheKey = `scoreboard:dates:${league}:v3`;

    // Try cache first (1 hour TTL)
    const cached = await getCached<string[]>(cacheKey);
    if (cached) {
      res.json({
        data: cached,
        meta: {
          requestId: req.requestId,
          cacheHit: true,
        },
      });
      return;
    }

    // Get all game dates from the schedule store
    const store = getScheduleStore();
    const allGameDates = store.getAllGameDates();

    // Filter to only this league and dates with games
    const datesWithGames = allGameDates
      .filter(gd => gd.leagueId === league && gd.gameCount > 0)
      .map(gd => gd.scoreboardDate)
      .sort();

    // If we have game dates from the store, use those
    // Otherwise fall back to generating season dates (for leagues not yet synced)
    let dates: string[];

    if (datesWithGames.length > 0) {
      dates = datesWithGames;
    } else {
      // Fallback: get season range and generate dates
      const today = new Date();
      const todayStr = today.toISOString().split('T')[0];
      const season = getSeasonForDate(league, todayStr);

      dates = [];
      if (season) {
        const seasonStart = new Date(season.preseasonStart || season.startDate);
        const seasonEnd = new Date(season.postseasonEnd || season.endDate);
        const endDate = new Date(Math.max(
          seasonEnd.getTime(),
          today.getTime() + 14 * 24 * 60 * 60 * 1000
        ));

        let currentDate = new Date(seasonStart);
        while (currentDate <= endDate) {
          dates.push(currentDate.toISOString().split('T')[0]);
          currentDate.setDate(currentDate.getDate() + 1);
        }
      } else {
        // Last resort fallback
        for (let i = -120; i <= 60; i++) {
          const date = new Date(today);
          date.setDate(date.getDate() + i);
          dates.push(date.toISOString().split('T')[0]);
        }
      }
    }

    // Cache for 1 hour
    await setCached(cacheKey, dates, 60 * 60);

    res.json({
      data: dates,
      meta: {
        requestId: req.requestId,
        cacheHit: false,
        fromGameDates: datesWithGames.length > 0,
        totalDates: dates.length,
      },
    });
  } catch (error) {
    next(error);
  }
});
