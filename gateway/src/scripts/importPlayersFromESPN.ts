#!/usr/bin/env ts-node
/**
 * Import Players from ESPN Box Scores
 *
 * Fetches recent games from ESPN and extracts player bios.
 * Only stores player info (name, position, team) - stats are fetched on-demand.
 */

import { config as dotenvConfig } from 'dotenv';
import axios from 'axios';
import { closePool, query } from '../db/pool';
import { logger } from '../utils/logger';
import { upsertPlayer } from '../db/repositories/playerRepository';

dotenvConfig();

const ESPN_BASE_URL = 'https://site.api.espn.com/apis/site/v2/sports';
const ESPN_SUMMARY_URL = 'https://site.web.api.espn.com/apis/site/v2/sports';

interface ESPNGame {
  id: string;
  date: string;
  status: {
    type: {
      completed: boolean;
    };
  };
}

interface ESPNScoreboardResponse {
  events: ESPNGame[];
}

async function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Fetch scoreboard for a specific date
 */
async function fetchScoreboard(sportPath: string, date: string): Promise<ESPNGame[]> {
  try {
    const url = `${ESPN_BASE_URL}/${sportPath}/scoreboard?dates=${date}`;
    const response = await axios.get<ESPNScoreboardResponse>(url, { timeout: 30000 });
    return response.data.events || [];
  } catch (error) {
    logger.error('Failed to fetch ESPN scoreboard', { sportPath, date, error });
    return [];
  }
}

/**
 * Fetch box score summary for a game
 */
async function fetchBoxScore(sportPath: string, gameId: string): Promise<any | null> {
  try {
    const url = `${ESPN_SUMMARY_URL}/${sportPath}/summary?event=${gameId}`;
    const response = await axios.get(url, { timeout: 30000 });
    return response.data;
  } catch (error) {
    logger.error('Failed to fetch ESPN box score', { sportPath, gameId, error });
    return null;
  }
}

/**
 * Format date as YYYYMMDD for ESPN API
 */
function formatDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}${month}${day}`;
}

/**
 * Get dates for the last N days
 */
function getLastNDays(n: number): string[] {
  const dates: string[] = [];
  const today = new Date();

  for (let i = 0; i < n; i++) {
    const date = new Date(today);
    date.setDate(today.getDate() - i);
    dates.push(formatDate(date));
  }

  return dates;
}

interface LeagueConfig {
  name: string;
  sportPath: string;
  leaguePrefix: string;
}

const LEAGUES: LeagueConfig[] = [
  { name: 'NBA', sportPath: 'basketball/nba', leaguePrefix: 'nba' },
  { name: 'NFL', sportPath: 'football/nfl', leaguePrefix: 'nfl' },
];

/**
 * Extract first name from full name
 */
function extractFirstName(fullName: string): string | undefined {
  const parts = fullName.trim().split(' ');
  return parts.length > 1 ? parts.slice(0, -1).join(' ') : undefined;
}

/**
 * Extract last name from full name
 */
function extractLastName(fullName: string): string | undefined {
  const parts = fullName.trim().split(' ');
  return parts.length > 1 ? parts[parts.length - 1] : undefined;
}

/**
 * Extract players from a box score (bios only, no stats)
 */
async function extractPlayersFromBoxScore(
  summary: any,
  leaguePrefix: string
): Promise<number> {
  let count = 0;

  if (!summary.boxscore?.players?.length) {
    return 0;
  }

  for (const teamData of summary.boxscore.players) {
    const teamId = `${leaguePrefix}_${teamData.team.id}`;
    const stats = teamData.statistics?.[0];
    if (!stats?.athletes?.length) continue;

    for (const athlete of stats.athletes) {
      try {
        await upsertPlayer({
          sport: leaguePrefix,
          provider: 'espn',
          providerPlayerId: athlete.athlete.id,
          displayName: athlete.athlete.displayName,
          firstName: extractFirstName(athlete.athlete.displayName),
          lastName: extractLastName(athlete.athlete.displayName),
          jersey: athlete.athlete.jersey,
          position: athlete.athlete.position?.abbreviation,
          currentTeamId: teamId,
          isActive: true,
        });
        count++;
      } catch (error) {
        logger.error('Failed to upsert player', {
          playerId: athlete.athlete.id,
          playerName: athlete.athlete.displayName,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  return count;
}

async function importPlayersForLeague(
  league: LeagueConfig,
  daysBack: number
): Promise<{ games: number; players: number }> {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Importing ${league.name} players from last ${daysBack} days`);
  console.log(`${'='.repeat(60)}`);

  const dates = getLastNDays(daysBack);
  let totalGames = 0;
  const processedGames = new Set<string>();
  const processedPlayers = new Set<string>();

  for (const date of dates) {
    console.log(`\n[${date}] Fetching games...`);

    await delay(500);
    const games = await fetchScoreboard(league.sportPath, date);

    const completedGames = games.filter(g => g.status.type.completed);
    console.log(`  Found ${completedGames.length} completed games`);

    for (const game of completedGames) {
      if (processedGames.has(game.id)) continue;
      processedGames.add(game.id);

      await delay(300); // Rate limit

      const summary = await fetchBoxScore(league.sportPath, game.id);
      if (!summary) continue;

      try {
        const playerCount = await extractPlayersFromBoxScore(summary, league.leaguePrefix);
        totalGames++;
        console.log(`  ✓ Game ${game.id}: ${playerCount} players`);
      } catch (error) {
        console.log(`  ✗ Failed game ${game.id}`);
      }
    }
  }

  // Count unique players
  const playerCount = await query<{ count: string }>(`
    SELECT COUNT(*) as count FROM players WHERE sport = $1
  `, [league.leaguePrefix]);

  return { games: totalGames, players: parseInt(playerCount[0]?.count || '0', 10) };
}

async function main() {
  const args = process.argv.slice(2);
  const daysBack = parseInt(args[0]) || 14;
  const leagueFilter = args[1]?.toLowerCase();

  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║         IMPORT PLAYERS FROM ESPN BOX SCORES                ║');
  console.log('║         (Bios only - stats fetched on-demand)              ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log(`\nImporting from last ${daysBack} days`);

  const results: { league: string; games: number; players: number }[] = [];

  try {
    for (const league of LEAGUES) {
      if (leagueFilter && league.leaguePrefix !== leagueFilter) continue;
      const result = await importPlayersForLeague(league, daysBack);
      results.push({ league: league.name, ...result });
    }

    // Print summary
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║                      IMPORT SUMMARY                        ║');
    console.log('╚════════════════════════════════════════════════════════════╝');

    for (const result of results) {
      console.log(`\n${result.league}:`);
      console.log(`  Games processed: ${result.games}`);
      console.log(`  Total players:   ${result.players}`);
    }

    console.log('\n✓ Import completed successfully!');
    console.log('  Note: Season stats are fetched from ESPN on-demand when viewing profiles.');

  } catch (error) {
    console.error('\n✗ Import failed:', error instanceof Error ? error.message : String(error));
    process.exit(1);
  } finally {
    await closePool();
  }
}

main();
