/**
 * BoxScoreStorage - Persistent storage for final box scores
 * 
 * Final box scores don't change, so we store them permanently
 * to avoid re-fetching and wasting API quota.
 * 
 * Storage backends:
 * 1. Redis (if available) - fast access
 * 2. JSON files (fallback) - survives restarts
 */

import * as fs from 'fs';
import * as path from 'path';
import { getRedisClient, isRedisAvailable } from './redis';
import { BoxScoreResponse } from '../types';
import { logger } from '../utils/logger';

const STORAGE_DIR = path.join(__dirname, '../../data/boxscores');
const REDIS_PREFIX = 'boxscore:permanent:';
const REDIS_TTL = 30 * 24 * 60 * 60; // 30 days in Redis (backup)

/**
 * Ensure storage directory exists
 */
function ensureStorageDir(): void {
  if (!fs.existsSync(STORAGE_DIR)) {
    fs.mkdirSync(STORAGE_DIR, { recursive: true });
  }
}

/**
 * Get file path for a game's box score
 */
function getFilePath(gameId: string): string {
  // Sanitize gameId for filesystem
  const safeId = gameId.replace(/[^a-zA-Z0-9_-]/g, '_');
  return path.join(STORAGE_DIR, `${safeId}.json`);
}

/**
 * Store a final box score permanently
 */
export async function storeBoxScore(gameId: string, boxScore: BoxScoreResponse): Promise<void> {
  // Only store final games
  if (boxScore.game.status !== 'final') {
    logger.debug('BoxScoreStorage: Skipping non-final game', { gameId, status: boxScore.game.status });
    return;
  }

  // Reject empty box scores (ESPN race condition protection)
  const league = gameId.split('_')[0];
  if ((league === 'nba' || league === 'ncaam') &&
      (boxScore.boxScore.homeTeam as any).starters?.length < 5) {
    logger.warn('BoxScoreStorage: Rejecting empty box score', { gameId });
    return;
  }

  const data = {
    ...boxScore,
    storedAt: new Date().toISOString(),
  };

  // Store in Redis if available
  if (isRedisAvailable()) {
    try {
      const client = getRedisClient();
      if (client) {
        await client.setEx(
          `${REDIS_PREFIX}${gameId}`,
          REDIS_TTL,
          JSON.stringify(data)
        );
        logger.debug('BoxScoreStorage: Stored in Redis', { gameId });
      }
    } catch (error) {
      logger.warn('BoxScoreStorage: Failed to store in Redis', { gameId, error });
    }
  }

  // Always store to file as permanent backup
  try {
    ensureStorageDir();
    const filePath = getFilePath(gameId);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    logger.debug('BoxScoreStorage: Stored to file', { gameId, filePath });
  } catch (error) {
    logger.error('BoxScoreStorage: Failed to store to file', { gameId, error });
  }
}

/**
 * Retrieve a stored box score
 */
export async function getStoredBoxScore(gameId: string): Promise<BoxScoreResponse | null> {
  // Try Redis first
  if (isRedisAvailable()) {
    try {
      const client = getRedisClient();
      if (client) {
        const data = await client.get(`${REDIS_PREFIX}${gameId}`);
        if (data) {
          logger.debug('BoxScoreStorage: Retrieved from Redis', { gameId });
          return JSON.parse(data);
        }
      }
    } catch (error) {
      logger.warn('BoxScoreStorage: Failed to retrieve from Redis', { gameId, error });
    }
  }

  // Try file storage
  try {
    const filePath = getFilePath(gameId);
    if (fs.existsSync(filePath)) {
      const data = fs.readFileSync(filePath, 'utf-8');
      logger.debug('BoxScoreStorage: Retrieved from file', { gameId });
      return JSON.parse(data);
    }
  } catch (error) {
    logger.warn('BoxScoreStorage: Failed to retrieve from file', { gameId, error });
  }

  return null;
}

/**
 * Check if a box score is already stored
 */
export async function hasStoredBoxScore(gameId: string): Promise<boolean> {
  // Check Redis first
  if (isRedisAvailable()) {
    try {
      const client = getRedisClient();
      if (client) {
        const exists = await client.exists(`${REDIS_PREFIX}${gameId}`);
        if (exists) return true;
      }
    } catch (error) {
      // Fall through to file check
    }
  }

  // Check file storage
  const filePath = getFilePath(gameId);
  return fs.existsSync(filePath);
}

/**
 * List all stored game IDs (for backfill tracking)
 */
export function listStoredGameIds(): string[] {
  try {
    ensureStorageDir();
    const files = fs.readdirSync(STORAGE_DIR);
    return files
      .filter(f => f.endsWith('.json'))
      .map(f => f.replace('.json', '').replace(/_/g, '_'));
  } catch (error) {
    logger.error('BoxScoreStorage: Failed to list stored games', { error });
    return [];
  }
}

/**
 * Get storage statistics
 */
export function getStorageStats(): {
  fileCount: number;
  totalSizeBytes: number;
} {
  try {
    ensureStorageDir();
    const files = fs.readdirSync(STORAGE_DIR);
    let totalSize = 0;
    
    for (const file of files) {
      if (file.endsWith('.json')) {
        const stat = fs.statSync(path.join(STORAGE_DIR, file));
        totalSize += stat.size;
      }
    }
    
    return {
      fileCount: files.filter(f => f.endsWith('.json')).length,
      totalSizeBytes: totalSize,
    };
  } catch (error) {
    return { fileCount: 0, totalSizeBytes: 0 };
  }
}
