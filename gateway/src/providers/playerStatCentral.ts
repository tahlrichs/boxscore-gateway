/**
 * Stat Central Data Assembly
 *
 * Merges historical seasons (Supabase) with current season (ESPN)
 * and computes career averages. Extracted from playerRoutes.ts.
 */

import { getPlayerById, getHistoricalSeasons } from '../db/repositories/playerRepository';
import { getStatCentralFromESPN, ESPNPlayerProfile, ESPNSeasonEntry } from './espnPlayerService';
import { NotFoundError } from '../middleware/errorHandler';
import { StatCentralData, StatCentralPlayer, SeasonRow } from '../types/statCentral';
import { getCurrentSeason, seasonLabel } from '../utils/seasonUtils';

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

/** Convert an ESPN entry to a SeasonRow, rounding all stat fields to 1 decimal. */
function espnToSeasonRow(
  entry: ESPNSeasonEntry,
  seasonLbl: string,
  teamAbbr: string | null,
): SeasonRow {
  return {
    seasonLabel: seasonLbl,
    teamAbbreviation: teamAbbr,
    gamesPlayed: entry.gamesPlayed,
    gamesStarted: round1(entry.gamesStarted),
    minutes: round1(entry.minutes),
    points: round1(entry.points),
    rebounds: round1(entry.rebounds),
    assists: round1(entry.assists),
    steals: round1(entry.steals),
    blocks: round1(entry.blocks),
    turnovers: round1(entry.turnovers),
    personalFouls: round1(entry.personalFouls),
    fgMade: round1(entry.fgMade),
    fgAttempted: round1(entry.fgAttempted),
    fgPct: round1(entry.fgPct),
    fg3Made: round1(entry.fg3Made),
    fg3Attempted: round1(entry.fg3Attempted),
    fg3Pct: round1(entry.fg3Pct),
    ftMade: round1(entry.ftMade),
    ftAttempted: round1(entry.ftAttempted),
    ftPct: round1(entry.ftPct),
    offRebounds: round1(entry.offRebounds),
    defRebounds: round1(entry.defRebounds),
  };
}

type NumericSeasonField = 'gamesStarted' | 'minutes' | 'points' | 'rebounds' | 'assists'
  | 'steals' | 'blocks' | 'turnovers' | 'personalFouls'
  | 'fgMade' | 'fgAttempted' | 'fgPct'
  | 'fg3Made' | 'fg3Attempted' | 'fg3Pct'
  | 'ftMade' | 'ftAttempted' | 'ftPct'
  | 'offRebounds' | 'defRebounds';

/**
 * Compute career averages from season rows when ESPN doesn't provide them.
 * Weighted average by games played. Uses TOTAL rows only to avoid
 * double-counting traded players.
 */
