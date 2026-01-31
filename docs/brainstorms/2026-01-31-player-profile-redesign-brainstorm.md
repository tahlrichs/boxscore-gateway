# Player Profile Redesign (BOX-41)

**Date:** 2026-01-31
**Status:** Ready for planning
**Linear:** BOX-41

## What We're Building

A redesigned Player Profile page that matches the reference screenshot from the Linear issue. The page will have a clear visual hierarchy with player bio info at top, prominent hero stats, and a tabbed content area with nested sub-tabs under Stat Central.

## Layout (Top to Bottom)

1. **Player Header**
   - Player name + Jersey number
   - Position
   - College
   - Hometown
   - Draft position

2. **Hero Stats Bar** (always visible, all tabs)
   - PPG | RPG | APG | FG% | 3P%
   - Large, prominent numbers

3. **Top-Level Tabs**: Bio | Stat Central | News

4. **Tab Content**
   - **Bio**: Placeholder for now
   - **Stat Central**:
     - Season Stats table (stat columns match BoxScore columns, but as averages)
     - Nested sub-tabs: Game Splits | Game Log | Advanced
       - Each sub-tab: placeholder content for now
   - **News**: Placeholder for now

## Key Decisions

- **Layout first, data later** — Build the full visual scaffold with placeholder/stub data, then wire real data in a follow-up
- **Hero stats always visible** — PPG, RPG, APG, FG%, 3P% stay above the tabs regardless of which tab is selected
- **Nested tab structure** — Game Splits, Game Log, Advanced are sub-tabs only visible under Stat Central
- **Stat columns match BoxScore** — Season Stats, Game Splits, and Game Log should use the same stat headers as the BoxScore view, but show averages instead of per-game totals
- **Hold off on season stats table styling** — May already be correct; will verify once data flows through

## Open Questions

- What specific stats go in the "Advanced" sub-tab? (Can define later)
- What content goes in Bio and News tabs? (Future issues)
- Should 3P% be included in hero stats for non-shooters, or adapt per player?

## Next Steps

Run `/workflows:plan` to create the implementation plan for the layout scaffold.
