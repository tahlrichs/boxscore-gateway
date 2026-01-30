-- 005_security_advisor_fixes.sql
-- Fix all Supabase Security Advisor errors and warnings (BOX-26)
-- Safe to run: gateway uses service role key which bypasses RLS

BEGIN;

-- ============================================================
-- 1. Enable RLS on all sports data tables (no policies = blocked)
-- ============================================================

-- Tables flagged by Security Advisor
ALTER TABLE public.external_ids ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_sync_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_season_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_game_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_career_summary ENABLE ROW LEVEL SECURITY;

-- Not flagged but should also be locked down
ALTER TABLE IF EXISTS public.nfl_player_season_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.nfl_player_game_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.nfl_player_career_summary ENABLE ROW LEVEL SECURITY;

-- Referenced by is_player_live function
ALTER TABLE IF EXISTS public.team_live_status ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. Fix Security Definer view → Security Invoker
-- ============================================================

ALTER VIEW public.v_id_mappings SET (security_invoker = on);

-- ============================================================
-- 3. Fix function search paths (set to empty, fully qualify refs)
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION public.materialize_game_dates(p_season_id VARCHAR DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    INSERT INTO public.game_dates (
        league_id,
        season_id,
        scoreboard_date,
        game_count,
        first_game_time_utc,
        last_game_time_utc,
        has_live_games,
        all_games_final,
        last_refreshed_at,
        created_at,
        updated_at
    )
    SELECT
        g.league_id,
        g.season_id,
        g.scoreboard_date,
        COUNT(*) as game_count,
        MIN(g.start_time_utc) as first_game_time_utc,
        MAX(g.start_time_utc) as last_game_time_utc,
        BOOL_OR(g.status = 'live') as has_live_games,
        BOOL_AND(g.status = 'final') as all_games_final,
        MAX(g.last_refreshed_at) as last_refreshed_at,
        NOW() as created_at,
        NOW() as updated_at
    FROM public.games g
    WHERE (p_season_id IS NULL OR g.season_id = p_season_id)
    GROUP BY g.league_id, g.season_id, g.scoreboard_date
    ON CONFLICT (league_id, scoreboard_date)
    DO UPDATE SET
        season_id = EXCLUDED.season_id,
        game_count = EXCLUDED.game_count,
        first_game_time_utc = EXCLUDED.first_game_time_utc,
        last_game_time_utc = EXCLUDED.last_game_time_utc,
        has_live_games = EXCLUDED.has_live_games,
        all_games_final = EXCLUDED.all_games_final,
        last_refreshed_at = EXCLUDED.last_refreshed_at,
        updated_at = NOW();

    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION public.is_player_live(p_player_id VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_team_id VARCHAR(100);
    v_is_live BOOLEAN;
    v_last_game_end TIMESTAMP;
BEGIN
    SELECT current_team_id INTO v_team_id
    FROM public.players
    WHERE id = p_player_id;

    IF v_team_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT is_live, last_game_end_time
    INTO v_is_live, v_last_game_end
    FROM public.team_live_status
    WHERE team_id = v_team_id;

    IF v_is_live THEN
        RETURN true;
    ELSIF v_last_game_end IS NOT NULL AND v_last_game_end > NOW() - INTERVAL '3 hours' THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

COMMIT;
