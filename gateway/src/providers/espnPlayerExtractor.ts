/**
 * ESPN Player Data Extractor
 *
 * Extracts player bio and game stats from ESPN box score responses
 * Integrates with playerRepository to upsert player data
 */

import { logger } from '../utils/logger';
import {
  Player,
  NBAGameLog,
  upsertPlayer,
  upsertNBAGameLog,
  recomputeSeasonSummary,
  recomputeNBASplits,
} from '../db/repositories/playerRepository';

/**
 * ESPN box score response types (subset needed for player extraction)
 */
interface ESPNSummaryResponse {
  boxscore: {
    teams: ESPNBoxscoreTeam[];
    players: ESPNBoxscorePlayers[];
  };
  header: {
    id: string;
    competitions: ESPNCompetition[];
  };
}

interface ESPNBoxscoreTeam {
  team: {
    id: string;
    abbreviation: string;
    displayName: string;
  };
}

interface ESPNBoxscorePlayers {
  team: {
    id: string;
    abbreviation: string;
  };
  statistics: Array<{
    names: string[];
    labels: string[];
    athletes: ESPNAthlete[];
  }>;
}

interface ESPNAthlete {
  active: boolean;
  athlete: {
    id: string;
    displayName: string;
    shortName: string;
    jersey?: string;
    position?: {
      abbreviation: string;
    };
  };
  starter: boolean;
  didNotPlay: boolean;
  reason?: string;
  stats: string[];
}

interface ESPNCompetition {
  id: string;
  date?: string;
  competitors: ESPNCompetitor[];
}

interface ESPNCompetitor {
  id: string;
  homeAway: 'home' | 'away';
  team: {
    id: string;
  };
}

/**
 * Extract and upsert all players from an ESPN box score
 *
 * @param summary - ESPN summary response containing box score data
 * @param leaguePrefix - League identifier (e.g., 'nba', 'ncaam')
 * @param season - Season year (e.g., 2025 for 2025-26 season)
 * @returns Array of player IDs that were upserted
 */
