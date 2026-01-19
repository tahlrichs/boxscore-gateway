import { Router, Request, Response, NextFunction } from 'express';
import { getProviderAdapter } from '../providers';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { config } from '../config';
import { RosterResponse } from '../types';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { validateTeamId } from '../middleware/validation';

export const teamsRouter = Router();

// Get team roster
teamsRouter.get('/:id/roster', validateTeamId, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    
    const cacheKey = cacheKeys.roster(id);
    
    // Try cache first
    const cached = await getCached<RosterResponse>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for roster: ${id}`);
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
    logger.debug(`Cache miss for roster: ${id}`);
    const provider = getProviderAdapter();
    const roster = await provider.fetchRoster(id);
    
    if (!roster) {
      throw new NotFoundError(`Roster for team '${id}' not found`);
    }
    
    // Cache the response
    await setCached(cacheKey, roster, config.cacheTtl.roster);
    
    res.cacheHit = false;
    res.json({
      data: roster,
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
