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

export interface ESPNPlayerProfile {
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
  draft: { year: number; round?: number; selection?: number } | null;
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
      draft: athlete.draft?.year ? {
        year: athlete.draft.year,
        round: athlete.draft.round || undefined,
        selection: athlete.draft.selection || athlete.draft.pick || undefined,
      } : null,
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

// ===== Shared ESPN stats parsing =====

interface ESPNAveragesCategory {
  labels: string[];
  statistics: Array<{
    stats?: string[];
    displaySeason?: string;
    season?: string;
    type?: string;
    team?: { abbreviation?: string };
    teamAbbreviation?: string;
  }>;
}

/**
 * Fetch the ESPN /athletes/{id}/stats endpoint and extract the averages category.
 * Shared by both fetchESPNDetailedStats and fetchSeasonBySeasonStats.
 */
async function fetchAveragesCategory(espnPlayerId: string): Promise<ESPNAveragesCategory | null> {
  const url = `${ESPN_ATHLETE_URL}/${espnPlayerId}/stats`;
  const response = await axios.get(url, {
    timeout: 10000,
    headers: { 'Accept': 'application/json' },
  });

  const categories: Array<{ name: string; labels?: string[]; statistics?: ESPNAveragesCategory['statistics'] }> =
    response.data.categories || [];
  const averages = categories.find(c => c.name === 'averages');
  if (!averages) return null;

  const labels = averages.labels || [];
  const statistics = averages.statistics || [];
  if (labels.length === 0 || statistics.length === 0) return null;

  return { labels, statistics };
}

/** Parse a stat string from ESPN ("51.4") to a number, returning 0 on failure. */
function parseStatValue(val: string | undefined): number {
  if (!val) return 0;
  const num = parseFloat(val);
  return isNaN(num) ? 0 : num;
}

/** Build a label→value lookup from an ESPN stats entry. */
function buildStatLookup(labels: string[], stats: string[]): (label: string) => number {
  const indexMap = new Map(labels.map((l, i) => [l, i]));
  return (label: string): number => {
    const idx = indexMap.get(label);
    if (idx === undefined || idx >= stats.length) return 0;
    return parseStatValue(stats[idx]);
  };
}

/**
 * Fetch detailed season stats from ESPN stats endpoint.
 * Returns current (most recent) season stats with all shooting percentages.
 */
async function fetchESPNDetailedStats(espnPlayerId: string): Promise<ESPNSeasonStats | null> {
  try {
    const averages = await fetchAveragesCategory(espnPlayerId);
    if (!averages) {
      logger.debug('No averages category found in ESPN stats', { espnPlayerId });
      return null;
    }

    const latest = averages.statistics[averages.statistics.length - 1];
    const stats = latest.stats || [];
    if (stats.length === 0) return null;

    const stat = buildStatLookup(averages.labels, stats);

    return {
      gamesPlayed: stat('GP'),
      gamesStarted: stat('GS'),
      minutesPerGame: stat('MIN'),
      points: stat('PTS'),
      rebounds: stat('REB'),
      assists: stat('AST'),
      steals: stat('STL'),
      blocks: stat('BLK'),
      turnovers: stat('TO'),
      fgPct: stat('FG%'),
      fg3Pct: stat('3P%'),
      ftPct: stat('FT%'),
      fgm: 0, // combined format in ESPN response
      fga: 0,
      fg3m: 0,
      fg3a: 0,
      ftm: 0,
      fta: 0,
      oreb: stat('OR'),
      dreb: stat('DR'),
      pf: stat('PF'),
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
 * ESPN season-by-season stats for stat central
 */
export interface ESPNSeasonEntry {
  season: number;
  teamAbbreviation: string | null; // null for TOTAL rows
  gamesPlayed: number;
  gamesStarted: number;
  minutes: number;
  points: number;
  rebounds: number;
  assists: number;
  steals: number;
  blocks: number;
  turnovers: number;
  personalFouls: number;
  fgMade: number;
  fgAttempted: number;
  fgPct: number; // 0-100 scale
  fg3Made: number;
  fg3Attempted: number;
  fg3Pct: number; // 0-100 scale
  ftMade: number;
  ftAttempted: number;
  ftPct: number; // 0-100 scale
  offRebounds: number;
  defRebounds: number;
}

export interface ESPNStatCentralData {
  profile: ESPNPlayerProfile;
  seasons: ESPNSeasonEntry[];
  career: ESPNSeasonEntry | null;
}

/**
 * Fetch all season-by-season stats from ESPN's /athletes/{id}/stats endpoint.
 * Returns per-game averages for each season plus career totals.
 */
export async function fetchSeasonBySeasonStats(espnPlayerId: string): Promise<{ seasons: ESPNSeasonEntry[]; career: ESPNSeasonEntry | null }> {
  try {
    const averages = await fetchAveragesCategory(espnPlayerId);
    if (!averages) {
      logger.debug('No averages category found in ESPN stats', { espnPlayerId });
      return { seasons: [], career: null };
    }

    const seasons: ESPNSeasonEntry[] = [];
    let career: ESPNSeasonEntry | null = null;

    for (const seasonEntry of averages.statistics) {
      const stats = seasonEntry.stats || [];
      if (stats.length === 0) continue;

      const stat = buildStatLookup(averages.labels, stats);

      const row: ESPNSeasonEntry = {
        season: 0,
        teamAbbreviation: null,
        gamesPlayed: stat('GP'),
        gamesStarted: stat('GS'),
        minutes: stat('MIN'),
        points: stat('PTS'),
        rebounds: stat('REB'),
        assists: stat('AST'),
        steals: stat('STL'),
        blocks: stat('BLK'),
        turnovers: stat('TO'),
        personalFouls: stat('PF'),
        fgMade: stat('FGM'),
        fgAttempted: stat('FGA'),
        fgPct: stat('FG%'),
        fg3Made: stat('3PM'),
        fg3Attempted: stat('3PA'),
        fg3Pct: stat('3P%'),
        ftMade: stat('FTM'),
        ftAttempted: stat('FTA'),
        ftPct: stat('FT%'),
        offRebounds: stat('OR'),
        defRebounds: stat('DR'),
      };

      const displaySeason = seasonEntry.displaySeason || seasonEntry.season || '';

      // Career row
      if (seasonEntry.type === 'career' || displaySeason === 'Career' || displaySeason === 'career') {
        career = { ...row, season: 0, teamAbbreviation: null };
        continue;
      }

      // Parse season year from "2025-26" -> 2025
      const seasonMatch = String(displaySeason).match(/^(\d{4})/);
      if (seasonMatch) {
        row.season = parseInt(seasonMatch[1], 10);
      } else {
        const numSeason = parseInt(String(seasonEntry.season), 10);
        if (!isNaN(numSeason)) {
          row.season = numSeason;
        } else {
          continue;
        }
      }

      row.teamAbbreviation = seasonEntry.team?.abbreviation || seasonEntry.teamAbbreviation || null;
      seasons.push(row);
    }

    seasons.sort((a, b) => b.season - a.season);
    return { seasons, career };
  } catch (error) {
    logger.debug('Failed to fetch ESPN season-by-season stats', {
      espnPlayerId,
      error: error instanceof Error ? error.message : String(error),
    });
    return { seasons: [], career: null };
  }
}

/**
 * Fetch complete stat central data for a player from ESPN.
 * Returns profile, all seasons, and career averages.
 */
export async function getStatCentralFromESPN(internalPlayerId: string): Promise<ESPNStatCentralData | null> {
  const espnId = await getESPNPlayerId(internalPlayerId);
  if (!espnId) {
    logger.warn('No ESPN ID found for player', { internalPlayerId });
    return null;
  }

  const [profile, seasonData] = await Promise.all([
    fetchESPNPlayerStats(espnId),
    fetchSeasonBySeasonStats(espnId),
  ]);

  if (!profile) return null;

  // If the season-by-season endpoint returned no data, fall back to
  // the current season stats from the profile as the only season
  if (seasonData.seasons.length === 0 && profile.currentSeasonStats) {
    const now = new Date();
    const currentSeason = now.getMonth() >= 9 ? now.getFullYear() : now.getFullYear() - 1;
    const cs = profile.currentSeasonStats;
    seasonData.seasons.push({
      season: currentSeason,
      teamAbbreviation: profile.team?.abbreviation || null,
      gamesPlayed: cs.gamesPlayed,
      gamesStarted: cs.gamesStarted,
      minutes: cs.minutesPerGame,
      points: cs.points,
      rebounds: cs.rebounds,
      assists: cs.assists,
      steals: cs.steals,
      blocks: cs.blocks,
      turnovers: cs.turnovers,
      personalFouls: cs.pf,
      fgMade: cs.fgm,
      fgAttempted: cs.fga,
      fgPct: cs.fgPct,
      fg3Made: cs.fg3m,
      fg3Attempted: cs.fg3a,
      fg3Pct: cs.fg3Pct,
      ftMade: cs.ftm,
      ftAttempted: cs.fta,
      ftPct: cs.ftPct,
      offRebounds: cs.oreb,
      defRebounds: cs.dreb,
    });
  }

  return {
    profile,
    seasons: seasonData.seasons,
    career: seasonData.career,
  };
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
