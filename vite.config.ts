/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/


import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

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

    // Gemini key (used by @google/genai in the frontend, if you're not using the proxy server)
    const geminiApiKey = cleanKey(process.env.GEMINI_API_KEY) ||
                         cleanKey(process.env.API_KEY) ||
                         cleanKey(env.GEMINI_API_KEY) ||
                         cleanKey(env.API_KEY);

    // Google Maps JS API key (used to load Maps + Places)
    const mapsApiKey = cleanKey(process.env.GOOGLE_MAPS_API_KEY) ||
                       cleanKey(env.GOOGLE_MAPS_API_KEY);

    if (!mapsApiKey) {
       console.warn("⚠️  WARNING: GOOGLE_MAPS_API_KEY is undefined. Map features may not function correctly.");
    } else {
       console.log("✅ GOOGLE_MAPS_API_KEY loaded for build.");
    }

    if (!geminiApiKey) {
       console.warn("⚠️  WARNING: GEMINI_API_KEY (or API_KEY) is undefined. Gemini features may not function correctly.");
    } else {
       console.log("✅ GEMINI_API_KEY loaded for build.");
    }

    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
      },
      plugins: [react()],
      define: {
        // Correctly inject string values.
        // If undefined, set to `undefined` (safer to detect than an empty string).
        'process.env.GOOGLE_MAPS_API_KEY': mapsApiKey ? JSON.stringify(mapsApiKey) : 'undefined',
        'process.env.GEMINI_API_KEY': geminiApiKey ? JSON.stringify(geminiApiKey) : 'undefined',
        // Back-compat: some code paths still read API_KEY.
        'process.env.API_KEY': geminiApiKey ? JSON.stringify(geminiApiKey) : 'undefined',
      },
      resolve: {
        alias: {
          '@': path.resolve('.'),
        }
      }
    };
});
