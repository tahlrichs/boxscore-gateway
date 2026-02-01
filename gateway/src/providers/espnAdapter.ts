/**
 * ESPNAdapter - ESPN API adapter for NBA data
 * 
 * Uses ESPN's unofficial public APIs:
 * - Scoreboard: https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard
 * - Summary: https://site.web.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event={eventId}
 * 
 * These endpoints are unofficial and may change without notice.
 * Rate limited via ESPNRateLimiter (60/min, 2000/day).
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import { logger } from '../utils/logger';
import { ProviderError, RateLimitError } from '../middleware/errorHandler';
import { getESPNRateLimiter, ESPNBudgetBucket } from '../utils/ESPNRateLimiter';
import { processBoxScoreForPlayers, getSeasonFromGameDate } from './espnPlayerExtractor';
import {
  SportsDataProvider,
  Game,
  BoxScoreResponse,
  StandingsResponse,
  RosterResponse,
  ProviderStatus,
  Team,
  PlayerLine,
  NBATeamBoxScore,
  NFLTeamBoxScore,
  NFLGroup,
  NFLTableRow,
  NHLTeamBoxScore,
  NHLSkaterLine,
  NHLGoalieLine,
  NHLSkaterStats,
  NHLGoalieStats,
  NHLTeamTotals,
  TeamTotals,
  Standing,
  Venue,
  BoxScore,
  GolfTournament,
  GolferLine,
  GolferStats,
  GolfScoreboardResponse,
  GolfWinner,
} from '../types';

// ESPN API response types
interface ESPNScoreboardResponse {
  events: ESPNEvent[];
  day?: { date: string };
}

interface ESPNEvent {
  id: string;
  date: string;
  name: string;
  shortName: string;
  status: {
    clock: number;
    displayClock: string;
    period: number;
    type: {
      id: string;
      name: string;
      state: string;
      completed: boolean;
      description: string;
      detail: string;
      shortDetail: string;
    };
  };
  competitions: ESPNCompetition[];
}

interface ESPNCompetition {
  id: string;
  date?: string;  // ISO date string for game start time
  venue?: {
    id: string;
    fullName: string;
    address: {
      city: string;
      state?: string;
    };
  };
  competitors: ESPNCompetitor[];
  status: {
    clock: number;
    displayClock: string;
    period: number;
    type: {
      id: string;
      name: string;
      state: string;
      completed: boolean;
    };
  };
}

interface ESPNCompetitor {
  id: string;
  homeAway: 'home' | 'away';
  score: string;
  team: {
    id: string;
    abbreviation: string;
    displayName: string;
    shortDisplayName: string;
    location: string;
    logo: string;
    color?: string;
    conferenceId?: string;
  };
  records?: Array<{
    name: string;
    summary: string;
  }>;
}

// ESPN Conference ID mappings for college sports
// Names must match iOS CollegeConference names for filtering to work
const ESPN_CONFERENCE_MAP: Record<string, string> = {
  // NCAAM / NCAAF conferences
  '1': 'AAC',           // American Athletic Conference
  '2': 'ACC',           // Atlantic Coast Conference
  '3': 'A-10',          // Atlantic 10 (NCAAM only)
  '4': 'Big East',      // Big East
  '5': 'Big Sky',       // Big Sky
  '6': 'Big South',     // Big South
  '7': 'Big Ten',       // Big Ten
  '8': 'Big 12',        // Big 12
  '9': 'C-USA',         // Conference USA
  '10': 'Ivy',          // Ivy League
  '11': 'MAAC',         // Metro Atlantic Athletic
  '12': 'MAC',          // Mid-American Conference
  '13': 'MEAC',         // Mid-Eastern Athletic
  '14': 'MWC',          // Mountain West
  '15': 'NEC',          // Northeast
  '16': 'OVC',          // Ohio Valley
  '17': 'Pac-12',       // Pac-12
  '18': 'Patriot',      // Patriot League
  '19': 'SEC',          // Southeastern Conference (old ID)
  '20': 'SoCon',        // Southern Conference
  '21': 'Southland',    // Southland
  '22': 'SWAC',         // Southwestern Athletic
  '23': 'SEC',          // Southeastern Conference
  '24': 'Summit',       // Summit League
  '25': 'Sun Belt',     // Sun Belt
  '26': 'WAC',          // Western Athletic
  '27': 'WCC',          // West Coast Conference
  '29': 'ASUN',         // Atlantic Sun / ASUN
  '30': 'Horizon',      // Horizon League
  '31': 'MVC',          // Missouri Valley
  '32': 'CAA',          // Colonial Athletic Association
  '33': 'America East', // America East
  '34': 'Big West',     // Big West
  '35': 'Independent',  // FBS/FCS Independents
  '37': 'C-USA',        // Conference USA (alternate)
  '40': 'Independent',  // Independent (alternate)
  '46': 'AAC',          // American Athletic Conference (alternate ID)
  '50': 'Big 12',       // Big 12 (alternate ID used in some calls)
  '62': 'AAC',          // American Athletic Conference (football)
  '80': 'Independent',  // FBS Independents
  '81': 'Sun Belt',     // Sun Belt (alternate)
  '151': 'AAC',         // American Athletic Conference
};

export interface ESPNSummaryResponse {
  boxscore: {
    teams: ESPNBoxscoreTeam[];
    players: ESPNBoxscorePlayers[];
  };
  header: {
    id: string;
    competitions: ESPNCompetition[];
  };
  gameInfo?: {
    venue?: {
      id: string;
      fullName: string;
      address: {
        city: string;
        state?: string;
      };
    };
  };
}

interface ESPNBoxscoreTeam {
  team: {
    id: string;
    abbreviation: string;
    displayName: string;
    shortDisplayName: string;
    location: string;
    logo: string;
  };
  statistics: Array<{
    name: string;
    displayValue: string;
  }>;
}

interface ESPNBoxscorePlayers {
  team: {
    id: string;
    abbreviation: string;
    displayName: string;
    shortDisplayName: string;
    location: string;
    logo: string;
  };
  statistics: Array<{
    name?: string;  // Category name for NFL (e.g., "passing", "rushing")
    names: string[];
    keys: string[];
    labels: string[];
    descriptions: string[];
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
  ejected?: boolean;
  stats: string[];
}

/**
 * ESPN Adapter for NBA data
 */
export class ESPNAdapter implements SportsDataProvider {
  readonly name = 'espn';
  
  private client: AxiosInstance;
  private lastError: Error | null = null;
  private errorCount = 0;
  private lastSuccessfulFetch: Date | null = null;

  constructor() {
    this.client = axios.create({
      timeout: 15000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'BoxScore/1.0',
      },
    });

