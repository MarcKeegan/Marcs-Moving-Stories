import { describe, expect, it, vi } from 'vitest';

// poiService imports Firebase auth for tokens; stub it for pure-logic tests.
vi.mock('../firebase', () => ({ auth: { currentUser: null } }));

import {
  assignPoisToSegments,
  samplePathIndices,
  sampleIndexForSegment,
  type RoutePoi,
} from '../services/poiService';

const poi = (name: string, types: string[] = [], ratings: number | null = null): RoutePoi => ({
  name,
  types,
  userRatingsTotal: ratings,
});

describe('samplePathIndices', () => {
  it('spaces samples evenly including both endpoints', () => {
    expect(samplePathIndices(101, 5)).toEqual([0, 25, 50, 75, 100]);
  });

  it('handles a single sample and short paths', () => {
    expect(samplePathIndices(10, 1)).toEqual([5]);
    expect(samplePathIndices(2, 8)).toEqual([0, 1]);
    expect(samplePathIndices(0, 4)).toEqual([]);
  });
});

describe('sampleIndexForSegment', () => {
  it('maps segments proportionally onto sample slots', () => {
    // 10 segments over 5 samples: segments 1-2 -> slot 0, 3-4 -> slot 1, ...
    expect(sampleIndexForSegment(1, 10, 5)).toBe(0);
    expect(sampleIndexForSegment(2, 10, 5)).toBe(0);
    expect(sampleIndexForSegment(3, 10, 5)).toBe(1);
    expect(sampleIndexForSegment(10, 10, 5)).toBe(4);
  });

  it('never exceeds the last slot', () => {
    expect(sampleIndexForSegment(60, 60, 8)).toBe(7);
    expect(sampleIndexForSegment(1, 1, 3)).toBe(0);
  });
});

describe('assignPoisToSegments', () => {
  it('never assigns the same landmark to two segments', () => {
    const shared = [poi('Old Mill', ['tourist_attraction']), poi('Corner Cafe')];
    const assignment = assignPoisToSegments([shared, shared], 4, 2);

    const allNames = [...assignment.values()].flat();
    expect(new Set(allNames).size).toBe(allNames.length);
  });

  it('caps landmarks per segment and prefers notable, popular places', () => {
    const sample = [
      poi('Chain Hotel', ['lodging'], 5000),        // boring type: excluded
      poi('City Museum', ['museum'], 10),           // notable: first
      poi('Popular Bakery', [], 900),
      poi('Quiet Shop', [], 3),
    ];
    const assignment = assignPoisToSegments([sample], 1, 2);

    expect(assignment.get(1)).toEqual(['City Museum', 'Popular Bakery']);
  });

  it('returns an empty map when there is nothing to assign', () => {
    expect(assignPoisToSegments([], 5).size).toBe(0);
    expect(assignPoisToSegments([[]], 5).size).toBe(0);
  });
});
