#!/usr/bin/env npx tsx
/**
 * Test ESPN's date range endpoint to see if bulk season fetch is possible
 * 
 * ESPN scoreboard endpoint supports date range queries:
 * GET https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=YYYYMMDD-YYYYMMDD
 * 
 * This script tests if ESPN returns full season data or limits results.
 * 
 * Usage: npx tsx scripts/testESPNDateRange.ts
 */

import axios from 'axios';

const ESPN_BASE = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard';

interface ESPNEvent {
  id: string;
  date: string;
  name: string;
  status: {
    type: {
      name: string;
      completed: boolean;
    };
  };
}

interface ESPNScoreboardResponse {
  events: ESPNEvent[];
  day?: { date: string };
}

async function testDateRange(startDate: string, endDate: string, description: string): Promise<void> {
  const url = `${ESPN_BASE}?dates=${startDate}-${endDate}`;
  
  console.log(`\n📅 Testing: ${description}`);
  console.log(`   URL: ${url}`);
  
  try {
    const start = Date.now();
    const response = await axios.get<ESPNScoreboardResponse>(url, {
      timeout: 30000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'BoxScore/1.0-DateRangeTest',
      },
    });
    const elapsed = Date.now() - start;
    
    const events = response.data.events || [];
    const uniqueDates = new Set(events.map(e => e.date.split('T')[0]));
    
    console.log(`   ✅ Success in ${elapsed}ms`);
    console.log(`   📊 Events returned: ${events.length}`);
    console.log(`   📆 Unique dates: ${uniqueDates.size}`);
    
    if (events.length > 0) {
      // Show date range of returned events
      const sortedDates = [...uniqueDates].sort();
      console.log(`   📍 First event date: ${sortedDates[0]}`);
      console.log(`   📍 Last event date: ${sortedDates[sortedDates.length - 1]}`);
      
      // Show status breakdown
      const completed = events.filter(e => e.status.type.completed).length;
      const scheduled = events.filter(e => !e.status.type.completed).length;
      console.log(`   🏀 Completed: ${completed}, Scheduled: ${scheduled}`);
    }
    
    return;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.log(`   ❌ Failed: ${error.response?.status} ${error.response?.statusText || error.message}`);
      if (error.response?.status === 429) {
        console.log(`   ⚠️  Rate limited - wait before retrying`);
      }
    } else {
      console.log(`   ❌ Failed: ${error}`);
    }
  }
}

async function testSingleDate(date: string, description: string): Promise<number> {
  const url = `${ESPN_BASE}?dates=${date}`;
  
  console.log(`\n📅 Testing: ${description}`);
  console.log(`   URL: ${url}`);
  
  try {
    const response = await axios.get<ESPNScoreboardResponse>(url, {
      timeout: 15000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'BoxScore/1.0-DateRangeTest',
      },
    });
    
    const events = response.data.events || [];
    console.log(`   ✅ Events: ${events.length}`);
    return events.length;
  } catch (error) {
    console.log(`   ❌ Failed`);
    return 0;
  }
}

async function main() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('ESPN Date Range Endpoint Test');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('\nTesting if ESPN supports bulk season schedule fetching...\n');
  
  // Test 1: Single day (baseline)
  await testSingleDate('20260113', 'Single day (Jan 13, 2026)');
  await sleep(1000);
  
  // Test 2: One week range
  await testDateRange('20260113', '20260119', 'One week (Jan 13-19, 2026)');
  await sleep(1000);
  
  // Test 3: One month range
  await testDateRange('20260101', '20260131', 'One month (January 2026)');
  await sleep(1000);
  
  // Test 4: Two month range
  await testDateRange('20260101', '20260228', 'Two months (Jan-Feb 2026)');
  await sleep(1000);
  
  // Test 5: Full season range (Oct 2025 - Jun 2026)
  await testDateRange('20251001', '20260630', 'Full season (Oct 2025 - Jun 2026)');
  await sleep(1000);
  
  // Test 6: Just regular season
  await testDateRange('20251022', '20260413', 'Regular season only (Oct 22 - Apr 13)');
  
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('Analysis');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`
Based on the results above:

- If full season range returns ALL games (~1230 regular season games):
  → Use Mode A: Single bulk fetch for entire season
  
- If results are truncated (e.g., only returns first N games or recent dates):
  → Use Mode B: Incremental discovery with rolling window
  
- If large ranges fail or time out:
  → Use Mode B: Fetch smaller chunks over multiple days

Recommendation: Check the "Events returned" count for each test.
A full NBA regular season has ~1230 games (82 games × 30 teams / 2).
If the full season test returns significantly fewer, ESPN limits results.
`);
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

main().catch(console.error);
