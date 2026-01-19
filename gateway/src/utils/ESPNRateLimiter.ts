/**
 * ESPNRateLimiter - Rate limiting for ESPN API requests
 *
 * Implements two-layer throttling:
 * 1. Token bucket (per-minute): 60 requests/min with burst allowance
 * 2. Daily budget: 2,000 soft cap, 2,200 hard cap
 *
 * Also includes adaptive backoff for error responses (429, 403, 5xx, timeouts)
 */

import { logger } from './logger';

// Configuration constants
const TOKEN_BUCKET_CAPACITY = 60; // 60 requests/minute max
const TOKEN_REFILL_RATE = 1; // 1 token per second
const TOKEN_REFILL_INTERVAL_MS = 1000; // Refill every second
const DAILY_SOFT_CAP = 2000;
const DAILY_HARD_CAP = 2200;
const WARNING_THRESHOLD = 1800;

// Budget bucket types
export type ESPNBudgetBucket = 'scoreboard' | 'gameSummary' | 'standings' | 'schedule' | 'reserve';

// Bucket allocations
const BUCKET_CONFIG: Record<ESPNBudgetBucket, { dailyLimit: number; isProtected: boolean }> = {
  scoreboard: { dailyLimit: 300, isProtected: true },
  gameSummary: { dailyLimit: 600, isProtected: true },
  standings: { dailyLimit: 1, isProtected: true },
  schedule: { dailyLimit: 0, isProtected: false },
  reserve: { dailyLimit: 1099, isProtected: false },
};

// Backoff configuration
const BACKOFF_CONFIG = {
  initial: {
    429: 30000, // 30 seconds
    403: 60000, // 60 seconds
    timeout: 15000, // 15 seconds
    '5xx': 30000, // 30 seconds
    consecutive: 60000, // 60 seconds for 3+ errors
  } as Record<string | number, number>,
  max: {
    429: 300000, // 5 minutes
    403: 600000, // 10 minutes
    timeout: 120000, // 2 minutes
    '5xx': 300000, // 5 minutes
    consecutive: 600000, // 10 minutes
  } as Record<string | number, number>,
  consecutiveErrorThreshold: 3,
  successesToHalveBackoff: 5,
  fullResetAfterMs: 600000, // 10 minutes of no errors
};

interface RateLimiterState {
  tokens: number;
  lastRefillTime: number;
  dailyUsed: number;
  lastResetDate: string;
  bucketUsage: Record<ESPNBudgetBucket, number>;
  backoffUntil: number | null;
  consecutiveErrors: number;
  currentBackoffMs: number;
}

interface CanMakeRequestResult {
  allowed: boolean;
  reason?: string;
  retryAfterMs?: number;
}

export class ESPNRateLimiter {
  private state: RateLimiterState;
  private consecutiveSuccesses = 0;
  private lastErrorTime: number | null = null;

  constructor() {
    this.state = this.getInitialState();
    this.checkAndResetIfNewDay();
  }

  private getInitialState(): RateLimiterState {
    return {
      tokens: TOKEN_BUCKET_CAPACITY,
      lastRefillTime: Date.now(),
      dailyUsed: 0,
      lastResetDate: this.getTodayUTC(),
      bucketUsage: {
        scoreboard: 0,
        gameSummary: 0,
        standings: 0,
        schedule: 0,
        reserve: 0,
      },
      backoffUntil: null,
      consecutiveErrors: 0,
      currentBackoffMs: 0,
    };
  }

  private getTodayUTC(): string {
    return new Date().toISOString().split('T')[0];
  }

  private refillTokens(): void {
    const now = Date.now();
    const elapsed = now - this.state.lastRefillTime;
    const tokensToAdd = Math.floor(elapsed / TOKEN_REFILL_INTERVAL_MS) * TOKEN_REFILL_RATE;

    if (tokensToAdd > 0) {
      this.state.tokens = Math.min(TOKEN_BUCKET_CAPACITY, this.state.tokens + tokensToAdd);
      this.state.lastRefillTime = now - (elapsed % TOKEN_REFILL_INTERVAL_MS);
    }
  }

  private checkAndResetIfNewDay(): void {
    const today = this.getTodayUTC();
    if (this.state.lastResetDate !== today) {
      logger.info('ESPNRateLimiter: New UTC day detected, resetting daily quota', {
        previousDay: this.state.lastResetDate,
        newDay: today,
        previousUsage: this.state.dailyUsed,
      });
      this.resetDaily();
    }
  }

