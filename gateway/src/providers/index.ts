/**
 * Provider module - ESPN-only data provider
 *
 * All sports data is fetched from ESPN's unofficial API.
 * This module provides a clean interface for future provider switching if needed.
 */

import { SportsDataProvider } from '../types';
import { ESPNAdapter, getESPNAdapter } from './espnAdapter';

// ESPN adapter instance (lazy loaded)
let espnInstance: ESPNAdapter | null = null;

/**
 * Get the ESPN adapter instance
 *
 * ESPN unofficial API is used for all sports data:
 * - Free, no API key required
 * - Supports NBA, NFL, NCAAF, NCAAM, NHL
 * - Rate limited via ESPNRateLimiter (60/min, 2000/day)
 */
export function getESPNAdapterInstance(): ESPNAdapter {
  if (!espnInstance) {
    espnInstance = getESPNAdapter();
  }
  return espnInstance;
}

/**
 * Get the active provider adapter
 * Currently always returns ESPN adapter
 */
export function getProviderAdapter(): SportsDataProvider {
  return getESPNAdapterInstance();
}

/**
 * Get adapter for a specific league
 * Currently all leagues use ESPN
 */
export function getAdapterForLeague(league: string): SportsDataProvider {
  return getESPNAdapterInstance();
}

/**
 * Get adapter for a specific game ID
 * Currently all games use ESPN
 */
export function getAdapterForGame(gameId: string): SportsDataProvider {
  return getESPNAdapterInstance();
}

/**
 * Check if a game ID is for an NBA game
 */
export function isNBAGame(gameId: string): boolean {
  return gameId.startsWith('nba_');
}

/**
 * Check if a game ID is for an NFL game
 */
export function isNFLGame(gameId: string): boolean {
  return gameId.startsWith('nfl_');
}

/**
 * Check if a game ID is for an NCAAF game
 */
export function isNCAAFGame(gameId: string): boolean {
  return gameId.startsWith('ncaaf_');
}

/**
 * Check if a game ID is for an NCAAM game
 */
export function isNCAAMGame(gameId: string): boolean {
  return gameId.startsWith('ncaam_');
}

/**
 * Check if a game ID is for an NHL game
 */
export function isNHLGame(gameId: string): boolean {
  return gameId.startsWith('nhl_');
}

/**
 * Check if a game/tournament ID is for a golf event
 */
export function isGolfGame(gameId: string): boolean {
  return gameId.startsWith('pga_') || gameId.startsWith('lpga_') || gameId.startsWith('korn_ferry_');
}

/**
 * Check if a game uses ESPN adapter (all games do now)
 */
export function isESPNGame(gameId: string): boolean {
  return true; // All games use ESPN
}

/**
 * Leagues supported by ESPN
 */
export const ESPN_LEAGUES = ['nba', 'nfl', 'ncaaf', 'ncaam', 'nhl', 'pga', 'lpga', 'korn_ferry'];

/**
 * Reset provider instance (useful for testing)
 */
export function resetProvider(): void {
  espnInstance = null;
}

/**
 * Get provider name
 */
export function getProviderName(): string {
  return 'espn';
}
