/**
 * Request validation middleware
 * Validates common request parameters to prevent invalid data from reaching routes
 */

import { Request, Response, NextFunction } from 'express';

// Valid league identifiers
const VALID_LEAGUES = ['nba', 'nfl', 'nhl', 'mlb', 'ncaam', 'ncaaf', 'pga', 'lpga', 'korn_ferry'];

// Valid season format: YYYY or YYYY-YY (e.g., "2024" or "2023-24")
const SEASON_REGEX = /^\d{4}(-\d{2})?$/;

// Valid date format: YYYY-MM-DD
const DATE_REGEX = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;

// Valid game ID format: league_identifier (e.g., "nba_401584701")
const GAME_ID_REGEX = /^[a-z]+_[\w-]+$/;

/**
 * Validate league parameter
 */
export function validateLeague(req: Request, res: Response, next: NextFunction): void {
  const league = req.query.league as string | undefined;

  if (!league) {
    res.status(400).json({
      error: 'Validation Error',
      message: 'Missing required parameter: league',
      validValues: VALID_LEAGUES,
    });
    return;
  }

  if (!VALID_LEAGUES.includes(league.toLowerCase())) {
    res.status(400).json({
      error: 'Validation Error',
      message: `Invalid league: ${league}`,
      validValues: VALID_LEAGUES,
    });
    return;
  }

  // Normalize to lowercase
  req.query.league = league.toLowerCase();
  next();
}

/**
 * Validate date parameter (YYYY-MM-DD format)
 */
export function validateDate(req: Request, res: Response, next: NextFunction): void {
  const date = req.query.date as string | undefined;

  if (!date) {
    res.status(400).json({
      error: 'Validation Error',
      message: 'Missing required parameter: date',
      format: 'YYYY-MM-DD',
    });
    return;
  }

  if (!DATE_REGEX.test(date)) {
    res.status(400).json({
      error: 'Validation Error',
      message: `Invalid date format: ${date}`,
      format: 'YYYY-MM-DD',
      example: '2024-01-15',
    });
    return;
  }

  // Validate that it's a real date
  const dateObj = new Date(date);
  if (isNaN(dateObj.getTime())) {
    res.status(400).json({
      error: 'Validation Error',
      message: `Invalid date: ${date}`,
      format: 'YYYY-MM-DD',
    });
    return;
  }

  next();
}

/**
 * Validate season parameter
 */
export function validateSeason(required: boolean = false) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const season = req.query.season as string | undefined;

    if (!season) {
      if (required) {
        res.status(400).json({
          error: 'Validation Error',
          message: 'Missing required parameter: season',
          format: 'YYYY or YYYY-YY',
          examples: ['2024', '2023-24'],
        });
        return;
      }
      // Optional - let the route decide what default to use
      next();
      return;
    }

    if (!SEASON_REGEX.test(season)) {
      res.status(400).json({
        error: 'Validation Error',
        message: `Invalid season format: ${season}`,
        format: 'YYYY or YYYY-YY',
        examples: ['2024', '2023-24'],
      });
      return;
    }

    next();
  };
}

/**
 * Validate game ID parameter
 */
export function validateGameId(req: Request, res: Response, next: NextFunction): void {
  const id = req.params.id;

  if (!id) {
    res.status(400).json({
      error: 'Validation Error',
      message: 'Missing required parameter: id',
    });
    return;
  }

  const idString = Array.isArray(id) ? id[0] : id;
  if (!GAME_ID_REGEX.test(idString)) {
    res.status(400).json({
      error: 'Validation Error',
      message: `Invalid game ID format: ${idString}`,
      format: 'league_identifier',
      example: 'nba_401584701',
    });
    return;
  }

  next();
}

/**
 * Validate team ID parameter
 */
export function validateTeamId(req: Request, res: Response, next: NextFunction): void {
  const id = req.params.id;

  if (!id) {
    res.status(400).json({
      error: 'Validation Error',
      message: 'Missing required parameter: id',
    });
    return;
  }

  // Team IDs should follow the same format as game IDs: league_identifier
  const idString = Array.isArray(id) ? id[0] : id;
  if (!GAME_ID_REGEX.test(idString)) {
    res.status(400).json({
      error: 'Validation Error',
      message: `Invalid team ID format: ${idString}`,
      format: 'league_identifier',
      example: 'nba_1610612747',
    });
    return;
  }

  next();
}

/**
 * Validate date range (for historical queries and scheduled games)
 */
export function validateDateRange(maxDaysBack: number = 365, maxDaysAhead: number = 365) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const date = req.query.date as string;

    if (!date) {
      next();
      return;
    }

    const requestDate = new Date(date);
    const today = new Date();
    const maxDate = new Date();
    maxDate.setDate(maxDate.getDate() - maxDaysBack);

    // Check if date is too far in the past
    if (requestDate < maxDate) {
      res.status(400).json({
        error: 'Validation Error',
        message: `Date is too far in the past. Maximum ${maxDaysBack} days back allowed.`,
        requestedDate: date,
        oldestAllowed: maxDate.toISOString().split('T')[0],
      });
      return;
    }

    // Check if date is too far in the future
    const futureLimit = new Date();
    futureLimit.setDate(futureLimit.getDate() + maxDaysAhead);

    if (requestDate > futureLimit) {
      res.status(400).json({
        error: 'Validation Error',
        message: `Date is too far in the future. Maximum ${maxDaysAhead} days ahead allowed.`,
        requestedDate: date,
        latestAllowed: futureLimit.toISOString().split('T')[0],
      });
      return;
    }

    next();
  };
}
