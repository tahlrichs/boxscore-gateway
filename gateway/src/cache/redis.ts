import { createClient, RedisClientType } from 'redis';
import { config } from '../config';
import { logger } from '../utils/logger';

let redisClient: RedisClientType | null = null;
let redisAvailable = false;

export async function initializeRedis(): Promise<void> {
  if (redisClient) {
    return;
  }

  // Use a timeout to prevent hanging forever if Redis is down
  const connectWithTimeout = new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Redis connection timeout'));
    }, 3000); // 3 second timeout

    try {
      redisClient = createClient({
        url: config.redisUrl,
        socket: {
          connectTimeout: 5000,
          reconnectStrategy: false, // Disable auto-reconnect
          family: 6, // Use IPv6 for Railway's private networking
        },
      });

      redisClient.on('error', (err) => {
        clearTimeout(timeout);
        logger.error('Redis Client Error:', err);
        redisAvailable = false;
        reject(err);
      });

      redisClient.on('connect', () => {
        logger.info('Redis Client Connected');
        redisAvailable = true;
      });

      redisClient.connect()
        .then(() => {
          clearTimeout(timeout);
          redisAvailable = true;
          resolve();
        })
        .catch((err) => {
          clearTimeout(timeout);
          reject(err);
        });
    } catch (err) {
      clearTimeout(timeout);
      reject(err);
    }
  });

  try {
    await connectWithTimeout;
  } catch (error) {
    logger.warn('Redis not available, running without cache');
    redisAvailable = false;
    redisClient = null;
  }
}

export function isRedisAvailable(): boolean {
  return redisAvailable;
}

export function getRedisClient(): RedisClientType | null {
  return redisClient;
}

export async function closeRedis(): Promise<void> {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
}

// Cache operations
export async function getCached<T>(key: string): Promise<T | null> {
  if (!redisAvailable) {
    return null;
  }
  
  try {
    const client = getRedisClient();
    if (!client) return null;
    
    const data = await client.get(key);
    
    if (!data) {
      return null;
    }
    
    return JSON.parse(data) as T;
  } catch (error) {
    logger.error(`Cache get error for key ${key}:`, error);
    return null;
  }
}

export async function setCached<T>(
  key: string,
  value: T,
  ttlSeconds: number
): Promise<void> {
  if (!redisAvailable) {
    return;
  }
  
  try {
    const client = getRedisClient();
    if (!client) return;
    
    await client.setEx(key, ttlSeconds, JSON.stringify(value));
  } catch (error) {
    logger.error(`Cache set error for key ${key}:`, error);
  }
}

export async function deleteCached(key: string): Promise<void> {
  if (!redisAvailable) {
    return;
  }
  
  try {
    const client = getRedisClient();
    if (!client) return;
    
    await client.del(key);
  } catch (error) {
    logger.error(`Cache delete error for key ${key}:`, error);
  }
}

export async function clearCachePattern(pattern: string): Promise<void> {
  if (!redisAvailable) {
    return;
  }
  
  try {
    const client = getRedisClient();
    if (!client) return;
    
    const keys = await client.keys(pattern);
    
    if (keys.length > 0) {
      await client.del(keys);
      logger.info(`Cleared ${keys.length} cache keys matching pattern: ${pattern}`);
    }
  } catch (error) {
    logger.error(`Cache clear error for pattern ${pattern}:`, error);
  }
}

// Cache key generators
export const cacheKeys = {
  scoreboard: (league: string, date: string) => `scoreboard:${league}:${date}`,
  game: (gameId: string) => `game:${gameId}`,
  boxScore: (gameId: string) => `boxscore:${gameId}`,
  standings: (league: string, season: string) => `standings:${league}:${season}`,
  rankings: (league: string, pollType: string) => `rankings:${league}:${pollType}`,
  roster: (teamId: string) => `roster:${teamId}`,
  schedule: (league: string, startDate: string, endDate: string) =>
    `schedule:${league}:${startDate}:${endDate}`,
  health: () => 'health:status',
};
