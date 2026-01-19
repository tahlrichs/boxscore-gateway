import { Router, Request, Response, NextFunction } from 'express';
import { getAdapterForGame, isNBAGame } from '../providers';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { getRequestDeduplicator } from '../cache/RequestDeduplicator';
import { getStoredBoxScore, storeBoxScore } from '../cache/BoxScoreStorage';
import { getBoxScoreTTL } from '../cache/CachePolicy';
import { config } from '../config';
import { Game, BoxScoreResponse } from '../types';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { validateGameId } from '../middleware/validation';
import { enrichBoxScoreWithPlayerIds } from '../utils/enrichBoxScore';

export const gamesRouter = Router();

/**
 * Get single game details
 *
 * NOTE: Per migration plan, prefer using scoreboard data for game status.
 * This endpoint exists for direct game lookups but scoreboard is more efficient.
 */
gamesRouter.get('/:id', validateGameId, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    
    const cacheKey = cacheKeys.game(id);
    
    // Try cache first
    const cached = await getCached<Game>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for game: ${id}`);
      res.cacheHit = true;
      res.json({
        data: { game: cached },
        meta: {
          requestId: req.requestId,
          provider: isNBAGame(id) ? 'espn' : config.provider,
          cacheHit: true,
        },
      });
      return;
    }
    
    // Use deduplication for API calls
    const deduplicator = getRequestDeduplicator();
    logger.debug(`Cache miss for game: ${id}`);
    
    // Get ESPN adapter for this game
    const adapter = getAdapterForGame(id);
    const providerName = adapter.name;
    
    const game = await deduplicator.dedupe(`game:${id}`, async () => {
      return adapter.fetchGame(id);
    });
    
    if (!game) {
      throw new NotFoundError(`Game '${id}' not found`);
    }
    
    // Determine TTL based on game status
    const ttl = game.status === 'live' ? config.cacheTtl.liveGame : config.cacheTtl.boxScore;
    
    // Cache the response
    await setCached(cacheKey, game, ttl);
    
    res.cacheHit = false;
    res.json({
      data: { game, lastUpdated: new Date().toISOString() },
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
 * Get box score for a game
 *
 * Uses three-tier lookup:
 * 1. Permanent storage (for final games)
 * 2. Redis cache (for recent/live games)
 * 3. API fetch (with quota tracking and per-game cooldown)
 */
gamesRouter.get('/:id/boxscore', validateGameId, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    const sport = String(req.query.sport || 'nba');
    
    // 1. Check permanent storage first (final games)
    let storedBoxScore = await getStoredBoxScore(id);
    if (storedBoxScore) {
      logger.debug(`Permanent storage hit for box score: ${id}`);

      // Enrich with player IDs
      const leaguePrefix = id.split('_')[0];
      storedBoxScore.boxScore = await enrichBoxScoreWithPlayerIds(
        storedBoxScore.boxScore,
        leaguePrefix
      );

      res.cacheHit = true;
      res.json({
        data: storedBoxScore,
        meta: {
          requestId: req.requestId,
          provider: isNBAGame(id) ? 'espn' : config.provider,
          cacheHit: true,
          storageType: 'permanent',
        },
      });
      return;
    }
    
    // 2. Check Redis cache
    const cacheKey = cacheKeys.boxScore(id);
    let cached = await getCached<BoxScoreResponse>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for box score: ${id}`);

      // Enrich with player IDs
      const leaguePrefix = id.split('_')[0];
      cached.boxScore = await enrichBoxScoreWithPlayerIds(
        cached.boxScore,
        leaguePrefix
      );

      res.cacheHit = true;
      res.json({
        data: cached,
        meta: {
          requestId: req.requestId,
          provider: isNBAGame(id) ? 'espn' : config.provider,
          cacheHit: true,
          storageType: 'cache',
        },
      });
      return;
    }
    
    // 3. Fetch from provider with deduplication
    const deduplicator = getRequestDeduplicator();
    logger.debug(`Cache miss for box score: ${id}`);
    
    // Get ESPN adapter for this game
    const adapter = getAdapterForGame(id);
    const providerName = adapter.name;
    
    const boxScoreResponse = await deduplicator.dedupe(`boxscore:${id}`, async () => {
      return adapter.fetchBoxScore(id, sport);
    });

    if (!boxScoreResponse) {
      throw new NotFoundError(`Box score for game '${id}' not found`);
    }

    // Enrich box score with internal player IDs
    const leaguePrefix = id.split('_')[0];
    boxScoreResponse.boxScore = await enrichBoxScoreWithPlayerIds(
      boxScoreResponse.boxScore,
      leaguePrefix
    );

    // Store permanently if final game
    if (boxScoreResponse.game.status === 'final') {
      await storeBoxScore(id, boxScoreResponse);
    }
    
    // Cache in Redis with appropriate TTL
    const ttl = getBoxScoreTTL(boxScoreResponse);
    await setCached(cacheKey, boxScoreResponse, ttl);
    
    res.cacheHit = false;
    res.json({
      data: boxScoreResponse,
      meta: {
        requestId: req.requestId,
        provider: providerName,
        cacheHit: false,
        storageType: 'api',
      },
    });
  } catch (error) {
    next(error);
  }
});
