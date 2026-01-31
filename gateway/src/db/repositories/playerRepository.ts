/**
 * Player Repository
 * Database operations for player data
 */

import { v4 as uuidv4 } from 'uuid';
import { query, getClient } from '../pool';
import { logger } from '../../utils/logger';

// =====================
// Types
// =====================

export interface Player {
  id: string;
  sport: string;
  display_name: string;
  first_name?: string;
  last_name?: string;
  jersey?: string;
  position?: string;
  height_in?: number;
  weight_lb?: number;
  school?: string;
  hometown?: string;
  headshot_url?: string;
  current_team_id?: string;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface PlayerProviderMapping {
  sport: string;
  provider: string;
  provider_player_id: string;
  player_id: string;
}

export interface NBASeasonSummary {
  player_id: string;
  season: number;
  team_id?: string;
  games_played: number;
  games_started: number;
  minutes_total: number;
  points_total: number;
  fgm: number;
  fga: number;
  fg3m: number;
  fg3a: number;
  ftm: number;
  fta: number;
  oreb: number;
  dreb: number;
  reb: number;
  ast: number;
  stl: number;
  blk: number;
  tov: number;
  pf: number;
  fg_pct?: number;
  fg3_pct?: number;
  ft_pct?: number;
  ppg?: number;
  rpg?: number;
  apg?: number;
}

export interface NBAGameLog {
  player_id: string;
  game_id: string;
  season: number;
  game_date: Date;
  team_id?: string;
  opponent_team_id?: string;
  is_home?: boolean;
  is_starter?: boolean;
  minutes?: number;
  points: number;
  fgm: number;
  fga: number;
  fg3m: number;
  fg3a: number;
  ftm: number;
  fta: number;
  oreb: number;
  dreb: number;
  reb: number;
  ast: number;
  stl: number;
  blk: number;
  tov: number;
  pf: number;
  plus_minus?: number;
  dnp_reason?: string;
}

// =====================
// Player CRUD
// =====================

/**
 * Find player by provider ID (ESPN, etc.)
 */
export async function findPlayerByProviderId(
  sport: string,
  provider: string,
  providerPlayerId: string
): Promise<Player | null> {
  const rows = await query<Player>(
    `
    SELECT p.*
    FROM players p
    JOIN external_ids e ON p.id = e.internal_id
    WHERE e.entity_type = 'player'
      AND e.provider = $1
      AND e.provider_id = $2
      AND p.sport = $3
    LIMIT 1
    `,
    [provider, providerPlayerId, sport]
  );

  return rows[0] || null;
}

/**
 * Upsert player - creates new or updates existing
 */
export async function upsertPlayer(data: {
  sport: string;
  provider: string;
  providerPlayerId: string;
  displayName: string;
  firstName?: string;
  lastName?: string;
  jersey?: string;
  position?: string;
  heightIn?: number;
  weightLb?: number;
  school?: string;
  hometown?: string;
  headshotUrl?: string;
  currentTeamId?: string;
  isActive?: boolean;
}): Promise<Player> {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Check if player exists via provider mapping
    const existing = await findPlayerByProviderId(
      data.sport,
      data.provider,
      data.providerPlayerId
    );

    let playerId: string;
    let player: Player;

    if (existing) {
      // Update existing player
      playerId = existing.id;
      const updateResult = await client.query<Player>(
        `
        UPDATE players
        SET
          display_name = COALESCE($2, display_name),
          first_name = COALESCE($3, first_name),
          last_name = COALESCE($4, last_name),
          jersey = COALESCE($5, jersey),
          position = COALESCE($6, position),
          height_in = COALESCE($7, height_in),
          weight_lb = COALESCE($8, weight_lb),
          school = COALESCE($9, school),
          hometown = COALESCE($10, hometown),
          headshot_url = COALESCE($11, headshot_url),
          current_team_id = COALESCE($12, current_team_id),
          is_active = COALESCE($13, is_active),
          updated_at = NOW()
        WHERE id = $1
        RETURNING *
        `,
        [
          playerId,
          data.displayName,
          data.firstName,
          data.lastName,
          data.jersey,
          data.position,
          data.heightIn,
          data.weightLb,
          data.school,
          data.hometown,
          data.headshotUrl,
          data.currentTeamId,
          data.isActive ?? true,
        ]
      );
      player = updateResult.rows[0];
    } else {
      // Create new player
      playerId = uuidv4();
      const insertResult = await client.query<Player>(
        `
        INSERT INTO players (
          id, sport, name, display_name, first_name, last_name, jersey, position,
          height_in, weight_lb, school, hometown, headshot_url,
          current_team_id, is_active
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING *
        `,
        [
          playerId,
          data.sport,
          data.displayName, // Use displayName for name field too
          data.displayName,
          data.firstName,
          data.lastName,
          data.jersey,
          data.position,
          data.heightIn,
          data.weightLb,
          data.school,
          data.hometown,
          data.headshotUrl,
          data.currentTeamId,
          data.isActive ?? true,
        ]
      );
      player = insertResult.rows[0];

      // Create provider mapping
      await client.query(
        `
        INSERT INTO external_ids (entity_type, internal_id, provider, provider_id)
        VALUES ('player', $1, $2, $3)
        ON CONFLICT (entity_type, internal_id, provider) DO UPDATE
        SET provider_id = EXCLUDED.provider_id, updated_at = NOW()
        `,
        [playerId, data.provider, data.providerPlayerId]
      );
    }

    await client.query('COMMIT');
    logger.debug('Player upserted', { playerId, provider: data.provider, providerPlayerId: data.providerPlayerId });

    return player;
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Failed to upsert player', { error, data });
    throw error;
  } finally {
    client.release();
  }
}

