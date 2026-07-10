/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React, { useEffect, useRef } from 'react';
import { EDITORIAL_MAP_STYLE } from './mapStyles';
import { useGoogleMaps } from '../hooks/useGoogleMaps';

interface Props {
  directions: google.maps.DirectionsResult | null;
  currentSegmentIndex: number;
  totalSegments: number;
}

const InlineMap: React.FC<Props> = ({ directions, currentSegmentIndex, totalSegments }) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const googleMapRef = useRef<google.maps.Map | null>(null);
  const directionsRendererRef = useRef<google.maps.DirectionsRenderer | null>(null);
  const progressMarkerRef = useRef<google.maps.Marker | null>(null);
  const routePathRef = useRef<google.maps.LatLng[]>([]);

  const { ready: mapsReady } = useGoogleMaps();

  // 1. Init Map
  useEffect(() => {
    if (!mapsReady || !mapRef.current || googleMapRef.current) return;

    googleMapRef.current = new google.maps.Map(mapRef.current, {
      zoom: 13,
      center: { lat: 0, lng: 0 },
      disableDefaultUI: true,
      zoomControl: true,
      styles: EDITORIAL_MAP_STYLE
    });

    directionsRendererRef.current = new google.maps.DirectionsRenderer({
      map: googleMapRef.current,
      suppressMarkers: false,
      polylineOptions: {
        strokeColor: '#1A1A1A',
        strokeWeight: 5,
        strokeOpacity: 0.9
      }
    });
  }, [mapsReady]);

  // 2. Render the already-calculated route (no extra Directions request)
  useEffect(() => {
    if (!mapsReady || !directions || !directionsRendererRef.current || !googleMapRef.current) return;

    directionsRendererRef.current.setDirections(directions);

    const routeData = directions.routes[0];
    if (!routeData) return;

    // Save the detailed path for placing the marker later
    routePathRef.current = routeData.overview_path;

    googleMapRef.current.fitBounds(routeData.bounds, { top: 50, right: 50, bottom: 50, left: 50 });

    if (!progressMarkerRef.current) {
      progressMarkerRef.current = new google.maps.Marker({
        map: googleMapRef.current,
        position: routePathRef.current[0], // Start at beginning
        zIndex: 999, // On top of everything
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: 8,
          fillColor: '#1A1A1A', // Editorial black
          fillOpacity: 1,
          strokeColor: '#FFFFFF',
          strokeWeight: 3,
        },
        title: 'You are here'
      });
    }
  }, [mapsReady, directions]);

  // 3. Update Marker Position based on progress
  useEffect(() => {
    if (!progressMarkerRef.current || routePathRef.current.length === 0) return;

    const path = routePathRef.current;
    // Approximate index along the path based on segment progress
    const safeIndex = Math.min(currentSegmentIndex, totalSegments);
    const progressRatio = safeIndex / Math.max(1, totalSegments);
    const pathIndex = Math.min(
      Math.floor(progressRatio * (path.length - 1)),
      path.length - 1
    );

    const newPos = path[pathIndex];
    if (newPos) {
      progressMarkerRef.current.setPosition(newPos);
    }
  }, [currentSegmentIndex, totalSegments]);

  return <div ref={mapRef} className="w-full h-full bg-stone-100" role="img" aria-label="Map of your journey route" />;
};

export default React.memo(InlineMap);
