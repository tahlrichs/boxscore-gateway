import { Router, Request, Response, NextFunction } from 'express';
import axios from 'axios';
import { getProviderAdapter } from '../providers';
import { getCached, setCached, cacheKeys } from '../cache/redis';
import { config } from '../config';
import { RosterResponse, Team } from '../types';
import { BadRequestError, NotFoundError, ProviderError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { validateTeamId, validateLeague } from '../middleware/validation';

export const teamsRouter = Router();

// ESPN sport path mapping
function getESPNSportPath(league: string): string {
  switch (league.toLowerCase()) {
    case 'nba': return 'basketball/nba';
    case 'nfl': return 'football/nfl';
    case 'ncaaf': return 'football/college-football';
    case 'ncaam': return 'basketball/mens-college-basketball';
    case 'nhl': return 'hockey/nhl';
    case 'mlb': return 'baseball/mlb';
    default: throw new BadRequestError(`Unsupported league: ${league}`);
  }
}

// Transform ESPN team to our Team type
interface ESPNTeamResponse {
  team: {
    id: string;
    abbreviation: string;
    displayName: string;
    shortDisplayName: string;
    location: string;
    color?: string;
    logos?: Array<{ href: string }>;
    standingSummary?: string;
    groups?: {
      id: string;
      parent?: {
        id: string;
        name?: string;
      };
      name?: string;
    };
  };
}

function transformESPNTeam(espnTeam: ESPNTeamResponse, leaguePrefix: string): Team {
  const team = espnTeam.team;

  // Extract conference/division from groups
  // For college: groups.parent?.name is the conference (e.g., "SEC", "Big Ten")
  // For pro: groups.parent?.name might be conference, groups.name is division
  let conference: string | undefined;
  let division: string | undefined;

  if (team.groups) {
    if (team.groups.parent?.name) {
      conference = team.groups.parent.name;
      division = team.groups.name;
    } else if (team.groups.name) {
      conference = team.groups.name;
    }
  }

  return {
    id: `${leaguePrefix}_${team.id}`,
    abbrev: team.abbreviation,
    name: team.shortDisplayName || team.displayName,
    city: team.location,
    logoURL: team.logos?.[0]?.href,
    primaryColor: team.color ? `#${team.color}` : undefined,
    conference,
    division,
  };
}

/**
 * GET /v1/teams?league=nba
 *
 * Returns list of all teams for the specified league
 */
teamsRouter.get('/', validateLeague, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const league = (req.query.league as string).toLowerCase();

    // Cache key for teams list (7 days TTL - teams rarely change)
    const cacheKey = `teams:list:${league}:v1`;

    // Try cache first
    const cached = await getCached<Team[]>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for teams list: ${league}`);
      res.cacheHit = true;
      res.json({
        data: {
          league,
          teams: cached,
          lastUpdated: new Date().toISOString(),
        },
        meta: {
          requestId: req.requestId,
          cacheHit: true,
        },
      });
      return;
    }

    // Fetch from ESPN
    const sportPath = getESPNSportPath(league);
    const url = `https://site.api.espn.com/apis/site/v2/sports/${sportPath}/teams`;

    logger.debug(`Fetching teams list from ESPN`, { url, league });

    const response = await axios.get(url, {
      timeout: 15000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'BoxScore/1.0',
      },
    });

    const espnTeams = response.data.sports?.[0]?.leagues?.[0]?.teams || [];
    const teams: Team[] = espnTeams.map((t: ESPNTeamResponse) => transformESPNTeam(t, league));

    // Sort alphabetically by city
    teams.sort((a, b) => a.city.localeCompare(b.city));

    // Cache for 7 days
    await setCached(cacheKey, teams, 7 * 24 * 60 * 60);

    res.cacheHit = false;
    res.json({
      data: {
        league,
        teams,
        lastUpdated: new Date().toISOString(),
      },
      meta: {
        requestId: req.requestId,
        cacheHit: false,
        totalTeams: teams.length,
      },
    });
  } catch (error) {
    if (error instanceof BadRequestError) {
      next(error);
      return;
    }
    const errMsg = error instanceof Error ? error.message : String(error);
    logger.error('Failed to fetch teams list', { error: errMsg });
    next(new ProviderError(`Failed to fetch teams: ${errMsg}`));
  }
});

// Get team roster
teamsRouter.get('/:id/roster', validateTeamId, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = req.params.id as string;
    
    const cacheKey = cacheKeys.roster(id);
    
    // Try cache first
    const cached = await getCached<RosterResponse>(cacheKey);
    if (cached) {
      logger.debug(`Cache hit for roster: ${id}`);
      res.cacheHit = true;
      res.json({
        data: cached,
        meta: {
          requestId: req.requestId,
          provider: config.provider,
          cacheHit: true,
        },
      });
      return;
    }
    
    // Fetch from provider
    logger.debug(`Cache miss for roster: ${id}`);
    const provider = getProviderAdapter();
    const roster = await provider.fetchRoster(id);
    
    if (!roster) {
      throw new NotFoundError(`Roster for team '${id}' not found`);
    }
    
    // Cache the response
    await setCached(cacheKey, roster, config.cacheTtl.roster);
    
    res.cacheHit = false;
    res.json({
      data: roster,
      meta: {
        requestId: req.requestId,
        provider: config.provider,
        cacheHit: false,
      },
    });
  } catch (error) {
    next(error);
  }
});
