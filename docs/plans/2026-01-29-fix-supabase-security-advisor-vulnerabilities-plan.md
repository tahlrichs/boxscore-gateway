---
title: Fix Supabase Security Advisor Vulnerabilities
type: fix
date: 2026-01-29
linear: BOX-26
brainstorm: docs/brainstorms/2026-01-29-supabase-security-fixes-brainstorm.md
---

# Fix Supabase Security Advisor Vulnerabilities

## Overview

Resolve all 13 errors and 4 warnings from the Supabase Security Advisor. The gateway uses the service role key (bypasses RLS), so enabling RLS with no policies locks down direct access via the anon key without breaking anything.

**Error breakdown (13):** 11 tables missing RLS + 1 Security Definer view + 1 additional RLS issue on `provider_sync_log` (counted separately by advisor).

**Warning breakdown (4):** 3 functions with mutable search paths + leaked password protection disabled.

## Acceptance Criteria

- [x] All 11 flagged tables have RLS enabled (no policies — blocks anon key access entirely)
- [x] NFL tables (`nfl_player_season_summary`, `nfl_player_game_logs`, `nfl_player_career_summary`) also have RLS enabled
- [x] `team_live_status` table has RLS enabled (referenced by `is_player_live`, not flagged but needs it)
- [x] `v_id_mappings` view changed from SECURITY DEFINER to SECURITY INVOKER
- [x] 3 functions have `search_path = ''` with fully qualified table references
- [ ] Leaked password protection enabled in Supabase dashboard (manual step)
- [ ] Gateway still returns data for all leagues after migration
- [ ] Anon key queries to sports tables return empty results (blocked by RLS)

## Migration File

`gateway/src/db/migrations/005_security_advisor_fixes.sql`

```sql
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
ALTER TABLE public.nfl_player_season_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfl_player_game_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfl_player_career_summary ENABLE ROW LEVEL SECURITY;

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
```

## Manual Step (Supabase Dashboard)

After running the migration:

1. Go to **Supabase Dashboard > Authentication > Settings**
2. Scroll to **Leaked Password Protection**
3. Toggle it **ON**

## Verification

After applying the migration:

### 1. SQL Editor checks (Supabase Dashboard)

```sql
-- Confirm service role still has access
SELECT count(*) FROM public.games;
SELECT count(*) FROM public.nfl_player_season_summary;
SELECT * FROM public.v_id_mappings LIMIT 5;
SELECT public.materialize_game_dates(NULL);

-- Confirm anon key is blocked
SET ROLE anon;
SELECT count(*) FROM public.games;                    -- Should return 0 rows
SELECT count(*) FROM public.nfl_player_season_summary; -- Should return 0 rows
SELECT * FROM public.v_id_mappings LIMIT 5;            -- Should return 0 rows
RESET ROLE;
```

### 2. REST API check (most realistic anon key test)

```bash
curl 'https://YOUR_PROJECT.supabase.co/rest/v1/games?select=count' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Authorization: Bearer YOUR_ANON_KEY'
# Should return empty array []
```

### 3. Gateway check

```
GET /v1/scoreboard?league=nba&date=2026-01-29
GET /v1/health
```

Confirm the gateway still returns game data for all leagues.

## Rollback

If anything breaks, run the SQL below. Note: the function `search_path` changes are intentionally **not** reverted — they are strictly more secure and harmless regardless of RLS state.

```sql
ALTER TABLE public.external_ids DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_seasons DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.games DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_dates DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_sync_log DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.players DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_season_summary DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_game_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_splits DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nba_player_career_summary DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfl_player_season_summary DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfl_player_game_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfl_player_career_summary DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.team_live_status DISABLE ROW LEVEL SECURITY;
ALTER VIEW public.v_id_mappings SET (security_invoker = off);
```

## References

- Brainstorm: [docs/brainstorms/2026-01-29-supabase-security-fixes-brainstorm.md](docs/brainstorms/2026-01-29-supabase-security-fixes-brainstorm.md)
- Existing schema: [gateway/src/db/schema.sql](gateway/src/db/schema.sql)
- Profiles RLS (reference): [gateway/src/db/migrations/003_create_profiles.sql](gateway/src/db/migrations/003_create_profiles.sql)
- Supabase Security Advisor: BOX-26 screenshots
