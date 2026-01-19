#!/usr/bin/env ts-node
import { config } from 'dotenv';
import { query, closePool } from '../db/pool';

config();

async function main() {
  const players = await query('SELECT id, display_name FROM players LIMIT 3');
  players.forEach(p => console.log(`${p.id} - ${p.display_name}`));
  await closePool();
}

main();
