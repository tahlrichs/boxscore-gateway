# Supabase Security Fixes Brainstorm

**Date:** 2026-01-29
**Linear Issue:** BOX-26 — Supabase vulnerabilities
**Status:** Ready for planning

## What We're Building

Fix all 13 errors and 4 warnings flagged by the Supabase Security Advisor. The issues fall into four categories:

1. **RLS Disabled on 11 tables** (errors) — sports data tables have no Row Level Security
2. **Security Definer View** (error) — `v_id_mappings` view uses SECURITY DEFINER
3. **Function Search Path Mutable** (3 warnings) — database functions missing `search_path`
4. **Leaked Password Protection Disabled** (warning) — Supabase Auth setting

## Why This Approach

### Architecture Context

- iOS app uses Supabase **only for auth** (sign in/up/token refresh)
- All data access goes through the **gateway**, which uses the **service role key** (bypasses RLS)
- The anon key is embedded in the iOS app — anyone could extract it and query Supabase directly
- RLS is the defense against unauthorized direct access

### Chosen Approach: Gateway-Only Access

Enable RLS on all public tables with **no permissive policies** for the sports data tables. This means:

- The gateway (service role) continues working as-is — service role bypasses RLS
- Direct queries using the anon key get **blocked entirely** (no policies = no access)
- The `profiles` table already has proper RLS with user-scoped policies (unchanged)
- If we ever need direct Supabase queries from iOS, we'd add read-only policies later

This is the simplest and most secure option. Since all data flows through the gateway anyway, there's no reason to allow direct table access.

## Key Decisions

1. **RLS with no policies** on sports data tables — blocks all direct access, gateway unaffected
2. **Fix all warnings** in the same pass — function search paths + leaked password protection
3. **Security Definer view** — review `v_id_mappings` and change to SECURITY INVOKER if safe
4. **Leaked password protection** — enable in Supabase dashboard (manual step)

## Tables to Enable RLS On

| Table | Current RLS |
|-------|-------------|
| `public.external_ids` | Disabled |
| `public.teams` | Disabled |
| `public.league_seasons` | Disabled |
| `public.games` | Disabled |
| `public.game_dates` | Disabled |
| `public.provider_sync_log` | Disabled |
| `public.players` | Disabled |
| `public.nba_player_season_summary` | Disabled |
| `public.nba_player_game_logs` | Disabled |
| `public.nba_player_splits` | Disabled |
| `public.nba_player_career_summary` | Disabled |

## Functions to Fix

| Function | Fix |
|----------|-----|
| `public.update_updated_at_column` | Set `search_path = ''` |
| `public.materialize_game_dates` | Set `search_path = ''` |
| `public.is_player_live` | Set `search_path = ''` |

## Manual Steps (Supabase Dashboard)

- Enable **Leaked Password Protection** in Auth settings

## Open Questions

- Does `v_id_mappings` need SECURITY DEFINER, or can it be changed to INVOKER?
- Are there NFL stats tables (`nfl_player_*`) that also need RLS? (Migration 002 exists but wasn't flagged — may not be deployed yet)
