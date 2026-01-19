/**
 * Golf routes - Week-based scoreboard and tournament leaderboard endpoints
 */

import { Router, Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { getESPNAdapter } from '../providers/espnAdapter';
import { GolfScoreboardResponse, GolfTournament } from '../types';

export const golfRouter = Router();

// Valid golf tours
const VALID_TOURS = ['pga', 'lpga', 'korn_ferry'];

/**
 * Validate tour parameter
 */
function validateTour(req: Request, res: Response, next: NextFunction): void {
  const tour = req.query.tour as string | undefined;

  if (!tour) {
    res.status(400).json({
      error: 'Validation Error',
      message: 'Missing required parameter: tour',
      validValues: VALID_TOURS,
    });
    return;
  }

  if (!VALID_TOURS.includes(tour.toLowerCase())) {
    res.status(400).json({
      error: 'Validation Error',
      message: `Invalid tour: ${tour}`,
      validValues: VALID_TOURS,
    });
    return;
  }

  req.query.tour = tour.toLowerCase();
  next();
}

/**
 * Get the Monday of the week containing a given date (UTC-based to avoid timezone issues)
 */
function getMondayOfWeek(dateStr: string): string {
  // Parse date string directly to avoid timezone issues
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  const dayOfWeek = date.getUTCDay();
  const diff = dayOfWeek === 0 ? -6 : 1 - dayOfWeek; // Adjust for Sunday

  date.setUTCDate(date.getUTCDate() + diff);

  // Return as YYYY-MM-DD string
  return date.toISOString().split('T')[0];
}

/**
 * GET /v1/golf/scoreboard
 * Get golf tournaments for a specific week
 *
 * Query params:
 * - tour: 'pga' | 'korn_ferry' (required)
 * - week: Date string (YYYY-MM-DD) - returns tournaments for the week containing this date (default: current week)
 */
golfRouter.get('/scoreboard', validateTour, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const tour = req.query.tour as string;
    const weekParam = req.query.week as string | undefined;

    // Determine the week start date string (YYYY-MM-DD)
    let weekDateStr: string;
    if (weekParam) {
      // Validate date format
      if (!/^\d{4}-\d{2}-\d{2}$/.test(weekParam)) {
        res.status(400).json({
          error: 'Validation Error',
          message: `Invalid date format: ${weekParam}`,
          format: 'YYYY-MM-DD',
        });
        return;
      }
      weekDateStr = weekParam;
    } else {
      // Use today's date
      weekDateStr = new Date().toISOString().split('T')[0];
    }

    const weekStart = getMondayOfWeek(weekDateStr);

    logger.info('Golf scoreboard request', { tour, weekStart, weekParam });

    const adapter = getESPNAdapter();
    const response: GolfScoreboardResponse = await adapter.fetchGolfScoreboard(
      tour,
      weekStart
    );

    res.json({
      data: response,
      lastUpdated: response.lastUpdated,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /v1/golf/tournaments/:id/leaderboard
 * Get full leaderboard for a specific tournament
 *
 * Path params:
 * - id: Tournament ID (e.g., 'pga_401580352')
 */
golfRouter.get('/tournaments/:id/leaderboard', async (req: Request<{ id: string }>, res: Response, next: NextFunction) => {
  try {
    const tournamentId = req.params.id;

    if (!tournamentId) {
      res.status(400).json({
        error: 'Validation Error',
        message: 'Missing required parameter: id',
      });
      return;
    }

    // Validate tournament ID format
    const parts = tournamentId.split('_');
    if (parts.length < 2 || !VALID_TOURS.includes(parts[0])) {
      res.status(400).json({
        error: 'Validation Error',
        message: `Invalid tournament ID format: ${tournamentId}`,
        format: 'tour_eventId (e.g., pga_401580352)',
      });
      return;
    }

    logger.info('Golf leaderboard request', { tournamentId });

    const adapter = getESPNAdapter();
    const tournament: GolfTournament | null = await adapter.fetchGolfLeaderboard(tournamentId);

    if (!tournament) {
      res.status(404).json({
        error: 'Not Found',
        message: `Tournament not found: ${tournamentId}`,
      });
      return;
    }

    res.json({
      data: tournament,
      lastUpdated: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /v1/golf/available-weeks
 * Get list of available weeks for golf tournaments
 *
 * Query params:
 * - tour: 'pga' | 'korn_ferry' (required)
 */
golfRouter.get('/available-weeks', validateTour, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Return a range of weeks around the current date
    // Golf season typically runs from January to August (PGA Tour wrap-around)
    const now = new Date();
    const weeks: string[] = [];

    // Generate 26 weeks before and 26 weeks after current date
    for (let i = -26; i <= 26; i++) {
      const weekDate = new Date(now);
      weekDate.setDate(weekDate.getDate() + (i * 7));
      const weekDateStr = weekDate.toISOString().split('T')[0];
      const monday = getMondayOfWeek(weekDateStr);
      weeks.push(monday);
    }

    res.json({
      data: weeks,
      lastUpdated: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
});