    this.client.interceptors.response.use(
      (response) => {
        this.lastSuccessfulFetch = new Date();
        this.errorCount = 0;
        getESPNRateLimiter().recordSuccess();
        return response;
      },
      (error: AxiosError) => {
        this.lastError = error;
        this.errorCount++;
        
        // Record error for adaptive backoff
        const isTimeout = error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT';
        const statusCode = error.response?.status || 0;
        getESPNRateLimiter().recordError(statusCode, isTimeout);
        
        throw error;
      }
    );
  }

  /**
   * Execute a rate-limited request
   */
  private async rateLimitedRequest<T>(
    bucket: ESPNBudgetBucket,
    requestFn: () => Promise<T>
  ): Promise<T> {
    const rateLimiter = getESPNRateLimiter();
    const check = rateLimiter.canMakeRequest(bucket);
    
    if (!check.allowed) {
      logger.warn('ESPNAdapter: Request blocked by rate limiter', {
        bucket,
        reason: check.reason,
        retryAfterMs: check.retryAfterMs,
      });
      
      if (check.retryAfterMs) {
        throw new RateLimitError(`Rate limit: ${check.reason}`);
      }
      throw new ProviderError(`Rate limit: ${check.reason}`);
    }
    
    rateLimiter.recordRequest(bucket);
    return requestFn();
  }

  // ===== SPORT CONFIG =====
  
  private getSportConfig(league: string): { sport: string; sportPath: string; leaguePrefix: string } {
    const leagueLower = league.toLowerCase();
    switch (leagueLower) {
      case 'nba':
        return { sport: 'basketball', sportPath: 'basketball/nba', leaguePrefix: 'nba' };
      case 'nfl':
        return { sport: 'football', sportPath: 'football/nfl', leaguePrefix: 'nfl' };
      case 'ncaaf':
        return { sport: 'football', sportPath: 'football/college-football', leaguePrefix: 'ncaaf' };
      case 'ncaam':
        return { sport: 'basketball', sportPath: 'basketball/mens-college-basketball', leaguePrefix: 'ncaam' };
      case 'mlb':
        return { sport: 'baseball', sportPath: 'baseball/mlb', leaguePrefix: 'mlb' };
      case 'nhl':
        return { sport: 'hockey', sportPath: 'hockey/nhl', leaguePrefix: 'nhl' };
      case 'pga':
        return { sport: 'golf', sportPath: 'golf/pga', leaguePrefix: 'pga' };
      case 'lpga':
        return { sport: 'golf', sportPath: 'golf/lpga', leaguePrefix: 'lpga' };
      case 'korn_ferry':
        return { sport: 'golf', sportPath: 'golf/korn-ferry', leaguePrefix: 'korn_ferry' };
      default:
        throw new ProviderError(`ESPN adapter does not support league: ${league}`);
    }
  }
  
  /**
   * Check if a league uses football-style box scores
   */
  private isFootballLeague(league: string): boolean {
    const leagueLower = league.toLowerCase();
    return leagueLower === 'nfl' || leagueLower === 'ncaaf';
  }
  
  /**
   * Check if a league uses basketball-style box scores
   */
  private isBasketballLeague(league: string): boolean {
    const leagueLower = league.toLowerCase();
    return leagueLower === 'nba' || leagueLower === 'ncaam';
  }
  
  /**
   * Check if a league uses hockey-style box scores
   */
  private isHockeyLeague(league: string): boolean {
    const leagueLower = league.toLowerCase();
    return leagueLower === 'nhl';
  }

  /**
   * Check if a league is a golf league
   */
  private isGolfLeague(league: string): boolean {
    const leagueLower = league.toLowerCase();
    return leagueLower === 'pga' || leagueLower === 'lpga' || leagueLower === 'korn_ferry';
  }

  // ===== SCOREBOARD =====
  
  async fetchScoreboard(league: string, date: string): Promise<Game[]> {
    const config = this.getSportConfig(league);

    try {
      const games = await this.rateLimitedRequest('scoreboard', async () => {
        // Format date as YYYYMMDD for ESPN API
        const espnDate = date.replace(/-/g, '');
        const url = `https://site.api.espn.com/apis/site/v2/sports/${config.sportPath}/scoreboard?dates=${espnDate}`;
        
        logger.debug('ESPNAdapter: Fetching scoreboard', { url, date, league });
        const response = await this.client.get<ESPNScoreboardResponse>(url);

        logger.debug('ESPNAdapter: Scoreboard response', {
          eventsCount: response.data.events?.length || 0,
          date,
          league,
          firstEvent: response.data.events?.[0] ? { id: response.data.events[0].id, name: response.data.events[0].name } : null
        });

        return response.data.events.map((event) => this.transformEvent(event, config.leaguePrefix));
      });
      
      return games;
    } catch (error) {
      if (error instanceof ProviderError) throw error;
      const errMsg = error instanceof Error ? error.message : String(error);
      logger.error('ESPNAdapter: Failed to fetch scoreboard', { date, league, error: errMsg });
      throw new ProviderError(`Failed to fetch scoreboard from ESPN: ${errMsg}`);
    }
  }

  // ===== SINGLE GAME =====
  
  async fetchGame(gameId: string): Promise<Game> {
    // Extract ESPN event ID and league from internal ID (nba_401584701 -> 401584701)
    const { league, espnId } = this.parseGameId(gameId);
    const config = this.getSportConfig(league);
    
    try {
      const game = await this.rateLimitedRequest('gameSummary', async () => {
        const url = `https://site.web.api.espn.com/apis/site/v2/sports/${config.sportPath}/summary?event=${espnId}`;
        
        logger.debug('ESPNAdapter: Fetching game', { url, gameId, league });
        const response = await this.client.get<ESPNSummaryResponse>(url);
        
        return this.transformSummaryToGame(response.data, espnId, config.leaguePrefix);
      });
      
      return game;
    } catch (error) {
      if (error instanceof ProviderError) throw error;
      const errMsg = error instanceof Error ? error.message : String(error);
      logger.error('ESPNAdapter: Failed to fetch game', { gameId, error: errMsg });
      throw new ProviderError(`Failed to fetch game from ESPN: ${errMsg}`);
    }
  }

  // ===== BOX SCORE =====
  
  async fetchBoxScore(gameId: string, sport: string): Promise<BoxScoreResponse> {
    const { league, espnId } = this.parseGameId(gameId);
    const config = this.getSportConfig(league);

    try {
      const boxScoreResponse = await this.rateLimitedRequest('gameSummary', async () => {
        const url = `https://site.web.api.espn.com/apis/site/v2/sports/${config.sportPath}/summary?event=${espnId}`;

        logger.debug('ESPNAdapter: Fetching box score', { url, gameId, league });
        const response = await this.client.get<ESPNSummaryResponse>(url);

        const game = this.transformSummaryToGame(response.data, espnId, config.leaguePrefix);
        const boxScore = this.transformBoxScore(response.data, config.leaguePrefix);

        // Auto-extract players from box score (basketball leagues only)
        if (this.isBasketballLeague(league)) {
          try {
            const gameDate = response.data.header?.competitions?.[0]?.date
              ? new Date(response.data.header.competitions[0].date)
              : new Date();
            const season = getSeasonFromGameDate(gameDate, config.leaguePrefix);

            // Run extraction asynchronously (don't block response)
            processBoxScoreForPlayers(response.data, config.leaguePrefix, season)
              .then(() => {
                logger.debug('ESPNAdapter: Player extraction completed', { gameId });
              })
              .catch((err) => {
                logger.warn('ESPNAdapter: Player extraction failed', {
                  gameId,
                  error: err instanceof Error ? err.message : String(err),
                });
              });
          } catch (extractionError) {
            logger.warn('ESPNAdapter: Failed to initiate player extraction', {
              gameId,
              error: extractionError instanceof Error ? extractionError.message : String(extractionError),
            });
          }
        }

        return {
          game,
          boxScore,
          lastUpdated: new Date().toISOString(),
        };
      });

      return boxScoreResponse;
    } catch (error) {
      if (error instanceof ProviderError) throw error;
      const errMsg = error instanceof Error ? error.message : String(error);
      logger.error('ESPNAdapter: Failed to fetch box score', { gameId, error: errMsg });
      throw new ProviderError(`Failed to fetch box score from ESPN: ${errMsg}`);
    }
  }

  // ===== RAW SUMMARY (for player ingestion) =====

  /**
   * Fetch raw ESPN summary response for a game, going through the rate limiter.
   * Used by player ingestion to get the full summary JSON without transforming it.
   */
  async fetchRawSummary(gameId: string): Promise<ESPNSummaryResponse> {
    const { league, espnId } = this.parseGameId(gameId);
    const config = this.getSportConfig(league);

    return this.rateLimitedRequest('gameSummary', async () => {
      const url = `https://site.web.api.espn.com/apis/site/v2/sports/${config.sportPath}/summary?event=${espnId}`;

      logger.debug('ESPNAdapter: Fetching raw summary', { url, gameId, league });
      const response = await this.client.get<ESPNSummaryResponse>(url);

      return response.data;
    });
  }

  // ===== STANDINGS (Phase 2) =====
  
  async fetchStandings(league: string, season?: string): Promise<StandingsResponse> {
    // Phase 2 implementation
    throw new ProviderError('Standings not yet implemented for ESPN adapter');
  }

  // ===== ROSTER =====
  
  async fetchRoster(teamId: string): Promise<RosterResponse> {
    throw new ProviderError('Roster not implemented for ESPN adapter');
  }

  // ===== HEALTH CHECK =====
  
  async healthCheck(): Promise<ProviderStatus> {
    try {
      // Simple health check - just verify we can reach the API
      const rateLimiter = getESPNRateLimiter();
      const status = rateLimiter.getStatus();
      
      // If we're in backoff or exhausted, report degraded
      if (status.backoff.active || status.daily.remaining <= 0) {
        return {
          name: this.name,
          status: 'degraded',
          lastSuccessfulFetch: this.lastSuccessfulFetch?.toISOString(),
          errorCount: this.errorCount,
        };
      }
      
      return {
        name: this.name,
        status: this.errorCount > 5 ? 'degraded' : 'healthy',
        lastSuccessfulFetch: this.lastSuccessfulFetch?.toISOString(),
        errorCount: this.errorCount,
      };
    } catch {
      return {
        name: this.name,
        status: 'unhealthy',
        lastSuccessfulFetch: this.lastSuccessfulFetch?.toISOString(),
        errorCount: this.errorCount,
      };
    }
  }

  // ===== TRANSFORMERS =====

  /**
   * Parse game ID to extract league and ESPN event ID
   * nba_401584701 -> { league: 'nba', espnId: '401584701' }
   * nfl_401547890 -> { league: 'nfl', espnId: '401547890' }
   */
  private parseGameId(gameId: string): { league: string; espnId: string } {
    const parts = gameId.split('_');
    if (parts.length >= 2) {
      return { league: parts[0], espnId: parts.slice(1).join('_') };
    }
    // Default to NBA for backwards compatibility
    return { league: 'nba', espnId: gameId };
  }

  /**
   * Extract ESPN event ID from internal game ID (legacy, use parseGameId instead)
   * nba_401584701 -> 401584701
   */
  private extractESPNId(gameId: string): string {
    return this.parseGameId(gameId).espnId;
  }

  /**
   * Transform ESPN event to canonical Game
   */
  private transformEvent(event: ESPNEvent, leaguePrefix: string = 'nba'): Game {
    const competition = event.competitions[0];
    const homeCompetitor = competition.competitors.find(c => c.homeAway === 'home')!;
    const awayCompetitor = competition.competitors.find(c => c.homeAway === 'away')!;

    // Determine period label based on sport
    const periodLabel = this.isFootballLeague(leaguePrefix) ? this.getNFLPeriodLabel(event.status.period) :
                        leaguePrefix === 'nhl' ? `P${event.status.period}` :
                        `Q${event.status.period}`;

    // Determine overtime periods based on sport (NBA/NCAAM has 4 quarters or 2 halves, NFL/NCAAF has 4 quarters, NHL has 3 periods)
    const regularPeriods = leaguePrefix === 'nhl' ? 3 : 4;
    const overtimePeriods = event.status.period > regularPeriods ? event.status.period - regularPeriods : undefined;

    const gameStatus = this.mapGameStatus(event.status.type.name);

    return {
      id: `${leaguePrefix}_${event.id}`,
      startTime: event.date,
      status: gameStatus,
      period: gameStatus !== 'scheduled' && event.status.period > 0 ? periodLabel : undefined,
      clock: gameStatus !== 'scheduled' && event.status.displayClock ? event.status.displayClock : undefined,
      overtimePeriods,
      venue: competition.venue ? {
        id: `venue_${competition.venue.id}`,
        name: competition.venue.fullName,
        city: competition.venue.address?.city || '',
        state: competition.venue.address?.state,
      } : undefined,
      homeTeam: this.transformCompetitorToTeam(homeCompetitor, leaguePrefix, gameStatus),
      awayTeam: this.transformCompetitorToTeam(awayCompetitor, leaguePrefix, gameStatus),
      externalIds: {
        espn: event.id,
      },
    };
  }
  
  /**
   * Get NFL period label
   */
  private getNFLPeriodLabel(period: number): string {
    switch (period) {
      case 1: return '1st';
      case 2: return '2nd';
      case 3: return '3rd';
      case 4: return '4th';
      case 5: return 'OT';
      default: return `OT${period - 4}`;
    }
  }

  /**
   * Transform ESPN competitor to canonical Team
   */
  private transformCompetitorToTeam(competitor: ESPNCompetitor, leaguePrefix: string = 'nba', gameStatus?: string): Team {
    // Map conference ID to conference name for college sports
    // Access the raw team object to get conferenceId (may not be in typed interface)
    const teamData = competitor.team as any;
    const conferenceId = teamData.conferenceId;
    const conference = conferenceId
      ? (ESPN_CONFERENCE_MAP[conferenceId] ?? `Conference ${conferenceId}`)
      : undefined;

    if (conferenceId) {
      logger.debug('ESPNAdapter: Team conference mapping', {
        team: competitor.team.abbreviation,
        conferenceId,
        conference,
        isMapped: conferenceId in ESPN_CONFERENCE_MAP
      });
    }

    // For scheduled games, don't include score (leave as undefined)
    // This prevents the iOS app from showing "0" for games that haven't started
    let score: number | undefined;
    if (gameStatus === 'scheduled') {
      score = undefined;
    } else {
      const parsed = parseInt(competitor.score, 10);
      score = isNaN(parsed) ? 0 : parsed;
    }

    return {
      id: `${leaguePrefix}_${competitor.team.id}`,
      abbrev: competitor.team.abbreviation,
      name: competitor.team.shortDisplayName || competitor.team.displayName,
      city: competitor.team.location,
      score,
      logoURL: competitor.team.logo,
      primaryColor: competitor.team.color ? `#${competitor.team.color}` : undefined,
      conference,
    };
  }

  /**
   * Transform ESPN summary response to canonical Game
   */
  private transformSummaryToGame(summary: ESPNSummaryResponse, espnEventId: string, leaguePrefix: string = 'nba'): Game {
    const competition = summary.header.competitions[0];

    if (!competition || !competition.competitors) {
      throw new ProviderError('Invalid ESPN summary response: missing competition or competitors');
    }

    const homeCompetitor = competition.competitors.find(c => c.homeAway === 'home');
    const awayCompetitor = competition.competitors.find(c => c.homeAway === 'away');

    if (!homeCompetitor || !awayCompetitor) {
      throw new ProviderError('Invalid ESPN summary response: missing home or away competitor');
    }

    const venue = summary.gameInfo?.venue || competition.venue;

    // Determine period label based on sport
    const periodLabel = this.isFootballLeague(leaguePrefix) ? this.getNFLPeriodLabel(competition.status.period) :
                        leaguePrefix === 'nhl' ? `P${competition.status.period}` :
                        `Q${competition.status.period}`;

    // Determine overtime periods based on sport
    const regularPeriods = leaguePrefix === 'nhl' ? 3 : 4;
    const overtimePeriods = competition.status.period > regularPeriods ? competition.status.period - regularPeriods : undefined;

    // Get start time from competition header (available in summary response)
    const startTime = competition.date || new Date().toISOString();

    const gameStatus = this.mapGameStatus(competition.status.type.name);

    return {
      id: `${leaguePrefix}_${espnEventId}`,
      startTime,
      status: gameStatus,
      period: gameStatus !== 'scheduled' && competition.status.period > 0 ? periodLabel : undefined,
      clock: gameStatus !== 'scheduled' && competition.status.displayClock ? competition.status.displayClock : undefined,
      overtimePeriods,
      venue: venue ? {
        id: `venue_${venue.id}`,
        name: venue.fullName,
        city: venue.address?.city || '',
        state: venue.address?.state,
      } : undefined,
      homeTeam: this.transformCompetitorToTeam(homeCompetitor, leaguePrefix, gameStatus),
      awayTeam: this.transformCompetitorToTeam(awayCompetitor, leaguePrefix, gameStatus),
      externalIds: {
        espn: espnEventId,
      },
    };
  }

  /**
   * Transform ESPN box score data to canonical BoxScore
   */
  private transformBoxScore(summary: ESPNSummaryResponse, leaguePrefix: string = 'nba'): BoxScore {
    const competition = summary.header.competitions[0];

    if (!competition || !competition.competitors) {
      throw new ProviderError('Invalid ESPN box score response: missing competition or competitors');
    }

    const homeCompetitor = competition.competitors.find(c => c.homeAway === 'home');
    const awayCompetitor = competition.competitors.find(c => c.homeAway === 'away');

    if (!homeCompetitor || !awayCompetitor) {
      throw new ProviderError('Invalid ESPN box score response: missing home or away competitor');
    }

    // Find player data for each team
    const homePlayerData = summary.boxscore?.players?.find(
      p => p.team.id === homeCompetitor.team.id
    );
    const awayPlayerData = summary.boxscore?.players?.find(
      p => p.team.id === awayCompetitor.team.id
    );
    
    // Football leagues (NFL, NCAAF) use different box score format than basketball
    if (this.isFootballLeague(leaguePrefix)) {
      return {
        homeTeam: this.transformNFLTeamBoxScore(
          homeCompetitor.team.id,
          homeCompetitor.team.displayName,
          homePlayerData,
          leaguePrefix
        ),
        awayTeam: this.transformNFLTeamBoxScore(
          awayCompetitor.team.id,
          awayCompetitor.team.displayName,
          awayPlayerData,
          leaguePrefix
        ),
      };
    }
    
    // Hockey leagues (NHL) use different box score format
    if (this.isHockeyLeague(leaguePrefix)) {
      return {
        homeTeam: this.transformNHLTeamBoxScore(
          homeCompetitor.team.id,
          homeCompetitor.team.displayName,
          homePlayerData,
          leaguePrefix
        ),
        awayTeam: this.transformNHLTeamBoxScore(
          awayCompetitor.team.id,
          awayCompetitor.team.displayName,
          awayPlayerData,
          leaguePrefix
        ),
      };
    }
    
    return {
      homeTeam: this.transformTeamBoxScore(
        homeCompetitor.team.id,
        homeCompetitor.team.displayName,
        homePlayerData,
        leaguePrefix
      ),
      awayTeam: this.transformTeamBoxScore(
        awayCompetitor.team.id,
        awayCompetitor.team.displayName,
        awayPlayerData,
        leaguePrefix
      ),
    };
  }
  
  /**
   * Transform ESPN football player data to canonical NFLTeamBoxScore
   * Used for both NFL and NCAAF
   */
  private transformNFLTeamBoxScore(
    teamId: string,
    teamName: string,
    playerData?: ESPNBoxscorePlayers,
    leaguePrefix: string = 'nfl'
  ): NFLTeamBoxScore {
    if (!playerData || !playerData.statistics?.length) {
      return {
        teamId: `${leaguePrefix}_${teamId}`,
        teamName,
        groups: [],
      };
    }
    
    const groups: NFLGroup[] = [];
    
    // Each statistics entry is a category (passing, rushing, receiving, etc.)
    for (const stat of playerData.statistics) {
      const rows: NFLTableRow[] = [];
      const labels = stat.labels || [];
      
      for (const athlete of (stat.athletes || [])) {
        const athleteStats = athlete.stats || [];
        
        // Create stat map from labels and values
        const statMap: Record<string, string> = {};
        labels.forEach((label, idx) => {
          statMap[label] = athleteStats[idx] || '-';
        });
        
        rows.push({
          id: athlete.athlete?.id || '',
          name: athlete.athlete?.displayName || 'Unknown',
          position: athlete.athlete?.position?.abbreviation || '',
          stats: statMap,
        });
      }
      
      groups.push({
        name: stat.name || 'Unknown',
        headers: labels,
        rows,
      });
    }
    
    return {
      teamId: `${leaguePrefix}_${teamId}`,
      teamName,
      groups,
    };
  }
  
  /**
   * Transform ESPN hockey player data to canonical NHLTeamBoxScore
   */
  private transformNHLTeamBoxScore(
    teamId: string,
    teamName: string,
    playerData?: ESPNBoxscorePlayers,
    leaguePrefix: string = 'nhl'
  ): NHLTeamBoxScore {
    if (!playerData || !playerData.statistics?.length) {
      return {
        teamId: `${leaguePrefix}_${teamId}`,
        teamName,
        skaters: [],
        goalies: [],
        teamTotals: this.emptyNHLTeamTotals(),
        scratches: [],
      };
    }
    
    const skaters: NHLSkaterLine[] = [];
    const goalies: NHLGoalieLine[] = [];
    
    // Process each statistics category
    for (const stat of playerData.statistics) {
      const categoryName = (stat.name || '').toLowerCase();
      const labels = stat.labels || [];
      const athletes = stat.athletes || [];

      // Log category for debugging
      logger.debug('ESPNAdapter NHL: Processing category', {
        teamId,
        categoryName,
        athleteCount: athletes.length
      });

      // Create label index for parsing
      const labelIndex: Record<string, number> = {};
      labels.forEach((label, idx) => {
        labelIndex[label.toUpperCase()] = idx;
      });

      for (const athlete of athletes) {
        if (athlete.didNotPlay) continue;

        const stats = athlete.stats || [];
        const position = athlete.athlete?.position?.abbreviation || '';

        // Check if this is a goalie
        if (position === 'G' || categoryName === 'goalies' || categoryName === 'goaltending') {
          const goalieStats = this.parseNHLGoalieStats(stats, labelIndex);
          goalies.push({
            id: `player_${athlete.athlete?.id || ''}`,
            name: athlete.athlete?.shortName || athlete.athlete?.displayName || 'Unknown',
            jersey: athlete.athlete?.jersey || '',
            stats: goalieStats,
            decision: this.extractGoalieDecision(stats, labelIndex),
          });
        } else if (categoryName === 'skaters' || categoryName === 'forwards' || categoryName === 'defensemen' || categoryName === 'defense' || categoryName === 'defenses' || position === 'D' || !categoryName) {
          // Include all skaters: forwards category, defenses category, or position D
          const skaterStats = this.parseNHLSkaterStats(stats, labelIndex);
          skaters.push({
            id: `player_${athlete.athlete?.id || ''}`,
            name: athlete.athlete?.shortName || athlete.athlete?.displayName || 'Unknown',
            jersey: athlete.athlete?.jersey || '',
            position,
            stats: skaterStats,
          });
        } else {
          // Log unmatched categories for debugging
          logger.debug('ESPNAdapter NHL: Skipped category/position', {
            categoryName,
            position,
            athleteName: athlete.athlete?.displayName
          });
        }
      }
    }
    
    // Calculate team totals
    const teamTotals = this.calculateNHLTeamTotals(skaters);
    
    return {
      teamId: `${leaguePrefix}_${teamId}`,
      teamName,
      skaters,
      goalies,
      teamTotals,
      scratches: [],
    };
  }
  
  /**
   * Parse NHL skater stats from ESPN format
   */
  private parseNHLSkaterStats(stats: string[], labelIndex: Record<string, number>): NHLSkaterStats {
    const getStat = (label: string): string | undefined => {
      const idx = labelIndex[label.toUpperCase()];
      return idx !== undefined ? stats[idx] : undefined;
    };
    
    const parseNumber = (val: string | undefined): number => {
      if (!val || val === '-' || val === '') return 0;
      return parseInt(val, 10) || 0;
    };
    
    const parseTimeOnIce = (val: string | undefined): number => {
      if (!val || val === '-' || val === '') return 0;
      // ESPN time format: "MM:SS" -> convert to seconds
      const parts = val.split(':');
      if (parts.length === 2) {
        return (parseInt(parts[0], 10) || 0) * 60 + (parseInt(parts[1], 10) || 0);
      }
      return parseInt(val, 10) || 0;
    };
    
    return {
      goals: parseNumber(getStat('G')),
      assists: parseNumber(getStat('A')),
      plusMinus: parseNumber(getStat('+/-')),
      penaltyMinutes: parseNumber(getStat('PIM')),
      shots: parseNumber(getStat('SOG') || getStat('S')),
      hits: parseNumber(getStat('HIT') || getStat('HITS')),
      blockedShots: parseNumber(getStat('BLK') || getStat('BS')),
      faceoffWins: parseNumber(getStat('FW')),
      faceoffLosses: parseNumber(getStat('FL')),
      timeOnIceSeconds: parseTimeOnIce(getStat('TOI')),
      powerPlayGoals: parseNumber(getStat('PPG')),
      shortHandedGoals: parseNumber(getStat('SHG')),
      powerPlayAssists: parseNumber(getStat('PPA')),
      shortHandedAssists: parseNumber(getStat('SHA')),
      shifts: parseNumber(getStat('SHFT') || getStat('SH')),
    };
  }
  
  /**
   * Parse NHL goalie stats from ESPN format
   */
  private parseNHLGoalieStats(stats: string[], labelIndex: Record<string, number>): NHLGoalieStats {
    const getStat = (label: string): string | undefined => {
      const idx = labelIndex[label.toUpperCase()];
      return idx !== undefined ? stats[idx] : undefined;
    };
    
    const parseNumber = (val: string | undefined): number => {
      if (!val || val === '-' || val === '') return 0;
      return parseInt(val, 10) || 0;
    };
    
    const parseTimeOnIce = (val: string | undefined): number => {
      if (!val || val === '-' || val === '') return 0;
      const parts = val.split(':');
      if (parts.length === 2) {
        return (parseInt(parts[0], 10) || 0) * 60 + (parseInt(parts[1], 10) || 0);
      }
      return parseInt(val, 10) || 0;
    };
    
    const saves = parseNumber(getStat('SV') || getStat('SAVES'));
    const shotsAgainst = parseNumber(getStat('SA'));
    const goalsAgainst = parseNumber(getStat('GA'));
    
    return {
      saves,
      shotsAgainst,
      goalsAgainst,
      timeOnIceSeconds: parseTimeOnIce(getStat('TOI')),
      evenStrengthSaves: parseNumber(getStat('EVSV')),
      powerPlaySaves: parseNumber(getStat('PPSV')),
      shortHandedSaves: parseNumber(getStat('SHSV')),
      evenStrengthShotsAgainst: parseNumber(getStat('EVSA')),
      powerPlayShotsAgainst: parseNumber(getStat('PPSA')),
      shortHandedShotsAgainst: parseNumber(getStat('SHSA')),
    };
  }
  
  /**
   * Extract goalie decision (W/L/OTL) from stats
   */
  private extractGoalieDecision(stats: string[], labelIndex: Record<string, number>): string | undefined {
    const idx = labelIndex['DEC'] ?? labelIndex['DECISION'];
    if (idx !== undefined && stats[idx] && stats[idx] !== '-') {
      return stats[idx];
    }
    return undefined;
  }
  
  /**
   * Calculate NHL team totals from skaters
   */
  private calculateNHLTeamTotals(skaters: NHLSkaterLine[]): NHLTeamTotals {
    const totals: NHLTeamTotals = this.emptyNHLTeamTotals();
    
    for (const skater of skaters) {
      if (skater.stats) {
        totals.goals += skater.stats.goals;
        totals.assists += skater.stats.assists;
        totals.shots += skater.stats.shots;
        totals.hits += skater.stats.hits;
        totals.blockedShots += skater.stats.blockedShots;
        totals.penaltyMinutes += skater.stats.penaltyMinutes;
        totals.faceoffWins += skater.stats.faceoffWins;
        totals.faceoffLosses += skater.stats.faceoffLosses;
        totals.powerPlayGoals += skater.stats.powerPlayGoals;
        totals.shortHandedGoals += skater.stats.shortHandedGoals;
      }
    }
    
    return totals;
  }
  
  /**
   * Create empty NHL team totals
   */
  private emptyNHLTeamTotals(): NHLTeamTotals {
    return {
      goals: 0,
      assists: 0,
      shots: 0,
      hits: 0,
      blockedShots: 0,
      penaltyMinutes: 0,
      faceoffWins: 0,
      faceoffLosses: 0,
      powerPlayGoals: 0,
      powerPlayOpportunities: 0,
      shortHandedGoals: 0,
      takeaways: 0,
      giveaways: 0,
    };
  }

  /**
   * Transform ESPN player data to canonical NBATeamBoxScore
   */
  private transformTeamBoxScore(
    teamId: string,
    teamName: string,
    playerData?: ESPNBoxscorePlayers,
    leaguePrefix: string = 'nba'
  ): NBATeamBoxScore {
    if (!playerData || !playerData.statistics?.[0]) {
      return {
        teamId: `${leaguePrefix}_${teamId}`,
        teamName,
        starters: [],
        bench: [],
        dnp: [],
        teamTotals: this.emptyTeamTotals(),
      };
    }

    const stats = playerData.statistics[0];
    const labels = stats.labels || [];
    const athletes = stats.athletes || [];

    const starters: PlayerLine[] = [];
    const bench: PlayerLine[] = [];
    const dnp: PlayerLine[] = [];

    for (const athlete of athletes) {
      const playerLine = this.transformAthlete(athlete, labels);
      
      if (athlete.didNotPlay) {
        dnp.push({
          ...playerLine,
          dnpReason: athlete.reason || 'DNP',
        });
      } else if (athlete.starter) {
        starters.push(playerLine);
      } else {
        bench.push(playerLine);
      }
    }

    // Calculate team totals from active players
    const activePlayers = [...starters, ...bench];
    const teamTotals = this.calculateTeamTotals(activePlayers);

    return {
      teamId: `${leaguePrefix}_${teamId}`,
      teamName,
      starters,
      bench,
      dnp,
      teamTotals,
    };
  }

  /**
   * Transform ESPN athlete to canonical PlayerLine
   */
  private transformAthlete(athlete: ESPNAthlete, labels: string[]): PlayerLine {
    const stats = athlete.stats || [];
    
    // Create label-to-index mapping
    const labelIndex: Record<string, number> = {};
    labels.forEach((label, idx) => {
      labelIndex[label.toUpperCase()] = idx;
    });

    // Parse stats based on labels
    const playerStats = this.parsePlayerStats(stats, labelIndex);

    return {
      id: `player_${athlete.athlete.id}`,
      name: athlete.athlete.shortName || athlete.athlete.displayName,
      jersey: athlete.athlete.jersey || '',
      position: athlete.athlete.position?.abbreviation || '',
      isStarter: athlete.starter,
      hasEnteredGame: !athlete.didNotPlay,
      stats: playerStats,
    };
  }

  /**
   * Parse player stats from ESPN format
   */
  private parsePlayerStats(
    stats: string[],
    labelIndex: Record<string, number>
  ): PlayerLine['stats'] {
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

    const parseMinutes = (val: string | undefined): number => {
      if (!val || val === '-' || val === '') return 0;
      // ESPN minutes can be "32" or "32:45"
      const parts = val.split(':');
      return parseInt(parts[0], 10) || 0;
    };

    const [fgMade, fgAttempted] = parseMadeAttempted(getStat('FG'));
    const [threeMade, threeAttempted] = parseMadeAttempted(getStat('3PT'));
    const [ftMade, ftAttempted] = parseMadeAttempted(getStat('FT'));

    return {
      minutes: parseMinutes(getStat('MIN')),
      points: parseNumber(getStat('PTS')),
      fgMade,
      fgAttempted,
      threeMade,
      threeAttempted,
      ftMade,
      ftAttempted,
      offRebounds: parseNumber(getStat('OREB')),
      defRebounds: parseNumber(getStat('DREB')),
      assists: parseNumber(getStat('AST')),
      steals: parseNumber(getStat('STL')),
      blocks: parseNumber(getStat('BLK')),
      turnovers: parseNumber(getStat('TO')),
      fouls: parseNumber(getStat('PF')),
      plusMinus: parseNumber(getStat('+/-')),
    };
  }

  /**
   * Calculate team totals from player stats
   */
  private calculateTeamTotals(players: PlayerLine[]): TeamTotals {
    const totals: TeamTotals = this.emptyTeamTotals();

    for (const player of players) {
      if (player.stats) {
        totals.minutes = (totals.minutes || 0) + (player.stats.minutes || 0);
        totals.points = (totals.points || 0) + (player.stats.points || 0);
        totals.fgMade = (totals.fgMade || 0) + (player.stats.fgMade || 0);
        totals.fgAttempted = (totals.fgAttempted || 0) + (player.stats.fgAttempted || 0);
        totals.threeMade = (totals.threeMade || 0) + (player.stats.threeMade || 0);
        totals.threeAttempted = (totals.threeAttempted || 0) + (player.stats.threeAttempted || 0);
        totals.ftMade = (totals.ftMade || 0) + (player.stats.ftMade || 0);
        totals.ftAttempted = (totals.ftAttempted || 0) + (player.stats.ftAttempted || 0);
        totals.offRebounds = (totals.offRebounds || 0) + (player.stats.offRebounds || 0);
        totals.defRebounds = (totals.defRebounds || 0) + (player.stats.defRebounds || 0);
        totals.assists = (totals.assists || 0) + (player.stats.assists || 0);
        totals.steals = (totals.steals || 0) + (player.stats.steals || 0);
        totals.blocks = (totals.blocks || 0) + (player.stats.blocks || 0);
        totals.turnovers = (totals.turnovers || 0) + (player.stats.turnovers || 0);
        totals.fouls = (totals.fouls || 0) + (player.stats.fouls || 0);
      }
    }

    // Calculate percentages
    totals.fgPercentage = totals.fgAttempted! > 0 
      ? (totals.fgMade! / totals.fgAttempted!) * 100 
      : 0;
    totals.threePercentage = totals.threeAttempted! > 0 
      ? (totals.threeMade! / totals.threeAttempted!) * 100 
      : 0;
    totals.ftPercentage = totals.ftAttempted! > 0 
      ? (totals.ftMade! / totals.ftAttempted!) * 100 
      : 0;
    totals.totalRebounds = (totals.offRebounds || 0) + (totals.defRebounds || 0);

    return totals;
  }

  /**
   * Create empty team totals
   */
  private emptyTeamTotals(): TeamTotals {
    return {
      minutes: 0,
      points: 0,
      fgMade: 0,
      fgAttempted: 0,
      threeMade: 0,
      threeAttempted: 0,
      ftMade: 0,
      ftAttempted: 0,
      offRebounds: 0,
      defRebounds: 0,
      assists: 0,
      steals: 0,
      blocks: 0,
      turnovers: 0,
      fouls: 0,
      fgPercentage: 0,
      threePercentage: 0,
      ftPercentage: 0,
      totalRebounds: 0,
    };
  }

