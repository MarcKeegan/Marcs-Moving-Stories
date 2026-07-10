/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React, { useEffect, useRef } from 'react';
import { EDITORIAL_MAP_STYLE } from './mapStyles';
import { useGoogleMaps } from '../hooks/useGoogleMaps';

interface Props {
  directions: google.maps.DirectionsResult | null;
}

const MapBackground: React.FC<Props> = ({ directions }) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const googleMapRef = useRef<google.maps.Map | null>(null);
  const directionsRendererRef = useRef<google.maps.DirectionsRenderer | null>(null);

  const { ready: mapsReady } = useGoogleMaps();

  useEffect(() => {
    if (!mapsReady || !mapRef.current || googleMapRef.current) return;

    googleMapRef.current = new google.maps.Map(mapRef.current, {
      zoom: 13,
      center: { lat: 34.0522, lng: -118.2437 }, // Default LA
      disableDefaultUI: true,
      styles: EDITORIAL_MAP_STYLE
    });

    directionsRendererRef.current = new google.maps.DirectionsRenderer({
      map: googleMapRef.current,
      suppressMarkers: true, // We want a clean look
      polylineOptions: {
        strokeColor: '#1A1A1A',
        strokeWeight: 4,
        strokeOpacity: 0.8
      }
    });
  }, [mapsReady]);

  // Render the already-calculated route (no extra Directions request)
  useEffect(() => {
    if (!mapsReady || !directions || !directionsRendererRef.current || !googleMapRef.current) return;

    directionsRendererRef.current.setDirections(directions);
    const bounds = directions.routes[0]?.bounds;
    if (bounds) {
      googleMapRef.current.fitBounds(bounds);
    }
  }, [mapsReady, directions]);

  return (
    <div aria-hidden="true" className="absolute inset-0 z-0 opacity-20 pointer-events-none mix-blend-multiply grayscale contrast-125">
      <div ref={mapRef} className="w-full h-full" />
      {/* Overlay gradient to fade edges */}
      <div className="absolute inset-0 bg-gradient-to-b from-editorial-100 via-transparent to-editorial-100"></div>
      <div className="absolute inset-0 bg-gradient-to-r from-editorial-100 via-transparent to-editorial-100"></div>
    </div>
  );
};

export default React.memo(MapBackground);
