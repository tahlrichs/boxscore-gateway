import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../middleware/auth';
import { pool } from '../db/pool';
import { supabaseAdmin } from '../db/supabaseAdmin';
import { BadRequestError, NotFoundError } from '../middleware/errorHandler';

const router = Router();

// Types
interface Profile {
  id: string;
  first_name: string | null;
  favorite_teams: string[];
  created_at: string;
}

interface ProfileUpdate {
  first_name?: string | null;
  favorite_teams?: string[];
}

/**
 * GET /v1/auth/me
 * Returns current user info + profile
 */
router.get('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;

    const result = await pool.query<Profile>(
      `SELECT id, first_name, favorite_teams, created_at
       FROM profiles WHERE id = $1`,
      [userId]
    );

    const profile = result.rows[0] || null;

    res.json({
      user: {
        id: req.user!.id,
        email: req.user!.email,
      },
      profile,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /v1/auth/me
 * Update current user's profile
 */
router.patch('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const { first_name, favorite_teams }: ProfileUpdate = req.body;

    // Validate input
    if (first_name !== undefined && first_name !== null) {
      if (typeof first_name !== 'string' || first_name.length > 50) {
        throw new BadRequestError('first_name must be a string under 50 characters');
      }
    }

    if (favorite_teams !== undefined) {
      if (!Array.isArray(favorite_teams) || favorite_teams.length > 30) {
        throw new BadRequestError('favorite_teams must be an array with max 30 items');
      }
      // Validate each team ID: must be string, max 50 chars, format: league_identifier
      const TEAM_ID_REGEX = /^[a-z]+_[\w-]+$/;
      for (const teamId of favorite_teams) {
        if (typeof teamId !== 'string' || teamId.length > 50 || !TEAM_ID_REGEX.test(teamId)) {
          throw new BadRequestError('Invalid team ID format (expected: league_identifier, e.g., nba_1610612744)');
        }
      }
    }

    // Check at least one field provided
    if (first_name === undefined && favorite_teams === undefined) {
      throw new BadRequestError('No fields to update');
    }

    // Update with COALESCE to handle partial updates
    const result = await pool.query<Profile>(
      `UPDATE profiles
       SET first_name = COALESCE($1, first_name),
           favorite_teams = COALESCE($2, favorite_teams)
       WHERE id = $3
       RETURNING id, first_name, favorite_teams, created_at`,
      [
        first_name ?? null,
        favorite_teams ? JSON.stringify(favorite_teams) : null,
        userId
      ]
    );

    if (result.rows.length === 0) {
      throw new NotFoundError('Profile not found');
    }

    res.json({ profile: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /v1/auth/me
 * Delete current user's account
 */
router.delete('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;

    // Delete profile first (cascade should handle this, but be explicit)
    await pool.query('DELETE FROM profiles WHERE id = $1', [userId]);

    // Delete from Supabase Auth using service role
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (error) {
      throw new Error(`Failed to delete user: ${error.message}`);
    }

    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

export default router;
