/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import { useEffect, useState } from 'react';

const SCRIPT_ID = 'google-maps-script';

const getMapsApiKey = (): string | null => {
  // Prefer the runtime-injected key (window.__ENV__, set by the proxy server).
  const runtimeKey = window.__ENV__?.GOOGLE_MAPS_API_KEY;
  if (runtimeKey) return runtimeKey;

  const key = process.env.GOOGLE_MAPS_API_KEY;
  // Vite injects the literal string 'undefined' if the var was missing at build time.
  if (!key || key === 'undefined') return null;
  return key.replace(/["']/g, '').trim();
};

// Single shared loader so every consumer of the hook waits on the same script.
let loaderPromise: Promise<void> | null = null;

const loadGoogleMaps = (): Promise<void> => {
  if (loaderPromise) return loaderPromise;

  loaderPromise = new Promise<void>((resolve, reject) => {
    if (window.google?.maps?.places) {
      resolve();
      return;
    }

    const mapsApiKey = getMapsApiKey();
    if (!mapsApiKey) {
      reject(new Error('Google Maps API key is missing. Set GOOGLE_MAPS_API_KEY in your environment.'));
      return;
    }

    // With loading=async the API is only usable once the bootstrap invokes
    // the callback, not when the script tag finishes loading.
    window.__onGoogleMapsLoaded = () => resolve();

    const script = document.createElement('script');
    script.id = SCRIPT_ID;
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(mapsApiKey)}&loading=async&v=weekly&libraries=places&callback=__onGoogleMapsLoaded`;
    script.async = true;
    script.onerror = () => reject(new Error('Google Maps failed to load.'));
    document.head.appendChild(script);
  });

  return loaderPromise;
};

/**
 * Loads the Google Maps JS API exactly once and reports readiness.
 * Any number of components can call this; they all share one script load.
 */
export function useGoogleMaps(): { ready: boolean; error: string | null } {
  const [ready, setReady] = useState<boolean>(() => Boolean(window.google?.maps?.places));
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    // Fired by the Maps API (after load) when the key is invalid/unauthorized.
    window.gm_authFailure = () => {
      if (!cancelled) setError('Google Maps authentication failed. Please check your API key.');
    };

    loadGoogleMaps().then(
      () => {
        if (!cancelled) setReady(true);
      },
      (e: Error) => {
        if (!cancelled) setError(e.message);
      }
    );

    return () => {
      cancelled = true;
    };
  }, []);

  return { ready, error };
}