// =====================
// NBA Stats Operations
// =====================

/**
 * Upsert NBA game log entry
 */
export async function upsertNBAGameLog(log: NBAGameLog): Promise<void> {
  // Calculate percentages
  const fg_pct = log.fga > 0 ? log.fgm / log.fga : null;
  const fg3_pct = log.fg3a > 0 ? log.fg3m / log.fg3a : null;
  const ft_pct = log.fta > 0 ? log.ftm / log.fta : null;

  await query(
    `
    INSERT INTO nba_player_game_logs (
      player_id, game_id, season, game_date, team_id, opponent_team_id,
      is_home, is_starter, minutes, points, fgm, fga, fg3m, fg3a, ftm, fta,
      oreb, dreb, reb, ast, stl, blk, tov, pf, plus_minus, dnp_reason,
      fg_pct, fg3_pct, ft_pct
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
      $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29
    )
    ON CONFLICT (player_id, game_id) DO UPDATE
    SET
      team_id = EXCLUDED.team_id,
      opponent_team_id = EXCLUDED.opponent_team_id,
      is_home = EXCLUDED.is_home,
      is_starter = EXCLUDED.is_starter,
      minutes = EXCLUDED.minutes,
      points = EXCLUDED.points,
      fgm = EXCLUDED.fgm,
      fga = EXCLUDED.fga,
      fg3m = EXCLUDED.fg3m,
      fg3a = EXCLUDED.fg3a,
      ftm = EXCLUDED.ftm,
      fta = EXCLUDED.fta,
      oreb = EXCLUDED.oreb,
      dreb = EXCLUDED.dreb,
      reb = EXCLUDED.reb,
      ast = EXCLUDED.ast,
      stl = EXCLUDED.stl,
      blk = EXCLUDED.blk,
      tov = EXCLUDED.tov,
      pf = EXCLUDED.pf,
      plus_minus = EXCLUDED.plus_minus,
      dnp_reason = EXCLUDED.dnp_reason,
      fg_pct = EXCLUDED.fg_pct,
      fg3_pct = EXCLUDED.fg3_pct,
      ft_pct = EXCLUDED.ft_pct,
      updated_at = NOW()
    `,
    [
      log.player_id, log.game_id, log.season, log.game_date, log.team_id, log.opponent_team_id,
      log.is_home, log.is_starter, log.minutes, log.points, log.fgm, log.fga, log.fg3m, log.fg3a,
      log.ftm, log.fta, log.oreb, log.dreb, log.reb, log.ast, log.stl, log.blk, log.tov, log.pf,
      log.plus_minus, log.dnp_reason, fg_pct, fg3_pct, ft_pct
    ]
  );
}

/**
 * Recompute and upsert season summary for a player
 */
