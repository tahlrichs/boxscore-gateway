import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

/**
 * IMPORTANT: Never expose data provider names (ESPN, etc.) in user-facing error messages.
 * All error messages should be sanitized before being sent to clients.
 */

// Provider names that should never be shown to users
const HIDDEN_PROVIDERS = ['ESPN', 'espn', 'Espn'];

/**
 * Sanitize error messages to remove provider names and internal details
 * that should not be exposed to end users.
 */
function sanitizeErrorMessage(message: string): string {
  let sanitized = message;

  // Remove provider names
  for (const provider of HIDDEN_PROVIDERS) {
    // Replace "from ESPN" patterns
    sanitized = sanitized.replace(new RegExp(`\\s*from\\s+${provider}`, 'gi'), '');
    // Replace "ESPN adapter" patterns
    sanitized = sanitized.replace(new RegExp(`${provider}\\s*adapter`, 'gi'), 'data provider');
    // Replace standalone ESPN references
    sanitized = sanitized.replace(new RegExp(`${provider}`, 'gi'), 'data provider');
  }

  // Clean up any double spaces
  sanitized = sanitized.replace(/\s{2,}/g, ' ').trim();

  return sanitized;
}

export class AppError extends Error {
  statusCode: number;
  code: string;

  constructor(message: string, statusCode: number = 500, code: string = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

export class BadRequestError extends AppError {
  constructor(message: string = 'Bad request') {
    super(message, 400, 'BAD_REQUEST');
  }
}

export class ProviderError extends AppError {
  constructor(message: string = 'Provider error') {
    super(message, 502, 'PROVIDER_ERROR');
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = 'Rate limit exceeded') {
    super(message, 429, 'RATE_LIMITED');
  }
}

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Log the full error internally (with provider details for debugging)
  logger.error('Request error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // Handle known errors - sanitize message before sending to client
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.code,
      message: sanitizeErrorMessage(err.message),
    });
    return;
  }

  // Handle unknown errors - always sanitize
  res.status(500).json({
    error: 'INTERNAL_ERROR',
    message: process.env.NODE_ENV === 'production'
      ? 'An unexpected error occurred'
      : sanitizeErrorMessage(err.message),
  });
}
