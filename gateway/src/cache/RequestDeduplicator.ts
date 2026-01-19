/**
 * RequestDeduplicator - Prevents duplicate API calls for the same resource
 * 
 * When multiple users request the same game/scoreboard within a short window,
 * coalesce them into a single API call and share the result.
 */

import { logger } from '../utils/logger';

interface PendingRequest<T> {
  promise: Promise<T>;
  createdAt: number;
}

// Maximum age of a pending request before we allow a new one (ms)
// Set to 30 seconds to ensure concurrent requests within the dedupe window
// are coalesced into a single upstream API call
const MAX_PENDING_AGE_MS = 30000; // 30 seconds

export class RequestDeduplicator {
  private pending: Map<string, PendingRequest<unknown>> = new Map();

  /**
   * Execute a request with deduplication
   * 
   * If a request for the same key is already in flight, return its promise.
   * Otherwise, execute the fetcher and cache its promise briefly.
   * 
   * @param key - Unique identifier for this request (e.g., "scoreboard:nba:2026-01-12")
   * @param fetcher - Function that performs the actual API call
   * @returns Promise resolving to the fetched data
   */
  async dedupe<T>(key: string, fetcher: () => Promise<T>): Promise<T> {
    // Check for existing pending request
    const existing = this.pending.get(key);
    if (existing && (Date.now() - existing.createdAt) < MAX_PENDING_AGE_MS) {
      logger.debug('RequestDeduplicator: Reusing pending request', { key });
      return existing.promise as Promise<T>;
    }

    // Create new request
    logger.debug('RequestDeduplicator: Creating new request', { key });
    
    const promise = fetcher().finally(() => {
      // Clean up after request completes (with small delay for late joiners)
      setTimeout(() => {
        const current = this.pending.get(key);
        if (current && current.promise === promise) {
          this.pending.delete(key);
        }
      }, 100);
    });

    this.pending.set(key, {
      promise,
      createdAt: Date.now(),
    });

    return promise;
  }

  /**
   * Check if a request is currently pending
   */
  isPending(key: string): boolean {
    const existing = this.pending.get(key);
    return !!existing && (Date.now() - existing.createdAt) < MAX_PENDING_AGE_MS;
  }

  /**
   * Clear all pending requests (for testing)
   */
  clear(): void {
    this.pending.clear();
  }

  /**
   * Get count of pending requests (for monitoring)
   */
  getPendingCount(): number {
    return this.pending.size;
  }
}

// Singleton instance
let deduplicatorInstance: RequestDeduplicator | null = null;

export function getRequestDeduplicator(): RequestDeduplicator {
  if (!deduplicatorInstance) {
    deduplicatorInstance = new RequestDeduplicator();
  }
  return deduplicatorInstance;
}

export function resetRequestDeduplicator(): void {
  deduplicatorInstance = null;
}
