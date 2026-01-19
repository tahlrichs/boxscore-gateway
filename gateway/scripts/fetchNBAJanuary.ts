#!/usr/bin/env npx tsx
/**
 * Fetch all NBA games for January 2026
 * Usage: npx tsx scripts/fetchNBAJanuary.ts
 */

import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';

const GATEWAY_URL = 'http://localhost:3001';
const OUTPUT_DIR = path.join(__dirname, '../data/nba/january2026');

interface Game {
  id: string;
  startTime: string;
  status: 'scheduled' | 'live' | 'final';
  homeTeam: { abbrev: string; name: string; score: number };
  awayTeam: { abbrev: string; name: string; score: number };
}

interface ScoreboardResponse {
  data: {
    league: string;
    date: string;
    lastUpdated: string;
    games: Game[];
  };
}

interface BoxScoreResponse {
  data: {
    game: Game;
    boxScore: any;
    lastUpdated: string;
  };
}

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchScoreboard(date: string): Promise<Game[]> {
  try {
    const response = await axios.get<ScoreboardResponse>(
      `${GATEWAY_URL}/v1/scoreboard?league=nba&date=${date}`
    );
    return response.data.data.games;
  } catch (error) {
    console.error(`Failed to fetch scoreboard for ${date}:`, error);
    return [];
  }
}

async function fetchBoxScore(gameId: string): Promise<any | null> {
  try {
    const response = await axios.get<BoxScoreResponse>(
      `${GATEWAY_URL}/v1/games/${gameId}/boxscore`
    );
    return response.data.data;
  } catch (error) {
    console.error(`Failed to fetch box score for ${gameId}:`, error);
    return null;
  }
}

function getJanuaryDates(): string[] {
  const dates: string[] = [];
  for (let day = 1; day <= 31; day++) {
    const date = `2026-01-${day.toString().padStart(2, '0')}`;
    dates.push(date);
  }
  return dates;
}

async function main() {
  console.log('🏀 Fetching NBA data for January 2026...\n');

  // Create output directory
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const dates = getJanuaryDates();
  const allGames: Record<string, Game[]> = {};
  const allBoxScores: Record<string, any> = {};

  let totalGames = 0;
  let finalGames = 0;
  let scheduledGames = 0;

  // Fetch scoreboards for all dates
  console.log('📅 Fetching scoreboards for all January dates...\n');
  
  for (const date of dates) {
    const games = await fetchScoreboard(date);
    allGames[date] = games;
    
    totalGames += games.length;
    finalGames += games.filter(g => g.status === 'final').length;
    scheduledGames += games.filter(g => g.status === 'scheduled').length;
    
    if (games.length > 0) {
      console.log(`  ${date}: ${games.length} games (${games.filter(g => g.status === 'final').length} final, ${games.filter(g => g.status === 'scheduled').length} scheduled)`);
    }
    
    // Small delay to be nice to the API
    await sleep(100);
  }

  console.log(`\n📊 Summary: ${totalGames} total games (${finalGames} final, ${scheduledGames} scheduled)\n`);

  // Fetch box scores for completed games
  console.log('📦 Fetching box scores for completed games...\n');
  
  const completedGames = Object.values(allGames)
    .flat()
    .filter(g => g.status === 'final');

  let boxScoreCount = 0;
  for (const game of completedGames) {
    const boxScore = await fetchBoxScore(game.id);
    if (boxScore) {
      allBoxScores[game.id] = boxScore;
      boxScoreCount++;
      
      const home = game.homeTeam;
      const away = game.awayTeam;
      console.log(`  ✅ ${away.abbrev} ${away.score} @ ${home.abbrev} ${home.score}`);
    }
    
    // Rate limit
    await sleep(200);
  }

  console.log(`\n📦 Fetched ${boxScoreCount} box scores\n`);

  // Save data to files
  console.log('💾 Saving data to files...\n');

  // Save all scoreboards
  const scoreboardsPath = path.join(OUTPUT_DIR, 'scoreboards.json');
  fs.writeFileSync(scoreboardsPath, JSON.stringify(allGames, null, 2));
  console.log(`  Saved scoreboards to ${scoreboardsPath}`);

  // Save all box scores
  const boxScoresPath = path.join(OUTPUT_DIR, 'boxscores.json');
  fs.writeFileSync(boxScoresPath, JSON.stringify(allBoxScores, null, 2));
  console.log(`  Saved box scores to ${boxScoresPath}`);

  // Save summary
  const summary = {
    fetchedAt: new Date().toISOString(),
    month: 'January 2026',
    totalGames,
    finalGames,
    scheduledGames,
    boxScoresCount: boxScoreCount,
    dates: dates.map(date => ({
      date,
      gameCount: allGames[date]?.length || 0,
      games: allGames[date]?.map(g => ({
        id: g.id,
        status: g.status,
        matchup: `${g.awayTeam.abbrev} @ ${g.homeTeam.abbrev}`,
        score: g.status === 'final' ? `${g.awayTeam.score}-${g.homeTeam.score}` : 'TBD',
      })) || [],
    })),
  };

  const summaryPath = path.join(OUTPUT_DIR, 'summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  console.log(`  Saved summary to ${summaryPath}`);

  console.log('\n✅ Done! All January 2026 NBA data has been fetched.\n');
}

main().catch(console.error);
