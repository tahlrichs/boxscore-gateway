import { Router, Request, Response, NextFunction } from 'express';
import { ESPNAdapter } from '../providers/espnAdapter';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { config } from '../config';
import { RankingsResponse } from '../types';
import { BadRequestError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { validateLeague } from '../middleware/validation';

export const rankingsRouter = Router();

/**
 * GET /v1/rankings
 * Get AP Top 25 or Coaches Poll rankings for college sports
 *
 * Query params:
 * - league: ncaam, ncaaf (required)
 * - poll: ap, coaches (optional, default: ap)
 */
rankingsRouter.get('/', validateLeague, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = (req.query.league as string).toLowerCase();
    const pollType = ((req.query.poll as string) || 'ap').toLowerCase() as 'ap' | 'coaches';

    // Only college sports have rankings
    if (!league.startsWith('ncaa')) {
      throw new BadRequestError('Rankings are only available for college sports (ncaam, ncaaf)');
    }

    // Validate poll type
    if (pollType !== 'ap' && pollType !== 'coaches') {
      throw new BadRequestError('Invalid poll type. Use "ap" or "coaches"');
    }

    const cacheKey = cacheKeys.rankings(league, pollType);

    // Try cache first
    const cached = await getCached<RankingsResponse>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for rankings: ${league}/${pollType}`);
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
    logger.debug(`Cache miss for rankings: ${league}/${pollType}`);
    const adapter = new ESPNAdapter();
    const rankings = await adapter.fetchRankings(league, pollType);

    // Cache the response
    await setCached(cacheKey, rankings, config.cacheTtl.rankings);

    res.cacheHit = false;
    res.json({
      data: rankings,
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
