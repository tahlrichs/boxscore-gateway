import { Router, Request, Response } from 'express';
import { leagueConfig } from '../config';
import { League } from '../types';

export const leaguesRouter = Router();

// Supported leagues
const supportedLeagues: League[] = [
  { id: 'nba', name: 'NBA', sportType: 'basketball' },
  { id: 'nfl', name: 'NFL', sportType: 'football' },
  { id: 'ncaaf', name: 'NCAAF', sportType: 'football' },
  { id: 'ncaam', name: 'NCAAM', sportType: 'basketball' },
  { id: 'nhl', name: 'NHL', sportType: 'hockey' },
  { id: 'mlb', name: 'MLB', sportType: 'baseball' },
  { id: 'pga', name: 'PGA Tour', sportType: 'golf' },
  { id: 'korn_ferry', name: 'Korn Ferry Tour', sportType: 'golf' },
];

leaguesRouter.get('/', (_req: Request, res: Response) => {
  res.json({
    data: supportedLeagues,
    lastUpdated: new Date().toISOString(),
  });
});

leaguesRouter.get('/:id', (req: Request, res: Response) => {
  const id = req.params.id as string;
  const league = supportedLeagues.find(l => l.id === id.toLowerCase());
  
  if (!league) {
    res.status(404).json({
      error: 'NOT_FOUND',
      message: `League '${id}' not found`,
    });
    return;
  }
  
  // Add provider-specific IDs for debugging
  const leagueWithIds = {
    ...league,
    externalIds: leagueConfig[id.toLowerCase() as keyof typeof leagueConfig],
  };
  
  res.json({
    data: leagueWithIds,
    lastUpdated: new Date().toISOString(),
  });
});
