/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/


import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, '.', '');
    
    // helper to clean keys
    const cleanKey = (key: string | undefined) => {
      if (!key) return undefined;
      const k = key.trim();
      // Filter out common placeholders or invalid values
      if (
        k === '' ||
        k === 'GEMINI_API_KEY' ||
        k === 'API_KEY' ||
        k === 'GOOGLE_MAPS_API_KEY' ||
        k.includes('YOUR_API_KEY') ||
        k === 'PLACEHOLDER'
      ) return undefined;
      return k;
    };

    // Google Maps JS API key (used to load Maps + Places). Maps browser keys are
    // public by design but MUST be HTTP-referrer-restricted in Google Cloud Console.
    const mapsApiKey = cleanKey(process.env.GOOGLE_MAPS_API_KEY) ||
                       cleanKey(env.GOOGLE_MAPS_API_KEY);

    if (!mapsApiKey) {
       console.warn("⚠️  WARNING: GOOGLE_MAPS_API_KEY is undefined. Map features may not function correctly.");
    } else {
       console.log("✅ GOOGLE_MAPS_API_KEY loaded for build.");
    }

    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
      },
      plugins: [react(), tailwindcss()],
      define: {
        // The Maps key is the only secretless key that belongs in the client bundle.
        // Gemini keys must never be defined here: production traffic goes through the
        // server proxy, and local dev uses VITE_GEMINI_API_KEY via import.meta.env.
        'process.env.GOOGLE_MAPS_API_KEY': mapsApiKey ? JSON.stringify(mapsApiKey) : 'undefined',
      },
      resolve: {
        alias: {
          '@': path.resolve('.'),
        }
      }
    };
});