export async function extractAndUpsertPlayersFromBoxScore(
  summary: ESPNSummaryResponse,
  leaguePrefix: string,
  season: number
): Promise<string[]> {
  const playerIds: string[] = [];

  if (!summary.boxscore?.players?.length) {
    logger.warn('ESPN box score has no player data', {
      eventId: summary.header?.id
    });
    return playerIds;
  }

  const espnEventId = summary.header.id;
  const gameId = `${leaguePrefix}_${espnEventId}`;
  const competition = summary.header.competitions[0];

  // Extract game date
  const gameDate = competition.date ? new Date(competition.date) : new Date();

  // Process each team's player data
  for (const teamData of summary.boxscore.players) {
    const teamId = `${leaguePrefix}_${teamData.team.id}`;

    // Find if this team is home or away
    const competitor = competition.competitors.find(c => c.team.id === teamData.team.id);
    const isHome = competitor?.homeAway === 'home';

    // Find opponent team
    const opponentCompetitor = competition.competitors.find(c => c.team.id !== teamData.team.id);
    const opponentTeamId = opponentCompetitor ? `${leaguePrefix}_${opponentCompetitor.team.id}` : undefined;

    // Extract players from statistics (NBA/NCAAM has one statistics entry)
    const stats = teamData.statistics[0];
    if (!stats?.athletes?.length) continue;

    const labels = stats.labels || [];

    for (const athlete of stats.athletes) {
      try {
        // Upsert player bio
        const player = await upsertPlayer({
          sport: leaguePrefix,
          provider: 'espn',
          providerPlayerId: athlete.athlete.id,
          displayName: athlete.athlete.displayName,
          firstName: extractFirstName(athlete.athlete.displayName),
          lastName: extractLastName(athlete.athlete.displayName),
          jersey: athlete.athlete.jersey,
          position: athlete.athlete.position?.abbreviation,
          currentTeamId: teamId,
          isActive: true,
        });

        playerIds.push(player.id);

        // Extract and upsert game log
        const gameLog = extractNBAGameLog(
          player.id,
          gameId,
          season,
          gameDate,
          teamId,
          opponentTeamId,
          isHome,
          athlete,
          labels
        );

        await upsertNBAGameLog(gameLog);

        logger.debug('Upserted player and game log', {
          playerId: player.id,
          playerName: player.display_name,
          gameId,
          didNotPlay: athlete.didNotPlay,
        });

      } catch (error) {
        logger.error('Failed to extract player from box score', {
          espnPlayerId: athlete.athlete.id,
          playerName: athlete.athlete.displayName,
          gameId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  logger.info('Extracted players from box score', {
    gameId,
    playerCount: playerIds.length,
  });

  return playerIds;
}

/**
 * Extract NBA game log from ESPN athlete data
 */
function extractNBAGameLog(
  playerId: string,
  gameId: string,
  season: number,
  gameDate: Date,
  teamId: string,
  opponentTeamId: string | undefined,
  isHome: boolean,
  athlete: ESPNAthlete,
  labels: string[]
): NBAGameLog {
  // Create label-to-index mapping
  const labelIndex: Record<string, number> = {};
  labels.forEach((label, idx) => {
    labelIndex[label.toUpperCase()] = idx;
  });

  const stats = athlete.stats || [];

  const getStat = (label: string): string | undefined => {
    const idx = labelIndex[label];
    return idx !== undefined ? stats[idx] : undefined;
  };

  const parseNumber = (val: string | undefined): number => {
    if (!val || val === '-' || val === '') return 0;
    return parseInt(val, 10) || 0;
  };

  const parseMadeAttempted = (val: string | undefined): [number, number] => {
    if (!val || val === '-' || val === '') return [0, 0];
    const parts = val.split('-');
    return [parseInt(parts[0], 10) || 0, parseInt(parts[1], 10) || 0];
  };

  const parseMinutes = (val: string | undefined): number | undefined => {
    if (!val || val === '-' || val === '') return undefined;
    // ESPN minutes can be "32" or "32:45"
    const parts = val.split(':');
    const minutes = parseInt(parts[0], 10) || 0;
    const seconds = parts.length > 1 ? parseInt(parts[1], 10) || 0 : 0;
    // Convert to decimal minutes (e.g., 32:30 = 32.5)
    return minutes + (seconds / 60);
  };

  const [fgMade, fgAttempted] = parseMadeAttempted(getStat('FG'));
  const [fg3Made, fg3Attempted] = parseMadeAttempted(getStat('3PT'));
  const [ftMade, ftAttempted] = parseMadeAttempted(getStat('FT'));

  return {
    player_id: playerId,
    game_id: gameId,
    season,
    game_date: gameDate,
    team_id: teamId,
    opponent_team_id: opponentTeamId,
    is_home: isHome,
    is_starter: athlete.starter,
    minutes: parseMinutes(getStat('MIN')),
    points: parseNumber(getStat('PTS')),
    fgm: fgMade,
    fga: fgAttempted,
    fg3m: fg3Made,
    fg3a: fg3Attempted,
    ftm: ftMade,
    fta: ftAttempted,
    oreb: parseNumber(getStat('OREB')),
    dreb: parseNumber(getStat('DREB')),
    reb: parseNumber(getStat('REB')) || (parseNumber(getStat('OREB')) + parseNumber(getStat('DREB'))),
    ast: parseNumber(getStat('AST')),
    stl: parseNumber(getStat('STL')),
    blk: parseNumber(getStat('BLK')),
    tov: parseNumber(getStat('TO')),
    pf: parseNumber(getStat('PF')),
    plus_minus: parseNumber(getStat('+/-')) || undefined,
    dnp_reason: athlete.didNotPlay ? (athlete.reason || 'DNP') : undefined,
  };
}

/**
 * Extract first name from full name
 * "LeBron James" -> "LeBron"
 * "Stephen Curry" -> "Stephen"
 */
function extractFirstName(fullName: string): string | undefined {
  const parts = fullName.trim().split(' ');
  return parts.length > 1 ? parts.slice(0, -1).join(' ') : undefined;
}

/**
 * Extract last name from full name
 * "LeBron James" -> "James"
 * "Stephen Curry" -> "Curry"
 */
function extractLastName(fullName: string): string | undefined {
  const parts = fullName.trim().split(' ');
  return parts.length > 1 ? parts[parts.length - 1] : undefined;
}

/**
 * Process a box score to extract players and recompute stats
 *
 * @param summary - ESPN summary response
 * @param leaguePrefix - League identifier
 * @param season - Season year
 */
export async function processBoxScoreForPlayers(
  summary: ESPNSummaryResponse,
  leaguePrefix: string,
  season: number
): Promise<void> {
  // Extract and upsert players
  const playerIds = await extractAndUpsertPlayersFromBoxScore(summary, leaguePrefix, season);

  // Recompute season summaries and splits for each player
  for (const playerId of playerIds) {
    try {
      await recomputeSeasonSummary(playerId, season);
      await recomputeNBASplits(playerId, season);

      logger.debug('Recomputed stats for player', { playerId, season });
    } catch (error) {
      logger.error('Failed to recompute stats for player', {
        playerId,
        season,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  logger.info('Processed box score for players', {
    gameId: `${leaguePrefix}_${summary.header.id}`,
    playerCount: playerIds.length,
  });
}

/**
 * Determine season from game date
 * NBA/NCAAM seasons span two calendar years (e.g., 2025-26 season starts Oct 2025)
 *
 * @param gameDate - Game date
 * @param leaguePrefix - League identifier
 * @returns Season year (start year of the season)
 */
export function getSeasonFromGameDate(gameDate: Date, leaguePrefix: string): number {
  const year = gameDate.getFullYear();
  const month = gameDate.getMonth(); // 0-indexed (0 = January)

  // For NBA/NCAAM: Oct-Dec = current year's season, Jan-Sep = previous year's season
  // e.g., Oct 2025 = 2025-26 season (return 2025)
  // e.g., Jan 2026 = 2025-26 season (return 2025)
  if (leaguePrefix === 'nba' || leaguePrefix === 'ncaam') {
    // October (9), November (10), December (11) = current year
    if (month >= 9) {
      return year;
    }
    // January (0) through September (8) = previous year
    return year - 1;
  }

  // For other sports, use calendar year
  return year;
}