  private resetDaily(): void {
    const previousUsage = this.state.dailyUsed;
    this.state.dailyUsed = 0;
    this.state.lastResetDate = this.getTodayUTC();
    this.state.bucketUsage = {
      scoreboard: 0,
      gameSummary: 0,
      standings: 0,
      schedule: 0,
      reserve: 0,
    };

    logger.info('ESPNRateLimiter: Daily quota reset', {
      previousUsage,
      newSoftCap: DAILY_SOFT_CAP,
    });
  }

  private checkBackoffExpiry(): void {
    if (this.state.backoffUntil && Date.now() >= this.state.backoffUntil) {
      logger.info('ESPNRateLimiter: Backoff period expired');
      this.state.backoffUntil = null;
    }

    if (this.lastErrorTime && (Date.now() - this.lastErrorTime) > BACKOFF_CONFIG.fullResetAfterMs) {
      this.state.consecutiveErrors = 0;
      this.state.currentBackoffMs = 0;
      this.lastErrorTime = null;
      logger.debug('ESPNRateLimiter: Error state fully reset after quiet period');
    }
  }

  canMakeRequest(bucket: ESPNBudgetBucket): CanMakeRequestResult {
    this.checkAndResetIfNewDay();
    this.refillTokens();
    this.checkBackoffExpiry();

    // 1. Check adaptive backoff
    if (this.state.backoffUntil) {
      const retryAfterMs = this.state.backoffUntil - Date.now();
      if (retryAfterMs > 0) {
        return {
          allowed: false,
          reason: 'Adaptive backoff active due to upstream errors',
          retryAfterMs,
        };
      }
    }

    // 2. Check token bucket (per-minute rate)
    if (this.state.tokens < 1) {
      const msUntilNextToken = TOKEN_REFILL_INTERVAL_MS - (Date.now() - this.state.lastRefillTime);
      return {
        allowed: false,
        reason: 'Per-minute rate limit exhausted (60/min)',
        retryAfterMs: Math.max(msUntilNextToken, 100),
      };
    }

    // 3. Check daily hard cap
    if (this.state.dailyUsed >= DAILY_HARD_CAP) {
      return {
        allowed: false,
        reason: `Daily hard cap exhausted (${DAILY_HARD_CAP}/day)`,
      };
    }

    // 4. Check bucket-specific limit
    const bucketConfig = BUCKET_CONFIG[bucket];
    if (this.state.bucketUsage[bucket] >= bucketConfig.dailyLimit) {
      return {
        allowed: false,
        reason: `Bucket '${bucket}' daily limit (${bucketConfig.dailyLimit}) exhausted`,
      };
    }

    // 5. Check daily soft cap (with warning)
    if (this.state.dailyUsed >= DAILY_SOFT_CAP && !bucketConfig.isProtected) {
      return {
        allowed: false,
        reason: `Daily soft cap reached (${DAILY_SOFT_CAP}), non-protected bucket '${bucket}' blocked`,
      };
    }

    // Log warning if approaching limit
    if (this.state.dailyUsed >= WARNING_THRESHOLD && this.state.dailyUsed < WARNING_THRESHOLD + 10) {
      logger.warn('ESPNRateLimiter: Approaching daily soft cap', {
        used: this.state.dailyUsed,
        softCap: DAILY_SOFT_CAP,
      });
    }

    return { allowed: true };
  }

  recordRequest(bucket: ESPNBudgetBucket): void {
    this.checkAndResetIfNewDay();
    this.refillTokens();

    this.state.tokens = Math.max(0, this.state.tokens - 1);
    this.state.dailyUsed++;
    this.state.bucketUsage[bucket]++;

    logger.debug('ESPNRateLimiter: Request recorded', {
      bucket,
      tokensRemaining: this.state.tokens,
      dailyUsed: this.state.dailyUsed,
      bucketUsed: this.state.bucketUsage[bucket],
    });
  }

  recordSuccess(): void {
    this.consecutiveSuccesses++;
    this.state.consecutiveErrors = 0;

    if (this.consecutiveSuccesses >= BACKOFF_CONFIG.successesToHalveBackoff) {
      if (this.state.currentBackoffMs > 0) {
        this.state.currentBackoffMs = Math.floor(this.state.currentBackoffMs / 2);
        logger.debug('ESPNRateLimiter: Halved backoff after consecutive successes', {
          newBackoffMs: this.state.currentBackoffMs,
        });
      }
      this.consecutiveSuccesses = 0;
    }
  }

