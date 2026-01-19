/**
 * ESPN Player Service
 *
 * Fetches player stats directly from ESPN API on-demand.
 * No local computation - uses ESPN's pre-computed stats.
 */

import axios from 'axios';
import { logger } from '../utils/logger';
import { query } from '../db/pool';

const ESPN_ATHLETE_URL = 'https://site.web.api.espn.com/apis/common/v3/sports/basketball/nba/athletes';
const ESPN_STATS_URL = 'https://site.web.api.espn.com/apis/common/v3/sports/basketball/nba/athletes';

interface ESPNSeasonStats {
  gamesPlayed: number;
  gamesStarted: number;
  minutesPerGame: number;
  points: number;
  rebounds: number;
  assists: number;
  steals: number;
  blocks: number;
  turnovers: number;
  fgPct: number;
  fg3Pct: number;
  ftPct: number;
  fgm: number;
  fga: number;
  fg3m: number;
  fg3a: number;
  ftm: number;
  fta: number;
  oreb: number;
  dreb: number;
  pf: number;
}

interface ESPNPlayerProfile {
  id: string;
  displayName: string;
  firstName: string;
  lastName: string;
  jersey: string;
  position: string;
  team: {
    id: string;
    name: string;
    abbreviation: string;
  } | null;
  headshot: string | null;
  height: string;
  weight: string;
  birthDate: string | null;
  college: string | null;
  currentSeasonStats: ESPNSeasonStats | null;
}

/**
 * Get ESPN player ID from our internal ID
 */
export async function getESPNPlayerId(internalId: string): Promise<string | null> {
  const result = await query<{ provider_id: string }>(`
    SELECT provider_id FROM external_ids
    WHERE internal_id = $1 AND entity_type = 'player' AND provider = 'espn'
    LIMIT 1
  `, [internalId]);

  return result[0]?.provider_id || null;
}

/**
 * Fetch player profile and stats directly from ESPN
 */
