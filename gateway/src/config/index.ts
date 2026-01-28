import dotenv from 'dotenv';

dotenv.config();

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  // Server
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // CORS
  corsOrigins: process.env.CORS_ORIGINS?.split(',') || ['*'],

  // Redis
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',

  // Data Provider (ESPN is the only provider)
  provider: 'espn',

  // ESPN Rate Limits
  espn: {
    dailyBudget: parseInt(process.env.ESPN_DAILY_BUDGET || '2000', 10),
    requestsPerMinute: parseInt(process.env.ESPN_REQUESTS_PER_MINUTE || '60', 10),
  },

  // Cache TTLs (seconds)
  cacheTtl: {
    liveGame: parseInt(process.env.CACHE_TTL_LIVE_GAME || '15', 10),
    scoreboard: parseInt(process.env.CACHE_TTL_SCOREBOARD || '30', 10),
    boxScore: parseInt(process.env.CACHE_TTL_BOX_SCORE || '30', 10),
    standings: parseInt(process.env.CACHE_TTL_STANDINGS || '21600', 10), // 6 hours
    roster: parseInt(process.env.CACHE_TTL_ROSTER || '86400', 10), // 24 hours
    schedule: parseInt(process.env.CACHE_TTL_SCHEDULE || '43200', 10), // 12 hours
    playerStats: parseInt(process.env.CACHE_TTL_PLAYER_STATS || '300', 10), // 5 minutes
  },

  // Rate Limiting
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10),
  rateLimitMaxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),

  // Logging
  logLevel: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),

  // Supabase Auth
  supabase: {
    url: requireEnv('SUPABASE_URL'),
    anonKey: requireEnv('SUPABASE_ANON_KEY'),
  },
};

// League configurations
export const leagueConfig = {
  nba: { espnPath: 'basketball/nba', name: 'NBA' },
  nfl: { espnPath: 'football/nfl', name: 'NFL' },
  nhl: { espnPath: 'hockey/nhl', name: 'NHL' },
  mlb: { espnPath: 'baseball/mlb', name: 'MLB' },
  ncaam: { espnPath: 'basketball/mens-college-basketball', name: 'NCAAM' },
  ncaaf: { espnPath: 'football/college-football', name: 'NCAAF' },
  pga: { espnPath: 'golf/pga', name: 'PGA Tour' },
  korn_ferry: { espnPath: 'golf/korn-ferry', name: 'Korn Ferry Tour' },
};

export type LeagueId = keyof typeof leagueConfig;
