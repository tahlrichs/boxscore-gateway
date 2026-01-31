---
title: "TruColor.net HTML scraping for team colors"
category: integration-issues
tags: [scraping, regex, html-parsing, team-colors, trucolor]
module: gateway/scripts
severity: n/a
date_solved: 2026-01-30
---

# TruColor.net HTML Scraping for Team Colors

## Problem

Needed to scrape current-season team colors (primary + secondary hex codes) for NBA, NFL, NHL, MLB, and NCAA D1 from TruColor.net and output a static JSON file for the iOS app.

## Key Challenges Encountered

### 1. Two distinct HTML formats

Pro league pages use:
```html
title="&#9989; <strong>TEAM NAME</strong> (year through present)"
```

NCAA pages use:
```html
class="collapseomatic" title="SCHOOL NAME"
```
with nested `ATHLETICS COLORS` subsections.

**Fix**: Separate `parseProPage()` and `parseNcaaPage()` functions.

### 2. Checkmark emoji is inconsistent

Not all current pro teams have `&#9989;`. Some just have `<strong>NAME</strong> (year through present)`.

**Fix**: Make checkmark optional in regex: `(?:&#9989;|✅)?`

### 3. NCAA conference URL discovery unreliable

The hub page links to non-NCAA leagues (MLB, NHL, soccer, lacrosse). Regex extraction returned 130+ pages instead of 33.

**Fix**: Hardcode the 33 actual NCAA D1 conference URLs.

### 4. `isSchoolName()` filtering

NCAA pages have many collapseomatic divs that aren't schools (year eras, subsection headers like "ATHLETICS COLORS", conference names). Schools must be distinguished from these.

**Fix**: Check for UNIVERSITY/COLLEGE/INSTITUTE/ACADEMY keywords first, exclude VAULT/GRAPHICS, exclude year-prefixed headers. The exclude patterns after the keyword check handle edge cases like "COLLEGE VAULT GRAPHICS COLORS".

### 5. Ohio State excluded by conference-name filter

Pattern meant to exclude "THE OHIO VALLEY CONFERENCE" also excluded "THE OHIO STATE UNIVERSITY AT COLUMBUS".

**Fix**: Move the UNIVERSITY/COLLEGE check *before* the conference-name exclusions.

### 6. `data/` directory gitignored

`gateway/.gitignore` had `data/` which blocked `src/data/teamColors.json`.

**Fix**: Add negation rules `!src/data/` and `!src/data/teamColors.json`.

## Solution Architecture

```
gateway/src/scripts/
  scrapeTeamColors.ts   # Orchestrator: fetches pages, writes JSON
  trucolorParser.ts     # Pure HTML parser (no side effects, no I/O)
  teamMappings.ts       # Static name -> abbreviation maps
gateway/src/data/
  teamColors.json       # Generated output (checked into git)
```

## Prevention & Best Practices

- **Iterative regex development**: Run scraper after each regex change, check team counts and unmapped list
- **Pure parser functions**: Keep parsing logic separate from I/O for testability
- **Polite scraping**: 300ms delays, custom User-Agent, reasonable content limits
- **Explicit mappings over fuzzy matching**: 650 lines of mappings is better than auto-generation that silently fails
- **Unit tests with fixture HTML**: Test both pro and NCAA paths with realistic HTML fragments

## Result

486 teams (30 NBA, 32 NFL, 32 NHL, 29 MLB, 363 NCAA), 0 unmapped. All verification checks passed.
