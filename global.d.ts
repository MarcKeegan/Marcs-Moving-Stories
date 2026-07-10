/**
 * Ambient declarations for globals used across the app.
 */

interface RuntimeEnv {
  GOOGLE_MAPS_API_KEY?: string;
  API_KEY?: string;
  GEMINI_USE_PROXY?: boolean;
  FIREBASE_API_KEY?: string;
  FIREBASE_AUTH_DOMAIN?: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_APP_ID?: string;
}

interface Window {
  /** Injected by server/server.js when the app is served behind the proxy. */
  __ENV__?: RuntimeEnv;
  /** Kept fresh by firebase.ts for the WebSocket proxy interceptor. */
  __FIREBASE_ID_TOKEN__?: string;
  /** Google Maps JS API failure callback (see useGoogleMaps). */
  gm_authFailure?: () => void;
}
