import { Router, Request, Response } from 'express';
import { getProviderAdapter } from '../providers';
import { getRedisClient } from '../cache/redis';
import { HealthResponse } from '../types';
import { logger } from '../utils/logger';

export const healthRouter = Router();

healthRouter.get('/', async (_req: Request, res: Response) => {
  try {
    const provider = getProviderAdapter();
    
    // Check provider health
    const providerStatus = await provider.healthCheck();
    
    // Check Redis health
    let cacheConnected = false;
    try {
      const client = getRedisClient();
      if (client) {
        await client.ping();
        cacheConnected = true;
      }
    } catch {
      logger.warn('Redis health check failed');
    }
    
    // Determine overall status
    let overallStatus: HealthResponse['status'] = 'healthy';
    if (!cacheConnected || providerStatus.status === 'unhealthy') {
      overallStatus = 'unhealthy';
    } else if (providerStatus.status === 'degraded') {
      overallStatus = 'degraded';
    }
    
    const response: HealthResponse = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      providers: [providerStatus],
      cache: {
        connected: cacheConnected,
      },
    };
    
    const statusCode = overallStatus === 'healthy' ? 200 : 
                       overallStatus === 'degraded' ? 200 : 503;
    
    res.status(statusCode).json(response);
  } catch (error) {
    logger.error('Health check failed:', error);
    
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      providers: [],
      cache: { connected: false },
    });
  }
});
