/**
 * ID Mapping Utilities
 * 
 * Handles mapping between internal canonical IDs and provider-specific IDs.
 * Critical for provider migration.
 */

import { logger } from '../utils/logger';

// Entity types
export type EntityType = 'team' | 'player' | 'game' | 'league' | 'venue';
export type Provider = 'espn' | 'sportradar' | 'sportsdataio';

// ID mapping entry
export interface IdMapping {
  entityType: EntityType;
  internalId: string;
  provider: Provider;
  providerId: string;
  metadata?: Record<string, unknown>;
}

// In-memory cache for ID mappings (for development/testing)
// In production, use PostgreSQL via the schema above
class IdMapperStore {
  private mappings: Map<string, IdMapping> = new Map();

  private getKey(entityType: EntityType, internalId: string, provider: Provider): string {
    return `${entityType}:${internalId}:${provider}`;
  }

  private getReverseKey(entityType: EntityType, provider: Provider, providerId: string): string {
    return `reverse:${entityType}:${provider}:${providerId}`;
  }

  set(mapping: IdMapping): void {
    const key = this.getKey(mapping.entityType, mapping.internalId, mapping.provider);
    const reverseKey = this.getReverseKey(mapping.entityType, mapping.provider, mapping.providerId);
    
    this.mappings.set(key, mapping);
    this.mappings.set(reverseKey, mapping);
  }

  getByInternalId(entityType: EntityType, internalId: string, provider: Provider): IdMapping | undefined {
    const key = this.getKey(entityType, internalId, provider);
    return this.mappings.get(key);
  }

  getByProviderId(entityType: EntityType, provider: Provider, providerId: string): IdMapping | undefined {
    const reverseKey = this.getReverseKey(entityType, provider, providerId);
    return this.mappings.get(reverseKey);
  }

  getAllForEntity(entityType: EntityType, internalId: string): IdMapping[] {
    const results: IdMapping[] = [];
    const providers: Provider[] = ['espn', 'sportradar', 'sportsdataio'];

    for (const provider of providers) {
      const mapping = this.getByInternalId(entityType, internalId, provider);
      if (mapping) {
        results.push(mapping);
      }
    }

    return results;
  }
}

// Global store instance
const store = new IdMapperStore();

/**
 * ID Mapper - handles translation between canonical and provider IDs
 */
export const idMapper = {
  /**
   * Register a mapping between internal ID and provider ID
   */
  register(mapping: IdMapping): void {
    store.set(mapping);
    logger.debug('Registered ID mapping:', {
      entityType: mapping.entityType,
      internalId: mapping.internalId,
      provider: mapping.provider,
      providerId: mapping.providerId,
    });
  },

  /**
   * Get provider ID from internal ID
   */
  toProviderId(entityType: EntityType, internalId: string, provider: Provider): string | null {
    const mapping = store.getByInternalId(entityType, internalId, provider);
    return mapping?.providerId ?? null;
  },

  /**
   * Get internal ID from provider ID
   */
  toInternalId(entityType: EntityType, provider: Provider, providerId: string): string | null {
    const mapping = store.getByProviderId(entityType, provider, providerId);
    return mapping?.internalId ?? null;
  },

  /**
   * Get all provider IDs for an internal ID
   */
  getAllProviderIds(entityType: EntityType, internalId: string): Record<Provider, string> {
    const mappings = store.getAllForEntity(entityType, internalId);
    const result: Partial<Record<Provider, string>> = {};
    
    for (const mapping of mappings) {
      result[mapping.provider] = mapping.providerId;
    }
    
    return result as Record<Provider, string>;
  },

  /**
   * Check if a mapping exists
   */
  hasMapping(entityType: EntityType, internalId: string, provider: Provider): boolean {
    return store.getByInternalId(entityType, internalId, provider) !== undefined;
  },

  /**
   * Generate a canonical internal ID for a new entity
   */
  generateInternalId(entityType: EntityType, league: string, identifier: string): string {
    switch (entityType) {
      case 'team':
        return `${league}_${identifier}`;
      case 'player':
        return `player_${identifier}`;
      case 'game':
        return `${league}_${identifier}`;
      case 'league':
        return league;
      case 'venue':
        return `venue_${identifier}`;
      default:
        return `${entityType}_${identifier}`;
    }
  },

  /**
   * Bulk register mappings (for initial setup or migration)
   */
  bulkRegister(mappings: IdMapping[]): void {
    for (const mapping of mappings) {
      store.set(mapping);
    }
    logger.info(`Registered ${mappings.length} ID mappings`);
  },
};

/**
 * Initialize default mappings for known entities
 * Call this during startup if needed
 */
export function initializeDefaultMappings(): void {
  // ESPN mappings are created dynamically when games are fetched
  logger.info('ID mapper initialized');
}

/**
 * Reconciliation utilities for provider migration
 */
export const reconciliation = {
  /**
   * Find potential matches by name (fuzzy matching)
   */
  findMatchesByName(name: string, candidates: Array<{ id: string; name: string }>): Array<{
    id: string;
    name: string;
    score: number;
  }> {
    const normalizedName = name.toLowerCase().trim();
    
    return candidates
      .map(candidate => ({
        ...candidate,
        score: this.calculateSimilarity(normalizedName, candidate.name.toLowerCase().trim()),
      }))
      .filter(match => match.score > 0.7)
      .sort((a, b) => b.score - a.score);
  },

  /**
   * Simple string similarity (Jaccard index)
   */
  calculateSimilarity(str1: string, str2: string): number {
    const set1 = new Set(str1.split(/\s+/));
    const set2 = new Set(str2.split(/\s+/));
    
    const intersection = new Set([...set1].filter(x => set2.has(x)));
    const union = new Set([...set1, ...set2]);
    
    return intersection.size / union.size;
  },

  /**
   * Validate mapping consistency across providers
   */
  validateMappings(entityType: EntityType, internalId: string): {
    valid: boolean;
    issues: string[];
  } {
    const mappings = store.getAllForEntity(entityType, internalId);
    const issues: string[] = [];

    if (mappings.length === 0) {
      issues.push(`No mappings found for ${entityType}:${internalId}`);
    }

    // Add more validation rules as needed
    // e.g., check that all expected providers have mappings

    return {
      valid: issues.length === 0,
      issues,
    };
  },
};
