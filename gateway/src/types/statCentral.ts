/**
 * Stat Central API Types
 *
 * Response contract for GET /v1/players/:id/stat-central
 * Used by the iOS Player Profile Stat Central tab.
 */

export interface StatCentralPlayer {
  id: string;
  displayName: string;
  jersey: string;
  position: string;
  teamName: string;
  teamAbbreviation: string;
  headshot: string | null;
  college: string | null;
  hometown: string | null;
  draftSummary: string | null; // "2020 · Round 1 · Pick 21" or null if undrafted
}

export interface SeasonRow {
  seasonLabel: string; // "2025-26" or "Career"
  teamAbbreviation: string | null; // null for TOTAL or career rows
  gamesPlayed: number;
  gamesStarted: number;
  minutes: number;         // minutes per game
  points: number;          // points per game
  rebounds: number;        // rebounds per game
  assists: number;         // assists per game
  steals: number;          // steals per game
  blocks: number;          // blocks per game
  turnovers: number;       // turnovers per game
  personalFouls: number;   // personal fouls per game
  fgMade: number;          // field goals made per game
  fgAttempted: number;
  fgPct: number;           // 0-100 scale
  fg3Made: number;         // three-pointers made per game
  fg3Attempted: number;
  fg3Pct: number;          // 0-100 scale
  ftMade: number;          // free throws made per game
  ftAttempted: number;
  ftPct: number;           // 0-100 scale
  offRebounds: number;     // offensive rebounds per game
  defRebounds: number;     // defensive rebounds per game
}

export interface StatCentralData {
  player: StatCentralPlayer;
  seasons: SeasonRow[]; // sorted descending by season, then by team
  career: SeasonRow;
}

export interface StatCentralResponse {
  data: StatCentralData;
  meta: {
    lastUpdated: string; // ISO 8601
  };
}

// Re-export seasonLabel from its canonical location for backwards compatibility
export { seasonLabel } from '../utils/seasonUtils';
