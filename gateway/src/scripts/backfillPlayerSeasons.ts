#!/usr/bin/env ts-node
/**
 * Backfill Player Season Summaries
 *
 * Fetches historical season-by-season stats from ESPN for all active NBA players
 * and upserts them into nba_player_season_summary.
 *
 * Usage:
 *   npx ts-node src/scripts/backfillPlayerSeasons.ts
 *   npx ts-node src/scripts/backfillPlayerSeasons.ts --force   # Re-fetch even if data exists
 */

import { config as dotenvConfig } from 'dotenv';
dotenvConfig();

import { closePool, query } from '../db/pool';
import { logger } from '../utils/logger';
import { fetchSeasonBySeasonStats } from '../providers/espnPlayerService';
import { upsertSeasonSummary } from '../db/repositories/playerRepository';

const CONCURRENCY = 3;
const DELAY_MS = 500;
const FORCE = process.argv.includes('--force');

interface PlayerRow {
  id: string;
  display_name: string;
  espn_id: string;
}

async function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function getActiveNBAPlayers(): Promise<PlayerRow[]> {
  const rows = await query<PlayerRow>(
    `SELECT p.id, p.display_name, e.provider_id AS espn_id
     FROM players p
     JOIN external_ids e ON e.internal_id = p.id
       AND e.entity_type = 'player'
       AND e.provider = 'espn'
     WHERE p.sport = 'nba'
       AND p.is_active = true
     ORDER BY p.display_name`
  );
  return rows;
}

async function playersWithExistingData(): Promise<Set<string>> {
  const rows = await query<{ player_id: string }>(
    `SELECT DISTINCT player_id FROM nba_player_season_summary`
  );
  return new Set(rows.map(r => r.player_id));
}

async function backfillPlayer(player: PlayerRow): Promise<number> {
  const { seasons } = await fetchSeasonBySeasonStats(player.espn_id);

  if (seasons.length === 0) return 0;

  // Get current season year to skip it (ESPN live data handles current season)
  const currentSeasonYear = getCurrentSeasonYear();

  let upserted = 0;
  for (const season of seasons) {
    // Skip current season - that comes from ESPN live data in the endpoint
    if (season.season >= currentSeasonYear) continue;

    await upsertSeasonSummary({
      playerId: player.id,
      season: season.season,
      teamId: season.teamAbbreviation || 'TOTAL',
      gamesPlayed: season.gamesPlayed,
      gamesStarted: season.gamesStarted,
      minutes: season.minutes,
      points: season.points,
      rebounds: season.rebounds,
      assists: season.assists,
      steals: season.steals,
      blocks: season.blocks,
      turnovers: season.turnovers,
      personalFouls: season.personalFouls,
      fgMade: season.fgMade,
      fgAttempted: season.fgAttempted,
      fgPct: season.fgPct,       // 0-100 scale, upsert converts to 0-1
      fg3Made: season.fg3Made,
      fg3Attempted: season.fg3Attempted,
      fg3Pct: season.fg3Pct,
      ftMade: season.ftMade,
      ftAttempted: season.ftAttempted,
      ftPct: season.ftPct,
      offRebounds: season.offRebounds,
      defRebounds: season.defRebounds,
    });
    upserted++;
  }

  return upserted;
}

function getCurrentSeasonYear(): number {
  const now = new Date();
  // NBA season starts in October, so Oct-Dec = next year's season
  return now.getMonth() >= 9 ? now.getFullYear() : now.getFullYear() - 1;
}

async function main() {
  logger.info(`Backfill player seasons${FORCE ? ' (FORCE mode)' : ''}`);

  const players = await getActiveNBAPlayers();
  logger.info(`Found ${players.length} active NBA players`);

  let skipSet = new Set<string>();
  if (!FORCE) {
    skipSet = await playersWithExistingData();
    logger.info(`Skipping ${skipSet.size} players with existing data`);
  }

  const toProcess = FORCE ? players : players.filter(p => !skipSet.has(p.id));
  logger.info(`Processing ${toProcess.length} players`);

  let processed = 0;
  let totalSeasons = 0;
  let errors = 0;

  // Process in batches of CONCURRENCY
  for (let i = 0; i < toProcess.length; i += CONCURRENCY) {
    const batch = toProcess.slice(i, i + CONCURRENCY);

    const results = await Promise.allSettled(
      batch.map(async (player) => {
        const count = await backfillPlayer(player);
        processed++;
        logger.info(
          `[${processed}/${toProcess.length}] Backfilled ${player.display_name} (${count} seasons)`
        );
        return count;
      })
    );

    for (const result of results) {
      if (result.status === 'fulfilled') {
        totalSeasons += result.value;
      } else {
        errors++;
        logger.error(`Backfill error: ${result.reason}`);
      }
    }

    if (i + CONCURRENCY < toProcess.length) {
      await delay(DELAY_MS);
    }
  }

  logger.info(
    `Done. Processed ${processed} players, ${totalSeasons} season rows, ${errors} errors.`
  );
}

main()
  .catch((err) => {
    logger.error('Backfill failed:', err);
    process.exitCode = 1;
  })
  .finally(() => closePool());
