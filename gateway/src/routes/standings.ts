import { Router, Request, Response, NextFunction } from 'express';
import { getProviderAdapter } from '../providers';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { config } from '../config';
import { StandingsResponse } from '../types';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { validateLeague, validateSeason } from '../middleware/validation';

export const standingsRouter = Router();

standingsRouter.get('/', validateLeague, validateSeason(false), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = (req.query.league as string).toLowerCase();
    const season = req.query.season as string || 'current';
    
    const cacheKey = cacheKeys.standings(league, season);
    
    // Try cache first
    const cached = await getCached<StandingsResponse>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for standings: ${league}/${season}`);
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
    
    // Fetch from provider
    logger.debug(`Cache miss for standings: ${league}/${season}`);
    const provider = getProviderAdapter();
    const standings = await provider.fetchStandings(league, season !== 'current' ? season : undefined);
    
    // Cache the response
    await setCached(cacheKey, standings, config.cacheTtl.standings);
    
    res.cacheHit = false;
    res.json({
      data: standings,
      meta: {
        requestId: req.requestId,
        provider: config.provider,
        cacheHit: false,
      },
    });
  } catch (error) {
    next(error);
  }
});
