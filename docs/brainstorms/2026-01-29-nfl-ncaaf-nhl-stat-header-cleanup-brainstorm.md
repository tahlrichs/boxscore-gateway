# Stat Table Header Cleanup (BOX-30)

**Date:** 2026-01-29
**Linear:** BOX-30

## What We're Building

Remove redundant header rows in NFL, NCAAF, and NHL box score stat tables. Currently these sports show a separate category bar (e.g., "Punting") above a table header row that says "PLAYER". The category name should replace "PLAYER" in the table header, and the separate bar should be removed — producing a single, clean header row.

## Scope

| Sport | Current State | Change Needed |
|-------|--------------|---------------|
| NFL | Separate category bar + "PLAYER" header row | Merge: category name replaces "PLAYER", remove bar |
| NCAAF | Same as NFL | Same fix as NFL |
| NHL | Separate category bar + "SKATERS"/"GOALIES" rows | Merge skaters only: "SKATERS" in name column, remove bar. Goalies already correct. |
| NBA | Already correct | No change |
| NCAAM | Already correct | No change |

## Why This Approach

- `SimpleTableView` is a shared component — add an optional `headerLabel` parameter so NFL/NCAAF/NHL can pass the category name while NBA/NCAAM continue showing "PLAYER"
- Minimal change: one new optional parameter, update callers in 3 sport views

## Key Decisions

- NFL & NCAAF: category display name (e.g., "PUNTING", "KICKING") replaces "PLAYER"
- NHL: only skaters section needs the merge; goalies section is already correct
- NBA & NCAAM: untouched

## Files to Change

- `Components/Tables/SimpleTableView.swift` — add optional `headerLabel` param
- `Sports/NFL/NFLBoxScoreView.swift` — pass section name, remove category bar
- `Sports/NCAAF/` — same pattern as NFL (need to locate exact file)
- `Sports/NHL/` — pass "SKATERS" for skaters section, remove that category bar

## Open Questions

None — requirements are clear.