export async function fetchESPNPlayerStats(espnPlayerId: string): Promise<ESPNPlayerProfile | null> {
  try {
    const url = `${ESPN_ATHLETE_URL}/${espnPlayerId}`;
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'Accept': 'application/json',
      },
    });

    const data = response.data;
    const athlete = data.athlete;

    if (!athlete) {
      logger.warn('No athlete data in ESPN response', { espnPlayerId });
      return null;
    }

    // Extract current season stats from the statistics array
    let currentSeasonStats: ESPNSeasonStats | null = null;

    // Check athlete.statsSummary.statistics (primary location)
    if (athlete.statsSummary?.statistics) {
      currentSeasonStats = parseESPNStatsSummary(athlete.statsSummary.statistics);
    }

    // Fallback: Look for current season stats in categories
    if (!currentSeasonStats) {
      const categories = data.athlete?.categories || [];
      for (const category of categories) {
        if (category.name === 'statistics' && category.categories) {
          const avgCategory = category.categories.find((c: any) => c.name === 'averages');
          if (avgCategory?.statistics) {
            currentSeasonStats = parseESPNStats(avgCategory.statistics);
            break;
          }
        }
      }
    }

    // Fallback: Check the statistics object directly
    if (!currentSeasonStats && data.statistics) {
      const splits = data.statistics.splits || [];
      const perGameSplit = splits.find((s: any) => s.name === 'perGame' || s.displayName === 'Per Game');
      if (perGameSplit?.stats) {
        currentSeasonStats = parseESPNStatsArray(perGameSplit.stats, perGameSplit.labels || []);
      }
    }

    // Fallback: Try to get stats from the athlete.statistics object
    if (!currentSeasonStats && athlete.statistics) {
      const stats = athlete.statistics;
      if (Array.isArray(stats) && stats.length > 0) {
        const latestStats = stats[0];
        if (latestStats.splits) {
          const perGame = latestStats.splits.find((s: any) =>
            s.abbreviation === 'Total' || s.name === 'perGame'
          );
          if (perGame?.stats) {
            currentSeasonStats = parseESPNStatsArray(perGame.stats, latestStats.labels || []);
          }
        }
      }
    }

    return {
      id: athlete.id,
      displayName: athlete.displayName,
      firstName: athlete.firstName,
      lastName: athlete.lastName,
      jersey: athlete.jersey || '',
      position: athlete.position?.abbreviation || athlete.position?.name || '',
      team: athlete.team ? {
        id: athlete.team.id,
        name: athlete.team.displayName || athlete.team.name,
        abbreviation: athlete.team.abbreviation,
      } : null,
      headshot: athlete.headshot?.href || null,
      height: athlete.displayHeight || '',
      weight: athlete.displayWeight || '',
      birthDate: athlete.dateOfBirth || null,
      college: athlete.college?.name || null,
      currentSeasonStats,
    };

  } catch (error) {
    if (axios.isAxiosError(error) && error.response?.status === 404) {
      logger.warn('ESPN player not found', { espnPlayerId });
      return null;
    }
    logger.error('Failed to fetch ESPN player stats', {
      espnPlayerId,
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

/**
 * Parse ESPN stats from statsSummary.statistics array
 * This is the primary format returned by the ESPN athlete endpoint
 */
function parseESPNStatsSummary(statistics: any[]): ESPNSeasonStats {
  const getStat = (name: string, abbrev?: string): number => {
    const stat = statistics.find((s: any) =>
      s.name === name || s.abbreviation === abbrev
    );
    return stat?.value !== undefined ? parseFloat(stat.value) : 0;
  };

  return {
    gamesPlayed: 0, // Not directly in statsSummary, would need to fetch separately
    gamesStarted: 0,
    minutesPerGame: getStat('avgMinutes', 'MIN'),
    points: getStat('avgPoints', 'PTS'),
    rebounds: getStat('avgRebounds', 'REB'),
    assists: getStat('avgAssists', 'AST'),
    steals: getStat('avgSteals', 'STL'),
    blocks: getStat('avgBlocks', 'BLK'),
    turnovers: getStat('avgTurnovers', 'TO'),
    fgPct: getStat('fieldGoalPct', 'FG%'),
    fg3Pct: getStat('threePointFieldGoalPct', '3P%'),
    ftPct: getStat('freeThrowPct', 'FT%'),
    fgm: 0, // Total stats not in summary
    fga: 0,
    fg3m: 0,
    fg3a: 0,
    ftm: 0,
    fta: 0,
    oreb: 0,
    dreb: 0,
    pf: 0,
  };
}

/**
 * Parse ESPN stats from statistics object
 */
function parseESPNStats(statistics: any[]): ESPNSeasonStats {
  const getStat = (name: string): number => {
    const stat = statistics.find((s: any) => s.name === name || s.abbreviation === name);
    return stat?.value ? parseFloat(stat.value) : 0;
  };

  return {
    gamesPlayed: getStat('games') || getStat('GP') || 0,
    gamesStarted: getStat('gamesStarted') || getStat('GS') || 0,
    minutesPerGame: getStat('minutes') || getStat('MIN') || 0,
    points: getStat('points') || getStat('PTS') || 0,
    rebounds: getStat('rebounds') || getStat('REB') || 0,
    assists: getStat('assists') || getStat('AST') || 0,
    steals: getStat('steals') || getStat('STL') || 0,
    blocks: getStat('blocks') || getStat('BLK') || 0,
    turnovers: getStat('turnovers') || getStat('TO') || 0,
    fgPct: getStat('fieldGoalPct') || getStat('FG%') || 0,
    fg3Pct: getStat('threePointFieldGoalPct') || getStat('3P%') || 0,
    ftPct: getStat('freeThrowPct') || getStat('FT%') || 0,
    fgm: getStat('fieldGoalsMade') || getStat('FGM') || 0,
    fga: getStat('fieldGoalsAttempted') || getStat('FGA') || 0,
    fg3m: getStat('threePointFieldGoalsMade') || getStat('3PM') || 0,
    fg3a: getStat('threePointFieldGoalsAttempted') || getStat('3PA') || 0,
    ftm: getStat('freeThrowsMade') || getStat('FTM') || 0,
    fta: getStat('freeThrowsAttempted') || getStat('FTA') || 0,
    oreb: getStat('offensiveRebounds') || getStat('OREB') || 0,
    dreb: getStat('defensiveRebounds') || getStat('DREB') || 0,
    pf: getStat('fouls') || getStat('PF') || 0,
  };
}

/**
 * Parse ESPN stats from stats array with labels
 */
function parseESPNStatsArray(stats: (string | number)[], labels: string[]): ESPNSeasonStats {
  const getStatByLabel = (label: string): number => {
    const idx = labels.indexOf(label);
    if (idx === -1) return 0;
    const val = stats[idx];
    return typeof val === 'number' ? val : parseFloat(String(val)) || 0;
  };

  return {
    gamesPlayed: getStatByLabel('GP'),
    gamesStarted: getStatByLabel('GS'),
    minutesPerGame: getStatByLabel('MIN'),
    points: getStatByLabel('PTS'),
    rebounds: getStatByLabel('REB'),
    assists: getStatByLabel('AST'),
    steals: getStatByLabel('STL'),
    blocks: getStatByLabel('BLK'),
    turnovers: getStatByLabel('TO'),
    fgPct: getStatByLabel('FG%'),
    fg3Pct: getStatByLabel('3P%'),
    ftPct: getStatByLabel('FT%'),
    fgm: getStatByLabel('FGM'),
    fga: getStatByLabel('FGA'),
    fg3m: getStatByLabel('3PM'),
    fg3a: getStatByLabel('3PA'),
    ftm: getStatByLabel('FTM'),
    fta: getStatByLabel('FTA'),
    oreb: getStatByLabel('OREB'),
    dreb: getStatByLabel('DREB'),
    pf: getStatByLabel('PF'),
  };
}

/**
 * Fetch detailed season stats from ESPN stats endpoint
 * Returns current season stats with all shooting percentages
 */
async function fetchESPNDetailedStats(espnPlayerId: string): Promise<ESPNSeasonStats | null> {
  try {
    const url = `${ESPN_STATS_URL}/${espnPlayerId}/stats`;
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'Accept': 'application/json',
      },
    });

    const data = response.data;
    const categories = data.categories || [];

    // Find the 'averages' category which has per-game stats
    const averagesCategory = categories.find((c: any) => c.name === 'averages');
    if (!averagesCategory) {
      logger.debug('No averages category found in ESPN stats', { espnPlayerId });
      return null;
    }

    const labels = averagesCategory.labels || [];
    const statistics = averagesCategory.statistics || [];

    // Get the most recent season (last in array)
    if (statistics.length === 0) {
      logger.debug('No season statistics found', { espnPlayerId });
      return null;
    }

    const currentSeason = statistics[statistics.length - 1];
    const stats = currentSeason.stats || [];

    if (labels.length === 0 || stats.length === 0) {
      return null;
    }

    // Create a stats lookup
    const statLookup: Record<string, string> = {};
    labels.forEach((label: string, idx: number) => {
      statLookup[label] = stats[idx] || '0';
    });

    // Parse percentage - ESPN returns them as strings like "51.4"
    const parsePct = (val: string): number => {
      const num = parseFloat(val);
      return isNaN(num) ? 0 : num;
    };

    // Parse number - ESPN returns them as strings
    const parseNum = (val: string): number => {
      const num = parseFloat(val);
      return isNaN(num) ? 0 : num;
    };

    return {
      gamesPlayed: parseNum(statLookup['GP'] || '0'),
      gamesStarted: parseNum(statLookup['GS'] || '0'),
      minutesPerGame: parseNum(statLookup['MIN'] || '0'),
      points: parseNum(statLookup['PTS'] || '0'),
      rebounds: parseNum(statLookup['REB'] || '0'),
      assists: parseNum(statLookup['AST'] || '0'),
      steals: parseNum(statLookup['STL'] || '0'),
      blocks: parseNum(statLookup['BLK'] || '0'),
      turnovers: parseNum(statLookup['TO'] || '0'),
      fgPct: parsePct(statLookup['FG%'] || '0'),
      fg3Pct: parsePct(statLookup['3P%'] || '0'),
      ftPct: parsePct(statLookup['FT%'] || '0'),
      fgm: 0, // These are in combined format like "8.4-16.3"
      fga: 0,
      fg3m: 0,
      fg3a: 0,
      ftm: 0,
      fta: 0,
      oreb: parseNum(statLookup['OR'] || '0'),
      dreb: parseNum(statLookup['DR'] || '0'),
      pf: parseNum(statLookup['PF'] || '0'),
    };
  } catch (error) {
    logger.debug('Failed to fetch ESPN detailed stats', {
      espnPlayerId,
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

/**
 * Get player stats - fetches from ESPN on-demand
 * Uses both athlete endpoint (for bio) and stats endpoint (for complete stats)
 */
export async function getPlayerStats(internalPlayerId: string): Promise<ESPNPlayerProfile | null> {
  const espnId = await getESPNPlayerId(internalPlayerId);

  if (!espnId) {
    logger.warn('No ESPN ID found for player', { internalPlayerId });
    return null;
  }

  // Fetch both endpoints in parallel
  const [profile, detailedStats] = await Promise.all([
    fetchESPNPlayerStats(espnId),
    fetchESPNDetailedStats(espnId),
  ]);

  if (!profile) {
    return null;
  }

  // If we got detailed stats, use those (they have 3P% and FT%)
  // Otherwise fall back to what the athlete endpoint provided
  if (detailedStats) {
    profile.currentSeasonStats = detailedStats;
  }

  return profile;
}
