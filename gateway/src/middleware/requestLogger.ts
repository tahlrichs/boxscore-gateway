import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

// Extend Express Request to include requestId
declare global {
  namespace Express {
    interface Request {
      requestId: string;
      startTime: number;
    }
  }
}

export function requestLogger(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Generate request ID
  req.requestId = uuidv4();
  req.startTime = Date.now();

  // Log request
  logger.info('Incoming request', {
    requestId: req.requestId,
    method: req.method,
    path: req.path,
    query: req.query,
    clientVersion: req.headers['x-client-version'],
    deviceId: req.headers['x-device-id'],
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - req.startTime;
    
    logger.info('Request completed', {
      requestId: req.requestId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
  });

  next();
}
