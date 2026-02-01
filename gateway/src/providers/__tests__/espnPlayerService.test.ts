import { buildIndexMap, parseCombinedStat, parseStatValue } from '../espnPlayerService';

describe('parseStatValue', () => {
  it('parses a numeric string', () => {
    expect(parseStatValue('6.7')).toBe(6.7);
  });

  it('returns 0 for undefined', () => {
    expect(parseStatValue(undefined)).toBe(0);
  });

  it('returns 0 for empty string', () => {
    expect(parseStatValue('')).toBe(0);
  });

  it('returns 0 for non-numeric string', () => {
    expect(parseStatValue('abc')).toBe(0);
  });

  it('parses integer strings', () => {
    expect(parseStatValue('42')).toBe(42);
  });
});

describe('buildIndexMap', () => {
  it('maps labels to their indices', () => {
    const map = buildIndexMap(['GP', 'GS', 'MIN']);
    expect(map.get('GP')).toBe(0);
    expect(map.get('GS')).toBe(1);
    expect(map.get('MIN')).toBe(2);
  });

  it('returns empty map for empty labels', () => {
    const map = buildIndexMap([]);
    expect(map.size).toBe(0);
  });
});

describe('parseCombinedStat', () => {
  const labels = ['GP', 'GS', 'MIN', 'FG', 'FG%', '3PT', '3P%', 'FT', 'FT%'];
  const indexMap = buildIndexMap(labels);

  it('parses combined "made-attempted" format', () => {
    const stats = ['68', '62', '34.5', '6.7-16.1', '.416', '1.8-5.7', '.316', '2.2-2.6', '.846'];
    expect(parseCombinedStat(indexMap, stats, 'FG')).toEqual([6.7, 16.1]);
    expect(parseCombinedStat(indexMap, stats, '3PT')).toEqual([1.8, 5.7]);
    expect(parseCombinedStat(indexMap, stats, 'FT')).toEqual([2.2, 2.6]);
  });

  it('returns [0, 0] for missing label', () => {
    const stats = ['68', '62', '34.5'];
    expect(parseCombinedStat(indexMap, stats, 'NONEXISTENT')).toEqual([0, 0]);
  });

  it('returns [0, 0] when index exceeds stats length', () => {
    const stats = ['68', '62']; // only 2 stats, FG is at index 3
    expect(parseCombinedStat(indexMap, stats, 'FG')).toEqual([0, 0]);
  });

  it('returns [0, 0] for empty stat value', () => {
    const stats = ['68', '62', '34.5', '', '.416'];
    expect(parseCombinedStat(indexMap, stats, 'FG')).toEqual([0, 0]);
  });

  it('returns [value, 0] for non-combined single value', () => {
    const stats = ['68', '62', '34.5', '16.1', '.416'];
    expect(parseCombinedStat(indexMap, stats, 'FG')).toEqual([16.1, 0]);
  });

  it('handles zero values in combined format', () => {
    const stats = ['68', '62', '34.5', '0.0-0.0', '.000'];
    expect(parseCombinedStat(indexMap, stats, 'FG')).toEqual([0, 0]);
  });
});