// ===== GOLF SPECIFIC METHODS =====

  /**
   * Fetch golf scoreboard (tournaments for a week)
   * Uses calendar data to show tournaments from any week, not just the current one
   */
  async fetchGolfScoreboard(league: string, weekStart: string): Promise<GolfScoreboardResponse> {
    const config = this.getSportConfig(league);

    // Calculate week boundaries (Monday to Sunday)
    const weekStartDate = new Date(weekStart);
    weekStartDate.setUTCHours(0, 0, 0, 0);
    const weekEndDate = new Date(weekStartDate);
    weekEndDate.setDate(weekEndDate.getDate() + 6);
    weekEndDate.setUTCHours(23, 59, 59, 999);

    try {
      const response = await this.rateLimitedRequest('scoreboard', async () => {
        // Fetch with calendar=true to get the full season schedule
        const url = `https://site.api.espn.com/apis/site/v2/sports/${config.sportPath}/scoreboard?calendar=true`;

        logger.debug('ESPNAdapter: Fetching golf scoreboard with calendar', { url, league, weekStart });
        const res = await this.client.get(url);

        return res.data;
      });

      // Get active tournaments with full leaderboard data
      const activeTournaments = this.transformGolfScoreboard(response, config.leaguePrefix as 'pga' | 'lpga' | 'korn_ferry');
      const activeIds = new Set(activeTournaments.map(t => t.id.split('_')[1]));

      // Get calendar tournaments (all scheduled tournaments for the season)
      const calendarTournaments = this.transformGolfCalendar(response, config.leaguePrefix as 'pga' | 'lpga' | 'korn_ferry');

      // Filter calendar tournaments to only those that overlap with the requested week
      const weekTournaments = calendarTournaments.filter((tournament) => {
        const tournamentStart = new Date(tournament.startDate);
        const tournamentEnd = new Date(tournament.endDate);

        // Tournament overlaps with week if:
        // - Tournament starts before week ends AND tournament ends after week starts
        return tournamentStart <= weekEndDate && tournamentEnd >= weekStartDate;
      });

      // Merge: use active tournament data if available (has leaderboard), otherwise use calendar data
      const tournaments = weekTournaments.map((calTournament) => {
        const espnId = calTournament.id.split('_')[1];
        const activeTournament = activeTournaments.find(t => t.id.split('_')[1] === espnId);
        return activeTournament || calTournament;
      });

      logger.debug('ESPNAdapter: Golf tournaments for week', {
        league,
        weekStart,
        calendarCount: calendarTournaments.length,
        weekCount: weekTournaments.length,
        activeCount: activeTournaments.length,
        finalCount: tournaments.length,
      });

      return {
        league: config.leaguePrefix,
        weekStart: weekStartDate.toISOString().split('T')[0],
        weekEnd: weekEndDate.toISOString().split('T')[0],
        tournaments,
        lastUpdated: new Date().toISOString(),
      };
    } catch (error) {
      // Handle ESPN API errors gracefully (e.g., Korn Ferry may be off-season)
      const errMsg = error instanceof Error ? error.message : String(error);

      // If ESPN returns 400 (no events), return empty tournaments instead of failing
      if (errMsg.includes('400') || errMsg.includes('Failed to get events')) {
        logger.info('ESPNAdapter: No golf tournaments available', { league, weekStart });
        return {
          league: config.leaguePrefix,
          weekStart: weekStartDate.toISOString().split('T')[0],
          weekEnd: weekEndDate.toISOString().split('T')[0],
          tournaments: [],
          lastUpdated: new Date().toISOString(),
        };
      }

      if (error instanceof ProviderError) throw error;
      logger.error('ESPNAdapter: Failed to fetch golf scoreboard', { league, error: errMsg });
      throw new ProviderError(`Failed to fetch golf scoreboard: ${errMsg}`);
    }
  }

  /**
   * Transform ESPN calendar data to tournament list (basic info, no leaderboard)
   */
  private transformGolfCalendar(data: any, tour: 'pga' | 'lpga' | 'korn_ferry'): GolfTournament[] {
    const calendar = data.leagues?.[0]?.calendar || [];

    return calendar.map((event: any) => {
      const startDate = event.startDate ? event.startDate.split('T')[0] : '';
      const endDate = event.endDate ? event.endDate.split('T')[0] : '';

      // Determine status based on dates
      const now = new Date();
      const start = new Date(startDate);
      const end = new Date(endDate);
      let roundStatus = 'Scheduled';
      if (now > end) {
        roundStatus = 'Complete';
      } else if (now >= start && now <= end) {
        roundStatus = 'In Progress';
      }

      // Extract winner information
      let winner: GolfWinner | undefined;

      // For completed tournaments, get the winner
      if (event.winner) {
        winner = {
          name: event.winner.displayName || event.winner.athlete?.displayName || event.winner.name || 'Unknown',
          score: event.winner.score || undefined,
          isDefendingChamp: false,
        };
      }

      // For scheduled tournaments, get the defending champion
      if (roundStatus === 'Scheduled' && event.defendingChampion) {
        winner = {
          name: event.defendingChampion.displayName || event.defendingChampion.athlete?.displayName || event.defendingChampion.name || 'Unknown',
          score: undefined,
          isDefendingChamp: true,
        };
      }

      // Log for debugging
      if (winner) {
        logger.debug('ESPNAdapter: Tournament winner extracted', {
          tournament: event.label,
          winner: winner.name,
          isDefendingChamp: winner.isDefendingChamp,
        });
      }

      return {
        id: `${tour}_${event.id}`,
        name: event.label || 'Unknown Tournament',
        tour,
        venue: '',
        location: '',
        startDate,
        endDate,
        currentRound: 1,
        roundStatus,
        purse: undefined,
        winner,
        leaderboard: [],
      };
    });
  }

  /**
   * Fetch full tournament leaderboard
   */
  async fetchGolfLeaderboard(tournamentId: string): Promise<GolfTournament | null> {
    const { league, espnId } = this.parseGameId(tournamentId);
    const config = this.getSportConfig(league);

    try {
      const response = await this.rateLimitedRequest('gameSummary', async () => {
        const url = `https://site.web.api.espn.com/apis/site/v2/sports/${config.sportPath}/leaderboard?event=${espnId}`;

        logger.debug('ESPNAdapter: Fetching golf leaderboard', { url, tournamentId });
        const res = await this.client.get(url);

        return res.data;
      });

      return this.transformGolfLeaderboard(response, config.leaguePrefix as 'pga' | 'lpga' | 'korn_ferry');
    } catch (error) {
      if (error instanceof ProviderError) throw error;
      const errMsg = error instanceof Error ? error.message : String(error);
      logger.error('ESPNAdapter: Failed to fetch golf leaderboard', { tournamentId, error: errMsg });
      throw new ProviderError(`Failed to fetch golf leaderboard from ESPN: ${errMsg}`);
    }
  }

  /**
   * Transform ESPN golf scoreboard response to tournaments
   */
  private transformGolfScoreboard(data: any, tour: 'pga' | 'lpga' | 'korn_ferry'): GolfTournament[] {
    const events = data.events || [];

    return events.map((event: any) => {
      const competition = event.competitions?.[0];
      const venue = competition?.venue || {};

      // Get leaderboard from competition
      const competitors = competition?.competitors || [];
      const leaderboard = this.transformGolfCompetitors(competitors);

      // Determine current round and status
      const status = event.status || {};
      const currentRound = status.period || 1;
      const roundStatus = this.mapGolfRoundStatus(status.type?.name || 'scheduled');

      // Extract winner - for completed tournaments, the leader is the winner
      let winner: GolfWinner | undefined;
      if (roundStatus === 'Complete' && leaderboard.length > 0) {
        const leader = leaderboard[0];
        if (leader.stats?.position === 1 || leaderboard[0]) {
          winner = {
            name: leader.name,
            score: leader.stats?.score,
            isDefendingChamp: false,
          };
        }
      }

      return {
        id: `${tour}_${event.id}`,
        name: event.name || event.shortName || 'Unknown Tournament',
        tour,
        venue: venue.fullName || 'TBD',
        location: venue.address?.city ? `${venue.address.city}, ${venue.address.state || ''}`.trim() : '',
        startDate: event.date ? event.date.split('T')[0] : '',
        endDate: event.endDate ? event.endDate.split('T')[0] : '',
        currentRound,
        roundStatus,
        purse: event.purse || undefined,
        winner,
        leaderboard,
      };
    });
  }

  /**
   * Transform full ESPN leaderboard response to GolfTournament
   */
  private transformGolfLeaderboard(data: any, tour: 'pga' | 'lpga' | 'korn_ferry'): GolfTournament | null {
    const event = data.events?.[0] || data;
    if (!event) return null;

    const competition = event.competitions?.[0] || {};
    const venue = competition.venue || {};
    const status = event.status || {};

    // Get full leaderboard
    const competitors = data.competitors || competition.competitors || [];
    const leaderboard = this.transformGolfCompetitors(competitors);

    return {
      id: `${tour}_${event.id}`,
      name: event.name || event.shortName || 'Unknown Tournament',
      tour,
      venue: venue.fullName || 'TBD',
      location: venue.address?.city ? `${venue.address.city}, ${venue.address.state || ''}`.trim() : '',
      startDate: event.date ? event.date.split('T')[0] : '',
      endDate: event.endDate ? event.endDate.split('T')[0] : '',
      currentRound: status.period || 1,
      roundStatus: this.mapGolfRoundStatus(status.type?.name || 'scheduled'),
      purse: event.purse || undefined,
      leaderboard,
    };
  }

  /**
   * Transform ESPN golf competitors to GolferLine array
   */
  private transformGolfCompetitors(competitors: any[]): GolferLine[] {
    return competitors.map((comp: any) => {
      const athlete = comp.athlete || {};
      const stats = comp.statistics || [];
      const linescores = comp.linescores || [];

      // Parse score from statistics
      const scoreStr = comp.score?.displayValue || comp.score || 'E';
      const position = comp.status?.position?.id || comp.sortOrder || 0;
      const thru = comp.status?.thru?.displayValue || comp.status?.thru || 'F';
      const today = comp.status?.today?.displayValue || 'E';

      // Get round scores from linescores
      const rounds = linescores.map((ls: any) => ls.displayValue || ls.value?.toString() || '-');

      // Parse numeric score for sorting
      let toParTotal = 0;
      if (scoreStr === 'E') {
        toParTotal = 0;
      } else if (scoreStr.startsWith('+')) {
        toParTotal = parseInt(scoreStr.substring(1), 10) || 0;
      } else if (scoreStr.startsWith('-')) {
        toParTotal = parseInt(scoreStr, 10) || 0;
      }

      const golferStats: GolferStats = {
        position: parseInt(position.toString(), 10) || 0,
        score: scoreStr,
        toParTotal,
        rounds,
        thru: thru.toString(),
        today,
      };

      return {
        id: `golfer_${athlete.id || comp.id}`,
        name: athlete.displayName || athlete.shortName || 'Unknown',
        country: athlete.flag?.alt || athlete.birthPlace?.country || undefined,
        imageURL: athlete.headshot?.href || undefined,
        stats: golferStats,
      };
    }).sort((a: GolferLine, b: GolferLine) => {
      // Sort by position (ascending)
      const posA = a.stats?.position ?? 999;
      const posB = b.stats?.position ?? 999;
      return posA - posB;
    });
  }

  /**
   * Map ESPN golf status to round status string
   */
  private mapGolfRoundStatus(statusName: string): string {
    const status = statusName.toUpperCase();

    if (status.includes('PROGRESS')) return 'In Progress';
    if (status.includes('FINAL') || status.includes('COMPLETE')) return 'Complete';
    if (status.includes('SCHEDULED') || status.includes('PRE')) return 'Scheduled';
    if (status.includes('DELAYED')) return 'Delayed';
    if (status.includes('SUSPENDED')) return 'Suspended';

    return 'Scheduled';
  }

  /**
   * Map ESPN status to canonical status
   */
  private mapGameStatus(statusName: string): 'scheduled' | 'live' | 'final' {
    const normalizedStatus = statusName.toUpperCase();
    
    if (normalizedStatus.includes('SCHEDULED') || normalizedStatus.includes('PRE')) {
      return 'scheduled';
    }
    if (normalizedStatus.includes('FINAL') || normalizedStatus.includes('END') || normalizedStatus.includes('POST')) {
      return 'final';
    }
    if (normalizedStatus.includes('PROGRESS') || normalizedStatus.includes('HALFTIME') || normalizedStatus.includes('IN_')) {
      return 'live';
    }
    
    // Default based on common ESPN status names
    switch (normalizedStatus) {
      case 'STATUS_SCHEDULED':
        return 'scheduled';
      case 'STATUS_IN_PROGRESS':
        return 'live';
      case 'STATUS_FINAL':
      case 'STATUS_FINAL_OT':
        return 'final';
      default:
        return 'scheduled';
    }
  }
}

// Singleton instance
let espnAdapterInstance: ESPNAdapter | null = null;

export function getESPNAdapter(): ESPNAdapter {
  if (!espnAdapterInstance) {
    espnAdapterInstance = new ESPNAdapter();
  }
  return espnAdapterInstance;
}

export function resetESPNAdapter(): void {
  espnAdapterInstance = null;
}
