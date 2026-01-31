#!/usr/bin/env tsx
/**
 * Scrape team colors from TruColor.net for NBA, NFL, NHL, MLB, and NCAA D1.
 *
 * Usage:  npm run scrape-colors
 *         tsx src/scripts/scrapeTeamColors.ts
 */

import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import { parseTrucolorPage, ParseResult } from './trucolorParser';
import { PRO_TEAM_ABBREVS, NCAA_SCHOOL_ABBREVS } from './teamMappings';

const DELAY_MS = 300;

const PRO_URLS: { league: string; urls: string[] }[] = [
  {
    league: 'nba',
    urls: [
      'https://www.trucolor.net/portfolio/national-basketball-association-official-colors-franchise-records-1946-1947-through-present/',
    ],
  },
  {
    league: 'nfl',
    urls: [
      'https://www.trucolor.net/portfolio/national-football-league-official-colors-franchise-records-1920-through-present/',
    ],
  },
  {
    league: 'nhl',
    urls: [
      'https://www.trucolor.net/portfolio/national-hockey-league-official-colors-franchise-records-1917-1918-through-present/',
    ],
  },
  {
    league: 'mlb',
    urls: [
      'https://www.trucolor.net/portfolio/major-league-baseball-american-league-official-colors-1903-through-present/',
      'https://www.trucolor.net/portfolio/major-league-baseball-national-league-official-colors-1903-through-present/',
    ],
  },
];

/**
 * Hardcoded NCAA D1 conference page URLs.
 * More reliable than parsing the hub page, which also links to non-NCAA leagues.
 */
const NCAA_CONFERENCE_URLS: string[] = [
  'https://www.trucolor.net/portfolio/america-east-conference-official-colors-and-nicknames-1979-1980-through-present/',
  'https://www.trucolor.net/portfolio/the-american-athletic-conference-official-colors-and-nicknames-2013-2014-through-present/',
  'https://www.trucolor.net/portfolio/atlantic-10-conference-official-colors-and-nicknames-1976-1977-through-present/',
  'https://www.trucolor.net/portfolio/atlantic-coast-conference-official-colors-and-nicknames-1953-1954-through-present/',
  'https://www.trucolor.net/portfolio/atlantic-sun-conference-official-colors-and-nicknames-1978-1979-through-present/',
  'https://www.trucolor.net/portfolio/big-12-conference-official-colors-and-nicknames-1996-1997-through-present/',
  'https://www.trucolor.net/portfolio/big-east-conference-official-colors-and-nicknames-2013-2014-through-present/',
  'https://www.trucolor.net/portfolio/big-sky-conference-official-colors-and-nicknames-1963-1964-through-present/',
  'https://www.trucolor.net/portfolio/big-south-conference-official-colors-and-nicknames-1983-1984-through-present/',
  'https://www.trucolor.net/portfolio/big-ten-conference-official-colors-and-nicknames-1896-1897-through-present/',
  'https://www.trucolor.net/portfolio/big-west-conference-official-colors-and-nicknames-1969-1970-through-present/',
  'https://www.trucolor.net/portfolio/coastal-athletic-association-official-colors-and-nicknames-1979-1980-through-present/',
  'https://www.trucolor.net/portfolio/conference-usa-official-colors-and-nicknames-1995-1996-through-present/',
  'https://www.trucolor.net/portfolio/horizon-league-official-colors-and-nicknames-1979-1980-through-present/',
  'https://www.trucolor.net/portfolio/ivy-league-official-colors-and-nicknames-1954-1955-through-present/',
  'https://www.trucolor.net/portfolio/metro-atlantic-athletic-conference-official-colors-and-nicknames-1981-1982-through-present/',
  'https://www.trucolor.net/portfolio/mid-american-conference-official-colors-and-nicknames-1946-1947-through-present/',
  'https://www.trucolor.net/portfolio/mid-eastern-athletic-conference-official-colors-and-nicknames-1970-1971-through-present/',
  'https://www.trucolor.net/portfolio/missouri-valley-conference-official-colors-and-nicknames-1907-1908-through-present/',
  'https://www.trucolor.net/portfolio/mountain-west-conference-official-colors-and-nicknames-1999-2000-through-present/',
  'https://www.trucolor.net/portfolio/ncaa-division-i-independents-official-colors-and-nicknames-1906-1907-through-present/',
  'https://www.trucolor.net/portfolio/northeast-conference-official-colors-and-nicknames-1981-1982-through-present/',
  'https://www.trucolor.net/portfolio/ohio-valley-conference-official-colors-and-nicknames-1948-1949-through-present/',
  'https://www.trucolor.net/portfolio/pac-12-conference-official-colors-and-nicknames-1915-1916-through-present/',
  'https://www.trucolor.net/portfolio/patriot-league-official-colors-and-nicknames-1986-1987-through-present/',
  'https://www.trucolor.net/portfolio/southeastern-conference-official-colors-and-nicknames-1932-1933-through-present/',
  'https://www.trucolor.net/portfolio/southern-conference-official-colors-and-nicknames-1921-1922-through-present/',
  'https://www.trucolor.net/portfolio/southland-conference-official-colors-and-nicknames-1963-1964-through-present/',
  'https://www.trucolor.net/portfolio/southwestern-athletic-conference-official-colors-and-nicknames-1920-1921-through-present/',
  'https://www.trucolor.net/portfolio/the-summit-league-official-colors-and-nicknames-1982-1983-through-present/',
  'https://www.trucolor.net/portfolio/sun-belt-conference-official-colors-and-nicknames-1976-1977-through-present/',
  'https://www.trucolor.net/portfolio/west-coast-conference-official-colors-and-nicknames-1952-1953-through-present/',
  'https://www.trucolor.net/portfolio/western-athletic-conference-official-colors-and-nicknames-1962-1963-through-present/',
];

