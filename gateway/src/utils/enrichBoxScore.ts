/**
 * Box Score Enrichment
 *
 * Enriches box score player data with internal player UUIDs
 * so the iOS app can navigate to player profiles
 */

import { BoxScore, NBATeamBoxScore, PlayerLine } from '../types';
import { findPlayerByProviderId } from '../db/repositories/playerRepository';
import { logger } from './logger';

/**
 * Enrich box score with internal player IDs
 * Converts ESPN player IDs (player_4395628) to internal UUIDs
 */
export async function enrichBoxScoreWithPlayerIds(
  boxScore: BoxScore,
  leaguePrefix: string = 'nba'
): Promise<BoxScore> {
  try {
    // Enrich home team
    if (isNBABoxScore(boxScore.homeTeam)) {
      await enrichNBATeamPlayers(boxScore.homeTeam, leaguePrefix);
    }

    // Enrich away team
    if (isNBABoxScore(boxScore.awayTeam)) {
      await enrichNBATeamPlayers(boxScore.awayTeam, leaguePrefix);
    }

    return boxScore;
  } catch (error) {
    logger.error('Failed to enrich box score with player IDs', {
      error: error instanceof Error ? error.message : String(error),
    });
    // Return original box score if enrichment fails
    return boxScore;
  }
}

/**
 * Type guard for NBA box score
 */
function isNBABoxScore(team: any): team is NBATeamBoxScore {
  return team && 'starters' in team && 'bench' in team;
}

/**
 * Enrich NBA team players with internal IDs
 */
async function enrichNBATeamPlayers(
  team: NBATeamBoxScore,
  leaguePrefix: string
): Promise<void> {
  // Enrich starters
  for (const player of team.starters) {
    await enrichPlayer(player, leaguePrefix);
  }

  // Enrich bench
  for (const player of team.bench) {
    await enrichPlayer(player, leaguePrefix);
  }

  // Enrich DNP
  for (const player of team.dnp) {
    await enrichPlayer(player, leaguePrefix);
  }
}

/**
 * Enrich individual player with internal ID
 */
async function enrichPlayer(player: PlayerLine, leaguePrefix: string): Promise<void> {
  try {
    // Extract ESPN player ID from current ID (player_4395628 -> 4395628)
    const espnId = player.id.replace('player_', '');

    // Look up internal player ID
    const dbPlayer = await findPlayerByProviderId(leaguePrefix, 'espn', espnId);

    if (dbPlayer) {
      // Replace with internal UUID
      player.id = dbPlayer.id;
      logger.debug('Enriched player ID', {
        espnId,
        internalId: dbPlayer.id,
        name: player.name,
      });
    } else {
      logger.warn('Player not found in database', {
        espnId,
        name: player.name,
      });
      // Keep ESPN ID as fallback
    }
  } catch (error) {
    logger.error('Failed to enrich player', {
      playerId: player.id,
      name: player.name,
      error: error instanceof Error ? error.message : String(error),
    });
    // Keep original ID on error
  }
}
