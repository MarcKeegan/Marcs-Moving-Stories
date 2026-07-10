import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, onIdTokenChanged } from 'firebase/auth';
import { getAnalytics, isSupported as analyticsIsSupported, logEvent as firebaseLogEvent, Analytics } from 'firebase/analytics';

const runtimeEnv =
  typeof window !== 'undefined' ? window.__ENV__ : undefined;

const firebaseConfig = {
  apiKey:
    (runtimeEnv?.FIREBASE_API_KEY as string) ??
    (import.meta.env.VITE_FIREBASE_API_KEY as string),
  authDomain:
    (runtimeEnv?.FIREBASE_AUTH_DOMAIN as string) ??
    (import.meta.env.VITE_FIREBASE_AUTH_DOMAIN as string),
  projectId:
    (runtimeEnv?.FIREBASE_PROJECT_ID as string) ??
    (import.meta.env.VITE_FIREBASE_PROJECT_ID as string),
  appId:
    (runtimeEnv?.FIREBASE_APP_ID as string) ??
    (import.meta.env.VITE_FIREBASE_APP_ID as string),
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();

// The WebSocket constructor cannot send headers, so the proxy's WebSocket
// interceptor reads the current ID token from this global instead. Firebase
// refreshes the token automatically and fires this listener each time.
if (typeof window !== 'undefined') {
  onIdTokenChanged(auth, async (user) => {
    window.__FIREBASE_ID_TOKEN__ = user ? await user.getIdToken() : undefined;
  });
}

// Initialize Firebase Analytics (only in browser environments that support it)
let analytics: Analytics | null = null;
if (typeof window !== 'undefined') {
  analyticsIsSupported()
    .then((supported) => {
      if (supported) {
        analytics = getAnalytics(app);
      }
    })
    .catch(() => {
      // Analytics is best-effort; never let it break the app.
    });
}

export { analytics };

// Helper function to log analytics events
export const logEvent = (eventName: string, eventParams?: Record<string, unknown>) => {
  if (analytics) {
    firebaseLogEvent(analytics, eventName, eventParams);
    console.log('📊 Analytics:', eventName, eventParams);
  }
};
