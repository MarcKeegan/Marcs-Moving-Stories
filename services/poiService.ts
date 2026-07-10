/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import { auth } from '../firebase';
import { TravelMode } from '../types';

/**
 * Fetches real points of interest along the route via the server's
 * /api/nearby-pois proxy (Google Places Nearby Search) and assigns them to
 * story segments, so the narration can reference actual landmarks the
 * traveler is passing.
 *
 * Everything here is best-effort: any failure (endpoint absent in local dev,
 * network error, empty results) yields an empty assignment and the story
 * generates exactly as before.
 */

export interface RoutePoi {
  name: string;
  types: string[];
  userRatingsTotal: number | null;
}

/** POIs assigned per 1-based segment index. */
export type SegmentPois = Map<number, string[]>;

// Cap on Places requests per journey, independent of journey length.
const MAX_SAMPLE_POINTS = 8;
const POIS_PER_SEGMENT = 2;

// Landmark-ish place types get priority over generic businesses.
const NOTABLE_TYPES = new Set([
  'tourist_attraction', 'museum', 'park', 'church', 'place_of_worship',
  'landmark', 'stadium', 'university', 'library', 'art_gallery',
  'city_hall', 'castle', 'cemetery', 'zoo', 'aquarium', 'amusement_park',
  'natural_feature', 'town_square', 'historical_landmark',
]);

// Types that make for poor storytelling scenery.
const BORING_TYPES = new Set([
  'lodging', 'gas_station', 'parking', 'atm', 'car_repair', 'car_wash',
  'car_dealer', 'storage', 'real_estate_agency', 'insurance_agency',
  'lawyer', 'dentist', 'doctor', 'bank', 'finance', 'moving_company',
]);

/** Pick `samples` roughly evenly spaced indices along a path of `pathLength` points. */
export const samplePathIndices = (pathLength: number, samples: number): number[] => {
  if (pathLength <= 0 || samples <= 0) return [];
  const count = Math.min(samples, pathLength);
  if (count === 1) return [Math.floor(pathLength / 2)];
  const indices: number[] = [];
  for (let i = 0; i < count; i++) {
    indices.push(Math.round((i / (count - 1)) * (pathLength - 1)));
  }
  return indices;
};

/** Map a 1-based segment index to its nearest sample slot. */
export const sampleIndexForSegment = (segmentIndex: number, totalSegments: number, samples: number): number => {
  if (samples <= 0) return 0;
  const ratio = (segmentIndex - 1) / Math.max(1, totalSegments);
  return Math.min(samples - 1, Math.floor(ratio * samples));
};

const poiScore = (poi: RoutePoi): number => {
  if (poi.types.some((t) => BORING_TYPES.has(t))) return -1;
  const notable = poi.types.some((t) => NOTABLE_TYPES.has(t)) ? 100000 : 0;
  return notable + (poi.userRatingsTotal ?? 0);
};

/**
 * Distribute sampled POIs across segments: each segment draws up to
 * POIS_PER_SEGMENT names from its nearest sample point, best-scored first,
 * and no landmark is mentioned in more than one segment.
 */
export const assignPoisToSegments = (
  poisPerSample: RoutePoi[][],
  totalSegments: number,
  perSegment: number = POIS_PER_SEGMENT
): SegmentPois => {
  const assignment: SegmentPois = new Map();
  if (poisPerSample.length === 0) return assignment;

  const ranked = poisPerSample.map((pois) =>
    [...pois].filter((p) => poiScore(p) >= 0).sort((a, b) => poiScore(b) - poiScore(a))
  );

  const used = new Set<string>();
  for (let seg = 1; seg <= totalSegments; seg++) {
    const slot = sampleIndexForSegment(seg, totalSegments, ranked.length);
    const names: string[] = [];
    for (const poi of ranked[slot] ?? []) {
      if (names.length >= perSegment) break;
      if (used.has(poi.name)) continue;
      used.add(poi.name);
      names.push(poi.name);
    }
    if (names.length > 0) assignment.set(seg, names);
  }
  return assignment;
};

interface NearbyPoisResponse {
  places?: Array<{
    name?: string;
    types?: string[];
    userRatingsTotal?: number | null;
  }>;
}

const fetchNearby = async (lat: number, lng: number, radius: number, token: string | undefined): Promise<RoutePoi[]> => {
  const params = new URLSearchParams({ location: `${lat},${lng}`, radius: String(radius) });
  const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};
  const res = await fetch(`/api/nearby-pois?${params.toString()}`, { headers });
  if (!res.ok) return [];
  const data = (await res.json()) as NearbyPoisResponse;
  return (data.places ?? [])
    .filter((p): p is { name: string; types?: string[]; userRatingsTotal?: number | null } => Boolean(p.name))
    .map((p) => ({
      name: p.name,
      types: p.types ?? [],
      userRatingsTotal: typeof p.userRatingsTotal === 'number' ? p.userRatingsTotal : null,
    }));
};

/**
 * Fetch and assign POIs for a journey. Never rejects — on any failure the
 * result is simply empty.
 */
export const fetchRoutePois = async (
  path: google.maps.LatLng[],
  travelMode: TravelMode,
  totalSegments: number
): Promise<SegmentPois> => {
  try {
    if (!path || path.length === 0) return new Map();

    const token = await auth.currentUser?.getIdToken();
    const sampleCount = Math.min(MAX_SAMPLE_POINTS, Math.max(1, totalSegments));
    const indices = samplePathIndices(path.length, sampleCount);
    // Walkers notice what's on the block; drivers pass a wider corridor.
    const radius = travelMode === 'WALKING' ? 400 : 1200;

    const poisPerSample = await Promise.all(
      indices.map((i) =>
        fetchNearby(path[i].lat(), path[i].lng(), radius, token).catch(() => [] as RoutePoi[])
      )
    );

    return assignPoisToSegments(poisPerSample, totalSegments);
  } catch (e) {
    console.warn('POI lookup failed; continuing without landmarks.', e);
    return new Map();
  }
};
