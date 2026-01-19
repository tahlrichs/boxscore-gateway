import { Request, Response, NextFunction } from 'express';

// Extend Express Response to include caching info
declare global {
  namespace Express {
    interface Response {
      cacheHit?: boolean;
    }
  }
}

export function cacheMiddleware(
  _req: Request,
  res: Response,
  next: NextFunction
): void {
  // Add cache info to response headers
  const originalJson = res.json.bind(res);
  
  res.json = function(data: unknown) {
    // Add cache header
    if (res.cacheHit !== undefined) {
      res.setHeader('X-Cache', res.cacheHit ? 'HIT' : 'MISS');
    }
    
    return originalJson(data);
  };

  next();
}
