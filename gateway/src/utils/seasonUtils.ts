/**
 * Season-related utilities shared across the gateway.
 */

/**
 * Get current NBA season based on current date.
 * October-December = current year's season; January-September = previous year's.
 */
export function getCurrentSeason(): number {
  const now = new Date();
  return now.getMonth() >= 9 ? now.getFullYear() : now.getFullYear() - 1;
}

/**
 * Convert a season start year to a display label.
 * e.g., 2025 -> "2025-26"
 */
export function seasonLabel(season: number): string {
  const nextYear = (season + 1) % 100;
  return `${season}-${nextYear.toString().padStart(2, '0')}`;
}
