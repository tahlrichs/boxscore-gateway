---
title: "Fix Supabase Security Advisor Vulnerabilities"
date: 2026-01-29
category: security-issues
tags:
  - supabase
  - rls
  - row-level-security
  - security-advisor
  - search-path
  - security-definer
  - database
module: Gateway
linear_issue: BOX-26
symptoms:
  - "Supabase Security Advisor shows 13 errors and 4 warnings"
  - "RLS disabled on public tables"
  - "Function search path mutable warning"
  - "Security Definer view warning"
---

# Fix Supabase Security Advisor Vulnerabilities

## Problem

Supabase Security Advisor flagged 13 errors and 4 warnings:

- **11 tables** with RLS disabled (anyone with the anon key could query them directly)
- **1 view** (`v_id_mappings`) using SECURITY DEFINER (runs as owner, bypassing caller's permissions)
- **1 additional RLS issue** on `provider_sync_log`
- **3 functions** with mutable search paths (schema injection risk)
- **Leaked password protection** disabled

The anon key is embedded in the iOS app — anyone could extract it and query Supabase directly, bypassing the gateway entirely.

## Root Cause

Tables were created without RLS because the gateway uses the service role key (which bypasses RLS). Nobody considered that the anon key embedded in the iOS app could be used for direct database access.

## Solution

### Key Insight

Enable RLS with **no policies** on all sports data tables. This blocks all access except the service role key, which is exactly what we want — the gateway is the only legitimate data consumer.

### Migration: `005_security_advisor_fixes.sql`

Three changes in a single transaction:

1. **Enable RLS on all tables** — `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` with no policies means zero access for anon/authenticated roles
2. **Change view to SECURITY INVOKER** — `ALTER VIEW v_id_mappings SET (security_invoker = on)` so the view respects the caller's permissions
3. **Set empty search_path on functions** — `SET search_path = ''` with fully qualified `public.table_name` references prevents schema injection

### Gotchas Encountered

- **NFL tables didn't exist yet in Supabase** — migration used `ALTER TABLE` without `IF EXISTS` for NFL tables, causing the entire transaction to roll back. Fixed by adding `IF EXISTS` for tables that may not be deployed yet.
- **Supabase SQL Editor runs as service role** — verification queries using `SET ROLE anon` are needed to actually test that RLS blocks the anon key. Without this, everything looks fine because you're running as the owner.

## Prevention

- When creating new tables, always include `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` in the same migration
- Use `IF EXISTS` for tables that may not be deployed in all environments
- Always fully qualify table references in functions (`public.table_name`)
- Run the Supabase Security Advisor periodically after schema changes

## Related

- [Brainstorm](../../brainstorms/2026-01-29-supabase-security-fixes-brainstorm.md)
- [Plan](../../plans/2026-01-29-fix-supabase-security-advisor-vulnerabilities-plan.md)
- PR: [#7](https://github.com/tahlrichs/boxscore-gateway/pull/7)