  recordError(statusCode: number, isTimeout = false): void {
    this.consecutiveSuccesses = 0;
    this.state.consecutiveErrors++;
    this.lastErrorTime = Date.now();

    let backoffKey: string | number;
    if (isTimeout) {
      backoffKey = 'timeout';
    } else if (statusCode === 429) {
      backoffKey = 429;
    } else if (statusCode === 403) {
      backoffKey = 403;
    } else if (statusCode >= 500) {
      backoffKey = '5xx';
    } else {
      return;
    }

    if (this.state.consecutiveErrors >= BACKOFF_CONFIG.consecutiveErrorThreshold) {
      backoffKey = 'consecutive';
    }

    const initialBackoff = BACKOFF_CONFIG.initial[backoffKey];
    const maxBackoff = BACKOFF_CONFIG.max[backoffKey];

    if (this.state.currentBackoffMs === 0) {
      this.state.currentBackoffMs = initialBackoff;
    } else {
      this.state.currentBackoffMs = Math.min(this.state.currentBackoffMs * 2, maxBackoff);
    }

    this.state.backoffUntil = Date.now() + this.state.currentBackoffMs;

    logger.warn('ESPNRateLimiter: Backoff triggered', {
      statusCode,
      isTimeout,
      backoffMs: this.state.currentBackoffMs,
      backoffUntil: new Date(this.state.backoffUntil).toISOString(),
      consecutiveErrors: this.state.consecutiveErrors,
    });
  }

  getStatus() {
    this.checkAndResetIfNewDay();
    this.refillTokens();
    this.checkBackoffExpiry();

    const buckets = {
      scoreboard: {
        used: this.state.bucketUsage.scoreboard,
        limit: BUCKET_CONFIG.scoreboard.dailyLimit,
        remaining: Math.max(0, BUCKET_CONFIG.scoreboard.dailyLimit - this.state.bucketUsage.scoreboard),
      },
      gameSummary: {
        used: this.state.bucketUsage.gameSummary,
        limit: BUCKET_CONFIG.gameSummary.dailyLimit,
        remaining: Math.max(0, BUCKET_CONFIG.gameSummary.dailyLimit - this.state.bucketUsage.gameSummary),
      },
      standings: {
        used: this.state.bucketUsage.standings,
        limit: BUCKET_CONFIG.standings.dailyLimit,
        remaining: Math.max(0, BUCKET_CONFIG.standings.dailyLimit - this.state.bucketUsage.standings),
      },
      schedule: {
        used: this.state.bucketUsage.schedule,
        limit: BUCKET_CONFIG.schedule.dailyLimit,
        remaining: Math.max(0, BUCKET_CONFIG.schedule.dailyLimit - this.state.bucketUsage.schedule),
      },
      reserve: {
        used: this.state.bucketUsage.reserve,
        limit: BUCKET_CONFIG.reserve.dailyLimit,
        remaining: Math.max(0, BUCKET_CONFIG.reserve.dailyLimit - this.state.bucketUsage.reserve),
      },
    };

    return {
      tokenBucket: {
        tokens: Math.floor(this.state.tokens),
        capacity: TOKEN_BUCKET_CAPACITY,
      },
      daily: {
        used: this.state.dailyUsed,
        softCap: DAILY_SOFT_CAP,
        hardCap: DAILY_HARD_CAP,
        remaining: Math.max(0, DAILY_SOFT_CAP - this.state.dailyUsed),
      },
      buckets,
      backoff: {
        active: this.state.backoffUntil !== null && this.state.backoffUntil > Date.now(),
        until: this.state.backoffUntil ? new Date(this.state.backoffUntil).toISOString() : null,
        consecutiveErrors: this.state.consecutiveErrors,
      },
      lastResetDate: this.state.lastResetDate,
    };
  }

  toJSON() {
    return { ...this.state };
  }

  fromJSON(data: RateLimiterState): void {
    this.state = data;
    this.checkAndResetIfNewDay();
  }
}

// Singleton instance
let rateLimiterInstance: ESPNRateLimiter | null = null;

export function getESPNRateLimiter(): ESPNRateLimiter {
  if (!rateLimiterInstance) {
    rateLimiterInstance = new ESPNRateLimiter();
  }
  return rateLimiterInstance;
}

export function resetESPNRateLimiter(): void {
  rateLimiterInstance = null;
}