function computeCareerFromSeasons(seasons: SeasonRow[]): SeasonRow {
  const totalRows = seasons.filter(s => s.teamAbbreviation === null);
  const rows = totalRows.length > 0 ? totalRows : seasons;
  const totalGP = rows.reduce((sum, s) => sum + s.gamesPlayed, 0);

  const empty: SeasonRow = {
    seasonLabel: 'Career',
    teamAbbreviation: null,
    gamesPlayed: 0,
    gamesStarted: 0, minutes: 0, points: 0, rebounds: 0, assists: 0,
    steals: 0, blocks: 0, turnovers: 0, personalFouls: 0,
    fgMade: 0, fgAttempted: 0, fgPct: 0,
    fg3Made: 0, fg3Attempted: 0, fg3Pct: 0,
    ftMade: 0, ftAttempted: 0, ftPct: 0,
    offRebounds: 0, defRebounds: 0,
  };

  if (totalGP === 0) return empty;

  const weightedAvg = (field: NumericSeasonField) =>
    round1(rows.reduce((sum, s) => sum + s[field] * s.gamesPlayed, 0) / totalGP);

  // For percentages, recompute from career-total made/attempted rather than averaging
  // the per-season percentages. Averaging percentages is mathematically wrong because
  // seasons with more attempts should carry more weight (e.g. 50% on 200 FGA vs 40% on 50 FGA).
  const totalFGA = rows.reduce((sum, s) => sum + s.fgAttempted * s.gamesPlayed, 0);
  const totalFG3A = rows.reduce((sum, s) => sum + s.fg3Attempted * s.gamesPlayed, 0);
  const totalFTA = rows.reduce((sum, s) => sum + s.ftAttempted * s.gamesPlayed, 0);

  // gamesStarted is a total count (not a per-game average), so sum it directly
  const totalGS = rows.reduce((sum, s) => sum + s.gamesStarted, 0);

  return {
    seasonLabel: 'Career',
    teamAbbreviation: null,
    gamesPlayed: totalGP,
    gamesStarted: totalGS,
    minutes: weightedAvg('minutes'),
    points: weightedAvg('points'),
    rebounds: weightedAvg('rebounds'),
    assists: weightedAvg('assists'),
    steals: weightedAvg('steals'),
    blocks: weightedAvg('blocks'),
    turnovers: weightedAvg('turnovers'),
    personalFouls: weightedAvg('personalFouls'),
    fgMade: weightedAvg('fgMade'),
    fgAttempted: weightedAvg('fgAttempted'),
    fgPct: totalFGA > 0
      ? round1(rows.reduce((sum, s) => sum + s.fgMade * s.gamesPlayed, 0) / totalFGA * 100)
      : 0,
    fg3Made: weightedAvg('fg3Made'),
    fg3Attempted: weightedAvg('fg3Attempted'),
    fg3Pct: totalFG3A > 0
      ? round1(rows.reduce((sum, s) => sum + s.fg3Made * s.gamesPlayed, 0) / totalFG3A * 100)
      : 0,
    ftMade: weightedAvg('ftMade'),
    ftAttempted: weightedAvg('ftAttempted'),
    ftPct: totalFTA > 0
      ? round1(rows.reduce((sum, s) => sum + s.ftMade * s.gamesPlayed, 0) / totalFTA * 100)
      : 0,
    offRebounds: weightedAvg('offRebounds'),
    defRebounds: weightedAvg('defRebounds'),
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
    const gp = hs.games_played || 0;
    const perGame = (total: number | null) => gp > 0 && total ? round1(total / gp) : 0;

    seasons.push({
      seasonLabel: seasonLabel(hs.season),
      teamAbbreviation: !hs.team_id || hs.team_id === 'TOTAL' ? null : hs.team_id,
      gamesPlayed: gp,
      gamesStarted: hs.games_started || 0,
      minutes: perGame(hs.minutes_total),
      points: round1(hs.ppg ?? perGame(hs.points_total)),
      rebounds: round1(hs.rpg ?? perGame(hs.reb)),
      assists: round1(hs.apg ?? perGame(hs.ast)),
      steals: perGame(hs.stl),
      blocks: perGame(hs.blk),
      turnovers: perGame(hs.tov),
      personalFouls: perGame(hs.pf),
      fgMade: perGame(hs.fgm),
      fgAttempted: perGame(hs.fga),
      fgPct: round1((hs.fg_pct || 0) * 100),
      fg3Made: perGame(hs.fg3m),
      fg3Attempted: perGame(hs.fg3a),
      fg3Pct: round1((hs.fg3_pct || 0) * 100),
      ftMade: perGame(hs.ftm),
      ftAttempted: perGame(hs.fta),
      ftPct: round1((hs.ft_pct || 0) * 100),
      offRebounds: perGame(hs.oreb),
      defRebounds: perGame(hs.dreb),
    });
  }

  // Current season + any ESPN seasons not in Supabase
  if (espnData) {
    for (const es of espnData.seasons) {
      const alreadyInDb = historicalSeasons.some(
        hs => hs.season === es.season && hs.season < currentSeason
      );
      if (alreadyInDb) continue;

      seasons.push(espnToSeasonRow(es, seasonLabel(es.season), es.teamAbbreviation || null));
    }
  }

  seasons.sort((a, b) => b.seasonLabel.localeCompare(a.seasonLabel));

  // Career row: prefer ESPN, fallback to weighted average from seasons
  let career: SeasonRow;
  if (espnData?.career) {
    career = espnToSeasonRow(espnData.career, 'Career', null);
  } else {
    career = computeCareerFromSeasons(seasons);
  }

  return { player: statCentralPlayer, seasons, career };
}
