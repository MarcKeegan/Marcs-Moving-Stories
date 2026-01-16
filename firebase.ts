import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider } from 'firebase/auth';

const runtimeEnv =
  typeof window !== 'undefined' ? (window as any).__ENV__ : undefined;

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

