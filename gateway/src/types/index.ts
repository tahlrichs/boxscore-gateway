// Canonical data types that the iOS app expects

// Golf-specific types
export interface GolferStats {
  position: number;
  score: string;           // e.g., "-12" or "E" or "+3"
  toParTotal: number;      // numeric for sorting
  rounds: string[];        // ["68", "70", "69", "72"] or ["-4", "-2", "-3", "E"]
  thru: string;            // "F" for finished, "12" for holes played
  today: string;           // Today's score relative to par
}

export interface GolferLine {
  id: string;
  name: string;
  country?: string;
  imageURL?: string;
  stats?: GolferStats;
}

export interface GolfWinner {
  name: string;
  score?: string;          // e.g., "-20" or "E"
  isDefendingChamp?: boolean;  // true if this is last year's winner for scheduled tournaments
}

export interface GolfTournament {
  id: string;
  name: string;
  tour: 'pga' | 'lpga' | 'korn_ferry';
  venue: string;
  location: string;
  startDate: string;       // "2025-01-15"
  endDate: string;         // "2025-01-18"
  currentRound: number;    // 1, 2, 3, or 4
  roundStatus: string;     // "In Progress", "Complete", "Scheduled"
  purse?: string;          // "$8,400,000"
  winner?: GolfWinner;     // Winner for completed tournaments, or defending champion for scheduled
  leaderboard: GolferLine[];
}

export interface GolfScoreboardResponse {
  league: string;
  weekStart: string;       // Monday of the week
  weekEnd: string;         // Sunday of the week
  tournaments: GolfTournament[];
  lastUpdated: string;
}

export interface League {
  id: string;
  name: string;
  sportType: string;
  season?: string;
}

export interface Team {
  id: string;
  abbrev: string;
  name: string;
  city: string;
  score?: number;
  logoURL?: string;
  primaryColor?: string;
  conference?: string;
  division?: string;
}

export interface Venue {
  id: string;
  name: string;
  city: string;
  state?: string;
}

export interface Game {
  id: string;
  startTime: string;
  status: 'scheduled' | 'live' | 'final';
  period?: string;
  clock?: string;
  overtimePeriods?: number;
  venue?: Venue;
  homeTeam: Team;
  awayTeam: Team;
  externalIds?: Record<string, string>;
}

export interface ScoreboardResponse {
  league: string;
  date: string;
  lastUpdated: string;
  games: Game[];
}

// Box Score Types
export interface PlayerStats {
  minutes?: number;
  points?: number;
  fgMade?: number;
  fgAttempted?: number;
  threeMade?: number;
  threeAttempted?: number;
  ftMade?: number;
  ftAttempted?: number;
  offRebounds?: number;
  defRebounds?: number;
  assists?: number;
  steals?: number;
  blocks?: number;
  turnovers?: number;
  fouls?: number;
  plusMinus?: number;
}

export interface PlayerLine {
  id: string;
  name: string;
  jersey?: string;
  position?: string;
  isStarter?: boolean;
  hasEnteredGame?: boolean;
  stats?: PlayerStats;
  dnpReason?: string;
}

export interface TeamTotals extends PlayerStats {
  fgPercentage?: number;
  threePercentage?: number;
  ftPercentage?: number;
  totalRebounds?: number;
}

export interface NBATeamBoxScore {
  teamId: string;
  teamName: string;
  starters: PlayerLine[];
  bench: PlayerLine[];
  dnp: PlayerLine[];
  teamTotals: TeamTotals;
}

export interface NFLTableRow {
  id: string;
  name: string;
  position: string;
  stats: Record<string, string>;  // label -> value mapping
}

export interface NFLGroup {
  name: string;  // e.g., "passing", "rushing", "receiving"
  headers: string[];  // stat column headers
  rows: NFLTableRow[];  // player rows
}

export interface NFLTeamBoxScore {
  teamId: string;
  teamName: string;
  groups: NFLGroup[];
}

