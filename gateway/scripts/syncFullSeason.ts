#!/usr/bin/env npx tsx
/**
 * Sync Full NBA 2025-26 Season
 * 
 * This script populates the games and game_dates tables with all NBA season data.
 * It uses the incremental sync approach, fetching scoreboards for each date
 * in the season window.
 * 
 * Usage: npx tsx scripts/syncFullSeason.ts [--days-back N] [--days-forward N]
 * 
 * Options:
 *   --days-back N     Days before today to sync (default: full season)
 *   --days-forward N  Days after today to sync (default: full season)
 *   --dry-run         Don't make actual API calls, just show what would be done
 *   --verbose         Show detailed progress
 * 
 * Examples:
 *   npx tsx scripts/syncFullSeason.ts                    # Sync full season
 *   npx tsx scripts/syncFullSeason.ts --days-back 7      # Sync last week + future
 *   npx tsx scripts/syncFullSeason.ts --days-forward 30  # Sync past + next month
 */

import { 
  runIncrementalSync, 
  runFullSeasonSync,
  getScheduleSyncStats,
  getLeagueSeason,
} from '../src/jobs';
import { materializeGameDates, getGameDatesStats } from '../src/jobs';
import { resetESPNRateLimiter } from '../src/quota/ESPNRateLimiter';

// Parse command line arguments
function parseArgs(): {
  daysBack?: number;
  daysForward?: number;
  dryRun: boolean;
  verbose: boolean;
  resetLimits: boolean;
} {
  const args = process.argv.slice(2);
  const result = {
    daysBack: undefined as number | undefined,
    daysForward: undefined as number | undefined,
    dryRun: false,
    verbose: false,
    resetLimits: false,
  };
  
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--days-back':
        result.daysBack = parseInt(args[++i], 10);
        break;
      case '--days-forward':
        result.daysForward = parseInt(args[++i], 10);
        break;
      case '--dry-run':
        result.dryRun = true;
        break;
      case '--verbose':
        result.verbose = true;
        break;
      case '--reset-limits':
        result.resetLimits = true;
        break;
    }
  }
  
  return result;
}

async function main() {
  const args = parseArgs();
  const seasonId = 'nba_2025-26';
  
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('NBA 2025-26 Season Sync');
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
  
  // Default to full season coverage
  const daysBack = args.daysBack ?? Math.ceil((today.getTime() - seasonStart.getTime()) / (1000 * 60 * 60 * 24));
  const daysForward = args.daysForward ?? Math.ceil((seasonEnd.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
  
  console.log('🔧 Sync Configuration:');
  console.log(`   Days Back: ${daysBack}`);
  console.log(`   Days Forward: ${daysForward}`);
  console.log(`   Dry Run: ${args.dryRun}`);
  console.log(`   Verbose: ${args.verbose}`);
  console.log(`   Reset Limits: ${args.resetLimits}`);
  console.log('');
  
  // Reset rate limits if requested (for bulk syncs)
  if (args.resetLimits) {
    console.log('🔄 Resetting ESPN rate limiter...\n');
    resetESPNRateLimiter();
  }
  
  // Calculate expected date range
  const startDate = new Date(today);
  startDate.setDate(startDate.getDate() - daysBack);
  const endDate = new Date(today);
  endDate.setDate(endDate.getDate() + daysForward);
  
  // Clamp to season boundaries
  const effectiveStart = startDate < seasonStart ? seasonStart : startDate;
  const effectiveEnd = endDate > seasonEnd ? seasonEnd : endDate;
  
  const totalDays = Math.ceil((effectiveEnd.getTime() - effectiveStart.getTime()) / (1000 * 60 * 60 * 24)) + 1;
  
  console.log('📊 Effective Range:');
  console.log(`   Start: ${effectiveStart.toISOString().split('T')[0]}`);
  console.log(`   End: ${effectiveEnd.toISOString().split('T')[0]}`);
  console.log(`   Total Days: ${totalDays}`);
  console.log('');
  
  if (args.dryRun) {
    console.log('🔍 DRY RUN - No API calls will be made\n');
    
    // Show current stats
    const stats = getScheduleSyncStats();
    console.log('Current Store Stats:');
    console.log(`   Seasons: ${stats.seasons}`);
    console.log(`   Games: ${stats.games}`);
    console.log(`   Game Dates: ${stats.gameDates}`);
    console.log('');
    
    console.log(`Would sync ${totalDays} dates from ESPN API.`);
    console.log(`Estimated ESPN API calls: ${totalDays} (one per date)`);
    console.log('');
    return;
  }
  
  // Run the sync
  console.log('🚀 Starting sync...\n');
  
  const startTime = Date.now();
  
  const result = await runIncrementalSync('nba', daysBack, daysForward, seasonId);
  
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
  console.log(`   Total Games: ${finalStats.games}`);
  console.log(`   Total Game Dates: ${finalStats.gameDates}`);
  console.log('');
  
  console.log('📅 Game Dates Breakdown:');
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
  
  // Show sample of skipped dates (no games)
  const skipRates = result.results.filter(r => r.gamesFound === 0).length;
  if (skipRates > 0) {
    console.log(`📭 Dates with no games: ${skipRates}`);
  }
  
  console.log('✅ Sync complete!\n');
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
