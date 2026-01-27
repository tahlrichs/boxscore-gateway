import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';
import { cacheMiddleware } from './middleware/cacheMiddleware';

// Routes
import { healthRouter } from './routes/health';
import { scoreboardRouter } from './routes/scoreboard';
import { gamesRouter } from './routes/games';
import { standingsRouter } from './routes/standings';
import { rankingsRouter } from './routes/rankings';
import { teamsRouter } from './routes/teams';
import { leaguesRouter } from './routes/leagues';
import { adminRouter } from './routes/admin';
import playerRouter from './routes/playerRoutes';
import { golfRouter } from './routes/golf';

// Initialize Redis
import { initializeRedis, isRedisAvailable } from './cache/redis';

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: config.corsOrigins,
  methods: ['GET'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Client-Version', 'X-Device-ID'],
}));

// Compression
app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMaxRequests,
  message: { error: 'Too many requests', message: 'Please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/v1', limiter);

// Body parsing
app.use(express.json());

// Request logging
app.use(requestLogger);

// Cache middleware
app.use(cacheMiddleware);

// API Routes
app.use('/v1/health', healthRouter);
app.use('/v1/leagues', leaguesRouter);
app.use('/v1/scoreboard', scoreboardRouter);
app.use('/v1/games', gamesRouter);
app.use('/v1/standings', standingsRouter);
app.use('/v1/rankings', rankingsRouter);
app.use('/v1/teams', teamsRouter);
app.use('/v1/players', playerRouter);
app.use('/v1/golf', golfRouter);
app.use('/v1/admin', adminRouter);

// Error handling
app.use(errorHandler);

// Start server
async function startServer() {
  try {
    // Initialize Redis connection (optional - will continue without cache if unavailable)
    await initializeRedis();
    if (isRedisAvailable()) {
      logger.info('Redis connected');
    } else {
      logger.warn('Running without Redis cache - all requests will hit the API directly');
    }

    // Graceful shutdown
    process.on('SIGTERM', async () => {
      logger.info('SIGTERM received, shutting down...');
      process.exit(0);
    });

    process.on('SIGINT', async () => {
      logger.info('SIGINT received, shutting down...');
      process.exit(0);
    });

    app.listen(config.port, () => {
      logger.info(`Gateway server running on port ${config.port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
      logger.info('Data provider: ESPN');
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export default app;