// NHL Types
export interface NHLSkaterStats {
  goals: number;
  assists: number;
  plusMinus: number;
  penaltyMinutes: number;
  shots: number;
  hits: number;
  blockedShots: number;
  faceoffWins: number;
  faceoffLosses: number;
  timeOnIceSeconds: number;
  powerPlayGoals: number;
  shortHandedGoals: number;
  powerPlayAssists: number;
  shortHandedAssists: number;
  shifts: number;
}

export interface NHLSkaterLine {
  id: string;
  name: string;
  jersey: string;
  position: string;
  stats?: NHLSkaterStats;
}

export interface NHLGoalieStats {
  saves: number;
  shotsAgainst: number;
  goalsAgainst: number;
  timeOnIceSeconds: number;
  evenStrengthSaves: number;
  powerPlaySaves: number;
  shortHandedSaves: number;
  evenStrengthShotsAgainst: number;
  powerPlayShotsAgainst: number;
  shortHandedShotsAgainst: number;
}

export interface NHLGoalieLine {
  id: string;
  name: string;
  jersey: string;
  stats?: NHLGoalieStats;
  decision?: string;  // W, L, OTL
}

export interface NHLScratchPlayer {
  id: string;
  name: string;
  jersey: string;
  position: string;
  reason?: string;
}

export interface NHLTeamTotals {
  goals: number;
  assists: number;
  shots: number;
  hits: number;
  blockedShots: number;
  penaltyMinutes: number;
  faceoffWins: number;
  faceoffLosses: number;
  powerPlayGoals: number;
  powerPlayOpportunities: number;
  shortHandedGoals: number;
  takeaways: number;
  giveaways: number;
}

export interface NHLTeamBoxScore {
  teamId: string;
  teamName: string;
  skaters: NHLSkaterLine[];
  goalies: NHLGoalieLine[];
  teamTotals: NHLTeamTotals;
  scratches: NHLScratchPlayer[];
}

export interface BoxScore {
  homeTeam: NBATeamBoxScore | NFLTeamBoxScore | NHLTeamBoxScore;
  awayTeam: NBATeamBoxScore | NFLTeamBoxScore | NHLTeamBoxScore;
}

export interface BoxScoreResponse {
  game: Game;
  boxScore: BoxScore;
  lastUpdated: string;
}

// Standings Types
export interface Standing {
  teamId: string;
  abbrev: string;
  name: string;
  wins: number;
  losses: number;
  ties?: number;
  winPct: number;
  rank: number;
  gamesBack?: number;
  streak?: string;
  lastTen?: string;
}

export interface ConferenceStandings {
  name: string;
  teams: Standing[];
}

export interface StandingsResponse {
  league: string;
  season: string;
  lastUpdated: string;
  conferences: ConferenceStandings[];
}

// Roster Types
export interface Player {
  id: string;
  name: string;
  jersey?: string;
  position?: string;
  height?: string;
  weight?: string;
  birthdate?: string;
  college?: string;
}

export interface RosterResponse {
  teamId: string;
  season: string;
  lastUpdated: string;
  players: Player[];
}

// Health Check Types
export interface ProviderStatus {
  name: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  lastSuccessfulFetch?: string;
  errorCount: number;
}

export interface HealthResponse {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  providers: ProviderStatus[];
  cache: {
    connected: boolean;
    hitRate?: number;
  };
}

// Provider adapter interface
export interface RawScoreboard {
  games: unknown[];
  rawResponse: unknown;
}

export interface SportsDataProvider {
  name: string;
  fetchScoreboard(league: string, date: string): Promise<Game[]>;
  fetchGame(gameId: string): Promise<Game>;
  fetchBoxScore(gameId: string, sport: string): Promise<BoxScoreResponse>;
  fetchStandings(league: string, season?: string): Promise<StandingsResponse>;
  fetchRoster(teamId: string): Promise<RosterResponse>;
  healthCheck(): Promise<ProviderStatus>;
}