export async function recomputeSeasonSummary(
  playerId: string,
  season: number
): Promise<void> {
  // Aggregate from game logs
  await query(
    `
    INSERT INTO nba_player_season_summary (
      player_id, season, team_id, games_played, games_started,
      minutes_total, points_total, fgm, fga, fg3m, fg3a, ftm, fta,
      oreb, dreb, reb, ast, stl, blk, tov, pf,
      fg_pct, fg3_pct, ft_pct, ppg, rpg, apg
    )
    SELECT
      player_id,
      season,
      'TOTAL' as team_id,
      COUNT(*) as games_played,
      SUM(CASE WHEN is_starter THEN 1 ELSE 0 END) as games_started,
      SUM(minutes) as minutes_total,
      SUM(points) as points_total,
      SUM(fgm) as fgm,
      SUM(fga) as fga,
      SUM(fg3m) as fg3m,
      SUM(fg3a) as fg3a,
      SUM(ftm) as ftm,
      SUM(fta) as fta,
      SUM(oreb) as oreb,
      SUM(dreb) as dreb,
      SUM(reb) as reb,
      SUM(ast) as ast,
      SUM(stl) as stl,
      SUM(blk) as blk,
      SUM(tov) as tov,
      SUM(pf) as pf,
      CASE WHEN SUM(fga) > 0 THEN SUM(fgm)::numeric / SUM(fga) ELSE NULL END as fg_pct,
      CASE WHEN SUM(fg3a) > 0 THEN SUM(fg3m)::numeric / SUM(fg3a) ELSE NULL END as fg3_pct,
      CASE WHEN SUM(fta) > 0 THEN SUM(ftm)::numeric / SUM(fta) ELSE NULL END as ft_pct,
      CASE WHEN COUNT(*) > 0 THEN SUM(points)::numeric / COUNT(*) ELSE 0 END as ppg,
      CASE WHEN COUNT(*) > 0 THEN SUM(reb)::numeric / COUNT(*) ELSE 0 END as rpg,
      CASE WHEN COUNT(*) > 0 THEN SUM(ast)::numeric / COUNT(*) ELSE 0 END as apg
    FROM nba_player_game_logs
    WHERE player_id = $1 AND season = $2
      AND dnp_reason IS NULL  -- Exclude DNP games
    GROUP BY player_id, season
    ON CONFLICT (player_id, season, team_id) DO UPDATE
    SET
      games_played = EXCLUDED.games_played,
      games_started = EXCLUDED.games_started,
      minutes_total = EXCLUDED.minutes_total,
      points_total = EXCLUDED.points_total,
      fgm = EXCLUDED.fgm,
      fga = EXCLUDED.fga,
      fg3m = EXCLUDED.fg3m,
      fg3a = EXCLUDED.fg3a,
      ftm = EXCLUDED.ftm,
      fta = EXCLUDED.fta,
      oreb = EXCLUDED.oreb,
      dreb = EXCLUDED.dreb,
      reb = EXCLUDED.reb,
      ast = EXCLUDED.ast,
      stl = EXCLUDED.stl,
      blk = EXCLUDED.blk,
      tov = EXCLUDED.tov,
      pf = EXCLUDED.pf,
      fg_pct = EXCLUDED.fg_pct,
      fg3_pct = EXCLUDED.fg3_pct,
      ft_pct = EXCLUDED.ft_pct,
      ppg = EXCLUDED.ppg,
      rpg = EXCLUDED.rpg,
      apg = EXCLUDED.apg,
      updated_at = NOW()
    `,
    [playerId, season]
  );

  logger.debug('Recomputed season summary', { playerId, season });
}

/**
 * Recompute and upsert splits for a player/season
 */