async function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchPage(url: string): Promise<string | null> {
  try {
    const response = await axios.get<string>(url, {
      timeout: 60000,
      responseType: 'text',
      headers: {
        'User-Agent': 'BoxScore-ColorScraper/1.0 (educational project)',
        'Accept': 'text/html',
        'Accept-Encoding': 'gzip, deflate',
      },
      maxContentLength: 10 * 1024 * 1024, // 10MB
    });
    return response.data;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`  ✗ Failed to fetch ${url}: ${msg}`);
    return null;
  }
}

async function scrapeProLeagues(): Promise<Record<string, Record<string, any>>> {
  const result: Record<string, Record<string, any>> = {};
  const allUnmapped: string[] = [];

  for (const { league, urls } of PRO_URLS) {
    console.log(`\n--- ${league.toUpperCase()} ---`);
    const abbrevMap = PRO_TEAM_ABBREVS[league] || {};
    const leagueTeams: Record<string, any> = {};

    for (const url of urls) {
      console.log(`  Fetching: ${url.split('/portfolio/')[1]?.slice(0, 60)}...`);
      await delay(DELAY_MS);
      const html = await fetchPage(url);
      if (!html) continue;

      const parsed = parseTrucolorPage(html, abbrevMap);
      Object.assign(leagueTeams, parsed.teams);
      allUnmapped.push(...parsed.unmapped.map(n => `${league}: ${n}`));
      console.log(`  Found ${Object.keys(parsed.teams).length} teams`);
    }

    result[league] = leagueTeams;
    console.log(`  Total ${league.toUpperCase()}: ${Object.keys(leagueTeams).length} teams`);
  }

  if (allUnmapped.length > 0) {
    console.log('\n⚠ Unmapped pro teams:');
    allUnmapped.forEach(n => console.log(`  - ${n}`));
  }

  return result;
}

async function scrapeNcaa(): Promise<{ teams: Record<string, any>; unmapped: string[] }> {
  console.log('\n--- NCAA D1 ---');
  const teams: Record<string, any> = {};
  const allUnmapped: string[] = [];

  const conferenceUrls = NCAA_CONFERENCE_URLS;
  console.log(`  ${conferenceUrls.length} conference pages to fetch`);

  for (let i = 0; i < conferenceUrls.length; i++) {
    const url = conferenceUrls[i];
    const confName = url.split('/portfolio/')[1]?.slice(0, 50) || url;
    console.log(`  [${i + 1}/${conferenceUrls.length}] ${confName}...`);

    await delay(DELAY_MS);
    const html = await fetchPage(url);
    if (!html) continue;

    const parsed = parseTrucolorPage(html, NCAA_SCHOOL_ABBREVS, true);
    Object.assign(teams, parsed.teams);
    allUnmapped.push(...parsed.unmapped);

    if (Object.keys(parsed.teams).length === 0 && parsed.unmapped.length === 0) {
      console.log(`    ⚠ Zero teams parsed (HTML structure may have changed)`);
    } else {
      console.log(`    ${Object.keys(parsed.teams).length} teams, ${parsed.unmapped.length} unmapped`);
    }
  }

  console.log(`  Total NCAA: ${Object.keys(teams).length} schools`);
  return { teams, unmapped: allUnmapped };
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════╗');
  console.log('║       SCRAPE TEAM COLORS FROM TRUCOLOR.NET           ║');
  console.log('╚════════════════════════════════════════════════════════╝');

  const proTeams = await scrapeProLeagues();
  const ncaaResult = await scrapeNcaa();

  const output: Record<string, any> = {
    _meta: {
      source: 'TruColor.net',
      scrapedAt: new Date().toISOString(),
    },
    ...proTeams,
    ncaa: ncaaResult.teams,
  };

  // Write JSON
  const outPath = path.join(__dirname, '..', 'data', 'teamColors.json');
  const outDir = path.dirname(outPath);
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2) + '\n');

  // Summary
  console.log('\n╔════════════════════════════════════════════════════════╗');
  console.log('║                     SUMMARY                           ║');
  console.log('╚════════════════════════════════════════════════════════╝');
  let total = 0;
  for (const [league, teams] of Object.entries(output)) {
    if (league === '_meta') continue;
    const count = Object.keys(teams).length;
    total += count;
    console.log(`  ${league.toUpperCase().padEnd(6)} ${count} teams`);
  }
  console.log(`  ${'TOTAL'.padEnd(6)} ${total} teams`);
  console.log(`\n  Output: ${outPath}`);

  if (ncaaResult.unmapped.length > 0) {
    console.log(`\n⚠ ${ncaaResult.unmapped.length} unmapped NCAA schools:`);
    // Deduplicate
    const unique = [...new Set(ncaaResult.unmapped)].sort();
    unique.forEach(n => console.log(`  - ${n}`));
  }

  console.log('\n✓ Done!');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
