#!/usr/bin/env npx tsx
/**
 * Sync Full NCAAF 2025 Season
 * 
 * This script populates the games and game_dates tables with all NCAAF season data.
 * 
 * Usage: npx tsx scripts/syncNCAAFSeason.ts [--reset-limits]
 */

import { 
  runIncrementalSync, 
  getScheduleSyncStats,
  getLeagueSeason,
} from '../src/jobs';
import { materializeGameDates, getGameDatesStats } from '../src/jobs';
import { resetESPNRateLimiter } from '../src/quota/ESPNRateLimiter';

// Parse command line arguments
function parseArgs(): { resetLimits: boolean } {
  const args = process.argv.slice(2);
  return {
    resetLimits: args.includes('--reset-limits'),
  };
}

async function main() {
  const args = parseArgs();
  const seasonId = 'ncaaf_2025';
  const league = 'ncaaf';
  
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('NCAAF 2025 Season Sync');
  console.log('═══════════════════════════════════════════════════════════════\n');
  
  // Show season info
  const season = getLeagueSeason(seasonId);
  if (!season) {
    console.error('❌ Season not found:', seasonId);
    process.exit(1);
  }
  
  console.log('📅 Season Info:');
  console.log(`   ID: ${season.id}`);
  console.log(`   Label: ${season.seasonLabel}`);
  console.log(`   Regular Season: ${season.startDate} to ${season.endDate}`);
  console.log(`   Preseason Start: ${season.preseasonStart || 'N/A'}`);
  console.log(`   Postseason End: ${season.postseasonEnd || 'N/A'}`);
  console.log(`   Status: ${season.status}`);
  console.log('');
  
  // Calculate date range
  const today = new Date();
  const seasonStart = new Date(season.preseasonStart || season.startDate);
  const seasonEnd = new Date(season.postseasonEnd || season.endDate);
  
  const daysBack = Math.ceil((today.getTime() - seasonStart.getTime()) / (1000 * 60 * 60 * 24));
  const daysForward = Math.ceil((seasonEnd.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
  
  console.log('🔧 Sync Configuration:');
  console.log(`   Days Back: ${daysBack}`);
  console.log(`   Days Forward: ${daysForward}`);
  console.log(`   Reset Limits: ${args.resetLimits}`);
  console.log('');
  
  // Reset rate limits if requested
  if (args.resetLimits) {
    console.log('🔄 Resetting ESPN rate limiter...\n');
    resetESPNRateLimiter();
  }
  
  // Run the sync
  console.log('🚀 Starting NCAAF sync...\n');
  
  const startTime = Date.now();
  
  const result = await runIncrementalSync(league, daysBack, daysForward, seasonId);
  
  // Materialize game_dates after sync
  console.log('\n📊 Materializing game_dates index...');
  const materializeResult = await materializeGameDates(seasonId);
  
  const endTime = Date.now();
  const totalDuration = endTime - startTime;
  
  // Print summary
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('Sync Summary');
  console.log('═══════════════════════════════════════════════════════════════\n');
  
  console.log('📈 Results:');
  console.log(`   Dates Processed: ${result.datesProcessed}`);
  console.log(`   Total Games Found: ${result.totalGamesFound}`);
  console.log(`   Games Upserted: ${result.totalGamesUpserted}`);
  console.log(`   Sync Duration: ${result.durationMs}ms`);
  console.log('');
  
  console.log('📊 Materialization:');
  console.log(`   Dates Processed: ${materializeResult.datesProcessed}`);
  console.log(`   Dates Created: ${materializeResult.datesCreated}`);
  console.log(`   Dates Updated: ${materializeResult.datesUpdated}`);
  console.log(`   Duration: ${materializeResult.durationMs}ms`);
  console.log('');
  
  // Show final stats
  const finalStats = getScheduleSyncStats();
  const gameDatesStats = getGameDatesStats(seasonId);
  
  console.log('📦 Final Store Stats:');
  console.log(`   Total Games (all sports): ${finalStats.games}`);
  console.log(`   Total Game Dates (all sports): ${finalStats.gameDates}`);
  console.log('');
  
  console.log('🏈 NCAAF Game Dates Breakdown:');
  console.log(`   Dates with Games: ${gameDatesStats.datesWithGames}`);
  console.log(`   Dates with Live Games: ${gameDatesStats.datesWithLiveGames}`);
  console.log(`   Dates All Final: ${gameDatesStats.datesAllFinal}`);
  console.log(`   Total Game Count: ${gameDatesStats.totalGameCount}`);
  console.log('');
  
  console.log(`⏱️  Total Duration: ${totalDuration}ms`);
  console.log('');
  
  if (result.errors.length > 0) {
    console.log('⚠️  Errors:');
    for (const error of result.errors.slice(0, 10)) {
      console.log(`   - ${error}`);
    }
    if (result.errors.length > 10) {
      console.log(`   ... and ${result.errors.length - 10} more`);
    }
    console.log('');
  }
  
  console.log('✅ NCAAF sync complete!\n');
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