export async function recomputeNBASplits(
  playerId: string,
  season: number
): Promise<void> {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    // HOME/AWAY splits
    for (const location of ['HOME', 'AWAY']) {
      const isHome = location === 'HOME';
      const stats = await client.query(
        `
        SELECT
          COUNT(*) as games_played,
          SUM(minutes) as minutes,
          SUM(points) as points,
          SUM(fgm) as fgm,
          SUM(fga) as fga,
          SUM(fg3m) as fg3m,
          SUM(fg3a) as fg3a,
          SUM(ftm) as ftm,
          SUM(fta) as fta,
          SUM(reb) as reb,
          SUM(ast) as ast,
          SUM(stl) as stl,
          SUM(blk) as blk,
          SUM(tov) as tov,
          SUM(pf) as pf,
          MAX(game_date) as last_game_date
        FROM nba_player_game_logs
        WHERE player_id = $1 AND season = $2 AND is_home = $3
          AND dnp_reason IS NULL
        `,
        [playerId, season, isHome]
      );

      if (stats.rows[0] && stats.rows[0].games_played > 0) {
        const row = stats.rows[0];
        await client.query(
          `
          INSERT INTO nba_player_splits (
            player_id, season, split_type, split_key, stats_json,
            games_included, last_game_date
          ) VALUES ($1, $2, 'HOME_AWAY', $3, $4, $5, $6)
          ON CONFLICT (player_id, season, split_type, split_key) DO UPDATE
          SET stats_json = EXCLUDED.stats_json,
              games_included = EXCLUDED.games_included,
              last_game_date = EXCLUDED.last_game_date,
              updated_at = NOW()
          `,
          [
            playerId,
            season,
            location,
            JSON.stringify(row),
            row.games_played,
            row.last_game_date
          ]
        );
      }
    }

    // LAST_N splits (5, 10, 20 games)
    for (const n of [5, 10, 20]) {
      const stats = await client.query(
        `
        SELECT
          COUNT(*) as games_played,
          SUM(minutes) as minutes,
          SUM(points) as points,
          SUM(fgm) as fgm,
          SUM(fga) as fga,
          SUM(fg3m) as fg3m,
          SUM(fg3a) as fg3a,
          SUM(ftm) as ftm,
          SUM(fta) as fta,
          SUM(reb) as reb,
          SUM(ast) as ast,
          SUM(stl) as stl,
          SUM(blk) as blk,
          SUM(tov) as tov,
          SUM(pf) as pf,
          MAX(game_date) as last_game_date
        FROM (
          SELECT * FROM nba_player_game_logs
          WHERE player_id = $1 AND season = $2 AND dnp_reason IS NULL
          ORDER BY game_date DESC
          LIMIT $3
        ) recent
        `,
        [playerId, season, n]
      );

      if (stats.rows[0] && stats.rows[0].games_played > 0) {
        const row = stats.rows[0];
        await client.query(
          `
          INSERT INTO nba_player_splits (
            player_id, season, split_type, split_key, stats_json,
            games_included, last_game_date
          ) VALUES ($1, $2, 'LAST_N', $3, $4, $5, $6)
          ON CONFLICT (player_id, season, split_type, split_key) DO UPDATE
          SET stats_json = EXCLUDED.stats_json,
              games_included = EXCLUDED.games_included,
              last_game_date = EXCLUDED.last_game_date,
              updated_at = NOW()
          `,
          [
            playerId,
            season,
            `LAST${n}`,
            JSON.stringify(row),
            row.games_played,
            row.last_game_date
          ]
        );
      }
    }

    // BY_MONTH splits
    const monthStats = await client.query(
      `
      SELECT
        TO_CHAR(game_date, 'MON') as month,
        COUNT(*) as games_played,
        SUM(minutes) as minutes,
        SUM(points) as points,
        SUM(fgm) as fgm,
        SUM(fga) as fga,
        SUM(fg3m) as fg3m,
        SUM(fg3a) as fg3a,
        SUM(ftm) as ftm,
        SUM(fta) as fta,
        SUM(reb) as reb,
        SUM(ast) as ast,
        SUM(stl) as stl,
        SUM(blk) as blk,
        SUM(tov) as tov,
        SUM(pf) as pf,
        MAX(game_date) as last_game_date
      FROM nba_player_game_logs
      WHERE player_id = $1 AND season = $2 AND dnp_reason IS NULL
      GROUP BY TO_CHAR(game_date, 'MON'), EXTRACT(MONTH FROM game_date)
      ORDER BY EXTRACT(MONTH FROM game_date)
      `,
      [playerId, season]
    );

    for (const row of monthStats.rows) {
      await client.query(
        `
        INSERT INTO nba_player_splits (
          player_id, season, split_type, split_key, stats_json,
          games_included, last_game_date
        ) VALUES ($1, $2, 'BY_MONTH', $3, $4, $5, $6)
        ON CONFLICT (player_id, season, split_type, split_key) DO UPDATE
        SET stats_json = EXCLUDED.stats_json,
            games_included = EXCLUDED.games_included,
            last_game_date = EXCLUDED.last_game_date,
            updated_at = NOW()
        `,
        [
          playerId,
          season,
          row.month.toUpperCase(),
          JSON.stringify(row),
          row.games_played,
          row.last_game_date
        ]
      );
    }

    await client.query('COMMIT');
    logger.debug('Recomputed NBA splits', { playerId, season });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Failed to recompute NBA splits', { error, playerId, season });
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Get player by ID
 */
export async function getPlayerById(playerId: string): Promise<Player | null> {
  const rows = await query<Player>(
    'SELECT * FROM players WHERE id = $1 LIMIT 1',
    [playerId]
  );
  return rows[0] || null;
}

/**
 * Get NBA season summary
 */
export async function getNBASeasonSummary(
  playerId: string,
  season: number
): Promise<NBASeasonSummary | null> {
  const rows = await query<NBASeasonSummary>(
    `SELECT * FROM nba_player_season_summary
     WHERE player_id = $1 AND season = $2 AND team_id = 'TOTAL'
     LIMIT 1`,
    [playerId, season]
  );
  return rows[0] || null;
}

/**
 * Get NBA game logs for a season
 */
export async function getNBAGameLogs(
  playerId: string,
  season: number,
  limit: number = 82
): Promise<NBAGameLog[]> {
  return await query<NBAGameLog>(
    `SELECT * FROM nba_player_game_logs
     WHERE player_id = $1 AND season = $2
     ORDER BY game_date DESC
     LIMIT $3`,
    [playerId, season, limit]
  );
}

/**
 * Get NBA splits
 */
export async function getNBASplits(
  playerId: string,
  season: number
): Promise<any> {
  const rows = await query<{split_type: string; split_key: string; stats_json: any}>(
    `SELECT split_type, split_key, stats_json
     FROM nba_player_splits
     WHERE player_id = $1 AND season = $2`,
    [playerId, season]
  );

  // Group by split_type
  const splits: any = {
    homeAway: {},
    lastN: {},
    byMonth: []
  };

  for (const row of rows) {
    if (row.split_type === 'HOME_AWAY') {
      splits.homeAway[row.split_key] = row.stats_json;
    } else if (row.split_type === 'LAST_N') {
      splits.lastN[row.split_key] = row.stats_json;
    } else if (row.split_type === 'BY_MONTH') {
      splits.byMonth.push({ month: row.split_key, stats: row.stats_json });
    }
  }

  return splits;
}

export interface HistoricalSeasonRow {
  season: number;
  team_id: string | null;
  games_played: number;
  stl: number | null;
  fg_pct: number | null;
  ft_pct: number | null;
  ppg: number | null;
  rpg: number | null;
  apg: number | null;
}

/**
 * Get all historical season summaries for a player (all seasons, all teams).
 * Returns both TOTAL rows and per-team rows for traded players.
 * Used by the stat-central endpoint.
 */
export async function getHistoricalSeasons(
  playerId: string
): Promise<HistoricalSeasonRow[]> {
  return await query<HistoricalSeasonRow>(
    `SELECT season, team_id, games_played, stl, fg_pct, ft_pct, ppg, rpg, apg
     FROM nba_player_season_summary
     WHERE player_id = $1
     ORDER BY season DESC, team_id ASC`,
    [playerId]
  );
}

/**
 * Upsert multiple season summaries from ESPN backfill data.
 * Each entry is a per-game average row — we store it as-is in the summary table
 * using the ppg/rpg/apg fields directly (since we don't have raw totals from ESPN averages).
 */
export async function upsertSeasonSummary(data: {
  playerId: string;
  season: number;
  teamId: string; // 'TOTAL' or actual team_id
  gamesPlayed: number;
  ppg: number;
  rpg: number;
  apg: number;
  spg: number;
  fgPct: number; // 0-1 decimal (DB stores as decimal)
  ftPct: number; // 0-1 decimal
}): Promise<void> {
  await query(
    `INSERT INTO nba_player_season_summary (
      player_id, season, team_id, games_played,
      stl, fg_pct, ft_pct, ppg, rpg, apg
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    ON CONFLICT (player_id, season, team_id) DO UPDATE
    SET
      games_played = EXCLUDED.games_played,
      stl = EXCLUDED.stl,
      fg_pct = EXCLUDED.fg_pct,
      ft_pct = EXCLUDED.ft_pct,
      ppg = EXCLUDED.ppg,
      rpg = EXCLUDED.rpg,
      apg = EXCLUDED.apg,
      updated_at = NOW()`,
    [
      data.playerId,
      data.season,
      data.teamId,
      data.gamesPlayed,
      // Store steals as total (spg * gp) since column is raw count
      data.gamesPlayed > 0 ? Math.round(data.spg * data.gamesPlayed) : 0,
      data.fgPct, // 0-1 decimal for DB
      data.ftPct,
      data.ppg,
      data.rpg,
      data.apg,
    ]
  );
}

// =====================
// Player Search
// =====================

export interface PlayerSearchResult {
  id: string;
  sport: string;
  display_name: string;
  position: string | null;
  current_team_id: string | null;
}

/**
 * Search players by name
 * Case-insensitive partial match using ILIKE
 */
export async function searchPlayers(
  queryStr: string,
  sport?: string,
  limit: number = 20
): Promise<PlayerSearchResult[]> {
  const escaped = queryStr.replace(/[%_\\]/g, '\\$&');
  const searchPattern = `%${escaped}%`;

  if (sport) {
    return await query<PlayerSearchResult>(
      `SELECT id, sport, display_name, position, current_team_id
       FROM players
       WHERE display_name ILIKE $1 ESCAPE '\\'
         AND sport = $2
         AND is_active = true
       ORDER BY display_name ASC
       LIMIT $3`,
      [searchPattern, sport, limit]
    );
  }

  return await query<PlayerSearchResult>(
    `SELECT id, sport, display_name, position, current_team_id
     FROM players
     WHERE display_name ILIKE $1 ESCAPE '\\'
       AND is_active = true
     ORDER BY display_name ASC
     LIMIT $2`,
    [searchPattern, limit]
  );
}

// =====================
// NFL Stats Operations
// =====================

export interface NFLSeasonSummary {
  player_id: string;
  season: number;
  team_id?: string;
  games_played: number;
  games_started: number;
  position_category: string;
  stats_json: Record<string, any>;
  updated_at?: Date;
}

export interface NFLGameLog {
  player_id: string;
  game_id: string;
  season: number;
  week?: number;
  game_date: Date;
  team_id?: string;
  opponent_team_id?: string;
  is_home?: boolean;
  is_starter?: boolean;
  position_category?: string;
  stats_json: Record<string, any>;
  dnp_reason?: string;
  updated_at?: Date;
}

/**
 * Upsert NFL game log entry
 */
export async function upsertNFLGameLog(log: NFLGameLog): Promise<void> {
  await query(
    `
    INSERT INTO nfl_player_game_logs (
      player_id, game_id, season, week, game_date, team_id, opponent_team_id,
      is_home, is_starter, position_category, stats_json, dnp_reason
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    ON CONFLICT (player_id, game_id) DO UPDATE
    SET
      team_id = EXCLUDED.team_id,
      opponent_team_id = EXCLUDED.opponent_team_id,
      week = EXCLUDED.week,
      is_home = EXCLUDED.is_home,
      is_starter = EXCLUDED.is_starter,
      position_category = EXCLUDED.position_category,
      stats_json = EXCLUDED.stats_json,
      dnp_reason = EXCLUDED.dnp_reason,
      updated_at = NOW()
    `,
    [
      log.player_id, log.game_id, log.season, log.week, log.game_date,
      log.team_id, log.opponent_team_id, log.is_home, log.is_starter,
      log.position_category, JSON.stringify(log.stats_json), log.dnp_reason
    ]
  );
}

/**
 * Recompute and upsert NFL season summary for a player
 */
export async function recomputeNFLSeasonSummary(
  playerId: string,
  season: number
): Promise<void> {
  // Get all game logs for this player/season
  const gameLogs = await query<{ position_category: string; stats_json: any }>(
    `SELECT position_category, stats_json
     FROM nfl_player_game_logs
     WHERE player_id = $1 AND season = $2 AND dnp_reason IS NULL`,
    [playerId, season]
  );

  if (gameLogs.length === 0) return;

  // Determine position category from most common
  const positionCounts: Record<string, number> = {};
  for (const log of gameLogs) {
    if (log.position_category) {
      positionCounts[log.position_category] = (positionCounts[log.position_category] || 0) + 1;
    }
  }
  const positionCategory = Object.entries(positionCounts)
    .sort((a, b) => b[1] - a[1])[0]?.[0] || 'UNKNOWN';

  // Aggregate stats based on position
  const aggregatedStats: Record<string, number> = {};
  for (const log of gameLogs) {
    const stats = typeof log.stats_json === 'string' ? JSON.parse(log.stats_json) : log.stats_json;
    for (const [key, value] of Object.entries(stats)) {
      if (typeof value === 'number') {
        aggregatedStats[key] = (aggregatedStats[key] || 0) + value;
      }
    }
  }

  await query(
    `
    INSERT INTO nfl_player_season_summary (
      player_id, season, team_id, games_played, games_started,
      position_category, stats_json
    ) VALUES ($1, $2, 'TOTAL', $3, $4, $5, $6)
    ON CONFLICT (player_id, season, team_id) DO UPDATE
    SET
      games_played = EXCLUDED.games_played,
      games_started = EXCLUDED.games_started,
      position_category = EXCLUDED.position_category,
      stats_json = EXCLUDED.stats_json,
      updated_at = NOW()
    `,
    [
      playerId, season, gameLogs.length,
      gameLogs.filter(g => (typeof g.stats_json === 'object' ? g.stats_json : JSON.parse(g.stats_json)).is_starter).length,
      positionCategory, JSON.stringify(aggregatedStats)
    ]
  );

  logger.debug('Recomputed NFL season summary', { playerId, season, positionCategory });
}

/**
 * Get NFL season summary
 */
export async function getNFLSeasonSummary(
  playerId: string,
  season: number
): Promise<NFLSeasonSummary | null> {
  const rows = await query<NFLSeasonSummary>(
    `SELECT * FROM nfl_player_season_summary
     WHERE player_id = $1 AND season = $2 AND team_id = 'TOTAL'
     LIMIT 1`,
    [playerId, season]
  );
  return rows[0] || null;
}

/**
 * Get NFL game logs for a season
 */
export async function getNFLGameLogs(
  playerId: string,
  season: number,
  limit: number = 17
): Promise<NFLGameLog[]> {
  return await query<NFLGameLog>(
    `SELECT * FROM nfl_player_game_logs
     WHERE player_id = $1 AND season = $2
     ORDER BY game_date DESC
     LIMIT $3`,
    [playerId, season, limit]
  );
}

/**
 * Get NFL career summaries
 */
export async function getNFLCareerSummaries(
  playerId: string
): Promise<NFLSeasonSummary[]> {
  return await query<NFLSeasonSummary>(
    `SELECT * FROM nfl_player_career_summary
     WHERE player_id = $1 AND team_id = 'TOTAL'
     ORDER BY season DESC`,
    [playerId]
  );
}

/**
 * Get position category for a player
 */
export async function getPlayerPositionCategory(playerId: string): Promise<string | null> {
  const player = await getPlayerById(playerId);
  if (!player?.position) return null;

  const position = player.position.toUpperCase();

  // Map detailed positions to categories
  if (['QB'].includes(position)) return 'QB';
  if (['RB', 'FB', 'HB'].includes(position)) return 'RB';
  if (['WR'].includes(position)) return 'WR';
  if (['TE'].includes(position)) return 'TE';
  if (['K', 'PK'].includes(position)) return 'K';
  if (['P'].includes(position)) return 'P';
  if (['DE', 'DT', 'NT', 'LB', 'ILB', 'OLB', 'MLB', 'CB', 'S', 'FS', 'SS', 'DB'].includes(position)) return 'DEF';
  if (['OL', 'OT', 'OG', 'C', 'G', 'T'].includes(position)) return 'OL';

  return position;
}
