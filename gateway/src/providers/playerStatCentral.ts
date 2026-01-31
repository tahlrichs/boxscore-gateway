/**
 * Stat Central Data Assembly
 *
 * Merges historical seasons (Supabase) with current season (ESPN)
 * and computes career averages. Extracted from playerRoutes.ts.
 */

import { getPlayerById } from '../db/repositories/playerRepository';
import { getHistoricalSeasons } from '../db/repositories/playerRepository';
import { getStatCentralFromESPN, ESPNPlayerProfile } from './espnPlayerService';
import { NotFoundError } from '../middleware/errorHandler';
import { StatCentralData, StatCentralPlayer, SeasonRow, seasonLabel } from '../types/statCentral';

/**
 * Get current NBA season based on current date.
 * October-December = current year's season; January-September = previous year's.
 */
function getCurrentSeason(): number {
  const now = new Date();
  return now.getMonth() >= 9 ? now.getFullYear() : now.getFullYear() - 1;
}

/** Round to 1 decimal place */
function round1(val: number | undefined | null): number {
  if (val === undefined || val === null || isNaN(val)) return 0;
  return Math.round(val * 10) / 10;
}

/**
 * Build draft summary string from ESPN profile data.
 * Returns "2020 · Round 1 · Pick 21" or null if undrafted/unknown.
 */
function buildDraftSummary(profile: ESPNPlayerProfile | undefined | null): string | null {
  if (!profile) return null;
  const draft = profile.draft;
  if (!draft) return null;
  const { year, round, selection } = draft;
  if (!year) return null;
  if (round && selection) return `${year} · Round ${round} · Pick ${selection}`;
  if (round) return `${year} · Round ${round}`;
  return `${year}`;
}

type NumericSeasonField = 'ppg' | 'rpg' | 'apg' | 'spg' | 'fgPct' | 'ftPct';

/**
 * Compute career averages from season rows when ESPN doesn't provide them.
 * Weighted average by games played. Uses TOTAL rows only to avoid
 * double-counting traded players.
 */
function computeCareerFromSeasons(seasons: SeasonRow[]): SeasonRow {
  const totalRows = seasons.filter(s => s.teamAbbreviation === null);
  const rows = totalRows.length > 0 ? totalRows : seasons;
  const totalGP = rows.reduce((sum, s) => sum + s.gamesPlayed, 0);

  if (totalGP === 0) {
    return {
      seasonLabel: 'Career',
      teamAbbreviation: null,
      gamesPlayed: 0,
      ppg: 0, rpg: 0, apg: 0, spg: 0, fgPct: 0, ftPct: 0,
    };
  }

  const weightedAvg = (field: NumericSeasonField) =>
    round1(rows.reduce((sum, s) => sum + s[field] * s.gamesPlayed, 0) / totalGP);

  return {
    seasonLabel: 'Career',
    teamAbbreviation: null,
    gamesPlayed: totalGP,
    ppg: weightedAvg('ppg'),
    rpg: weightedAvg('rpg'),
    apg: weightedAvg('apg'),
    spg: weightedAvg('spg'),
    fgPct: weightedAvg('fgPct'),
    ftPct: weightedAvg('ftPct'),
  };
}

/**
 * Build the complete stat-central dataset for a player.
 * Fetches data in parallel from DB and ESPN, merges seasons,
 * and computes career averages.
 */
export async function buildStatCentral(playerId: string): Promise<StatCentralData> {
  const [player, historicalSeasons, espnData] = await Promise.all([
    getPlayerById(playerId),
    getHistoricalSeasons(playerId),
    getStatCentralFromESPN(playerId),
  ]);

  if (!player) {
    throw new NotFoundError(`Player not found: ${playerId}`);
  }

  const currentSeason = getCurrentSeason();

  const statCentralPlayer: StatCentralPlayer = {
    id: player.id,
    displayName: player.display_name,
    jersey: espnData?.profile.jersey || player.jersey || '',
    position: espnData?.profile.position || player.position || '',
    teamName: espnData?.profile.team?.name || '',
    teamAbbreviation: espnData?.profile.team?.abbreviation || '',
    headshot: espnData?.profile.headshot || player.headshot_url || null,
    college: espnData?.profile.college || player.school || null,
    hometown: player.hometown || null,
    draftSummary: buildDraftSummary(espnData?.profile),
  };

  // Build season rows: merge historical (Supabase) + current (ESPN)
  const seasons: SeasonRow[] = [];

  // Historical seasons from Supabase (completed seasons only)
  for (const hs of historicalSeasons) {
    if (hs.season >= currentSeason) continue; // skip current season, ESPN has fresher data
    seasons.push({
      seasonLabel: seasonLabel(hs.season),
      teamAbbreviation: !hs.team_id || hs.team_id === 'TOTAL' ? null : hs.team_id,
      gamesPlayed: hs.games_played || 0,
      ppg: round1(hs.ppg),
      rpg: round1(hs.rpg),
      apg: round1(hs.apg),
      spg: round1(hs.games_played && hs.stl ? hs.stl / hs.games_played : 0),
      fgPct: round1((hs.fg_pct || 0) * 100), // DB stores 0-1, API returns 0-100
      ftPct: round1((hs.ft_pct || 0) * 100),
    });
  }

  // Current season + any ESPN seasons not in Supabase
  if (espnData) {
    for (const es of espnData.seasons) {
      const alreadyInDb = historicalSeasons.some(
        hs => hs.season === es.season && hs.season < currentSeason
      );
      if (alreadyInDb) continue;

      seasons.push({
        seasonLabel: seasonLabel(es.season),
        teamAbbreviation: es.teamAbbreviation || null,
        gamesPlayed: es.gamesPlayed,
        ppg: round1(es.ppg),
        rpg: round1(es.rpg),
        apg: round1(es.apg),
        spg: round1(es.spg),
        fgPct: round1(es.fgPct),
        ftPct: round1(es.ftPct),
      });
    }
  }

  seasons.sort((a, b) => b.seasonLabel.localeCompare(a.seasonLabel));

  // Career row: prefer ESPN, fallback to weighted average from seasons
  let career: SeasonRow;
  if (espnData?.career) {
    career = {
      seasonLabel: 'Career',
      teamAbbreviation: null,
      gamesPlayed: espnData.career.gamesPlayed,
      ppg: round1(espnData.career.ppg),
      rpg: round1(espnData.career.rpg),
      apg: round1(espnData.career.apg),
      spg: round1(espnData.career.spg),
      fgPct: round1(espnData.career.fgPct),
      ftPct: round1(espnData.career.ftPct),
    };
  } else {
    career = computeCareerFromSeasons(seasons);
  }

  return { player: statCentralPlayer, seasons, career };
}
