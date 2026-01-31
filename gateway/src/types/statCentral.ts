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
  ppg: number;
  rpg: number;
  apg: number;
  spg: number;
  fgPct: number; // 0-100 scale
  ftPct: number; // 0-100 scale
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

/**
 * Convert a season start year to a display label.
 * e.g., 2025 -> "2025-26"
 */
export function seasonLabel(season: number): string {
  const nextYear = (season + 1) % 100;
  return `${season}-${nextYear.toString().padStart(2, '0')}`;
}
