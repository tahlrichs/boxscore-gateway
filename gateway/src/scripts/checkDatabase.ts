#!/usr/bin/env ts-node
/**
 * Check Database Contents
 */

import { config } from 'dotenv';
import { query, closePool } from '../db/pool';

config();

async function check() {
  try {
    const players = await query('SELECT COUNT(*) as count FROM players');
    const gameLogs = await query('SELECT COUNT(*) as count FROM nba_player_game_logs');
    const seasonSummaries = await query('SELECT COUNT(*) as count FROM nba_player_season_summary');
    const splits = await query('SELECT COUNT(*) as count FROM nba_player_splits');

    console.log('Database Contents:');
    console.log('==================');
    console.log(`Players: ${players[0].count}`);
    console.log(`Game logs: ${gameLogs[0].count}`);
    console.log(`Season summaries: ${seasonSummaries[0].count}`);
    console.log(`Splits: ${splits[0].count}`);

    if (parseInt(players[0].count) > 0) {
      const samplePlayers = await query('SELECT id, display_name, position, current_team_id FROM players LIMIT 5');
      console.log('\nSample Players:');
      for (const p of samplePlayers) {
        console.log(`  - ${p.display_name} (${p.position}) - Team: ${p.current_team_id}`);
      }
    }

    await closePool();
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    await closePool();
    process.exit(1);
  }
}

check();
