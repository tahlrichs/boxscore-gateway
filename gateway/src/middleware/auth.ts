import { Request, Response, NextFunction } from 'express';
import { jwtVerify, createRemoteJWKSet, errors } from 'jose';
import { AppError } from './errorHandler';
import { config } from '../config';

// Create JWKS once at startup (jose caches and auto-refreshes)
const JWKS = createRemoteJWKSet(
  new URL(`${config.supabase.url}/auth/v1/.well-known/jwks.json`)
);

// Extend Express Request
declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

/**
 * Require valid Supabase JWT. Returns 401 if missing or invalid.
 */
export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next(new AppError('Authorization header required', 401, 'UNAUTHORIZED'));
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `${config.supabase.url}/auth/v1`,
      audience: 'authenticated',
    });

    if (!payload.sub) {
      return next(new AppError('Invalid token: missing subject', 401, 'TOKEN_INVALID'));
    }

    req.user = {
      id: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
    };

    next();
  } catch (error) {
    if (error instanceof errors.JWTExpired) {
      return next(new AppError('Token expired', 401, 'TOKEN_EXPIRED'));
    }
    if (error instanceof errors.JOSEError) {
      return next(new AppError('Invalid token', 401, 'TOKEN_INVALID'));
    }
    return next(error);
  }
}

/**
 * Attach user to request if valid token provided, but don't require it.
 * Use for routes that work for guests but can personalize for logged-in users.
 */
export async function optionalAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: `${config.supabase.url}/auth/v1`,
      audience: 'authenticated',
    });

    if (payload.sub) {
      req.user = {
        id: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : undefined,
      };
    }
  } catch (error) {
    // Only ignore token validation errors, not infrastructure failures
    if (!(error instanceof errors.JOSEError)) {
      console.warn('Auth infrastructure error in optionalAuth:', error);
    }
    // Continue without user for optional auth
  }

  next();
}
