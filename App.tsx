/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/



import React, { useState, useEffect, useRef } from 'react';
import { Headphones, Map as MapIcon, Sparkles, ArrowRight, Loader2, AlertTriangle } from 'lucide-react';
import RoutePlanner from './components/RoutePlanner';
import StoryPlayer from './components/StoryPlayer';
import MapBackground from './components/MapBackground';
import { AppState, RouteDetails, AudioStory } from './types';
import { generateSegment, generateSegmentAudio, calculateTotalSegments, generateStoryOutline } from './services/geminiService';
import { useAuth } from './AuthContext';

declare global {
    interface Window {
        webkitAudioContext: typeof AudioContext;
    }
}

// Helper to prevent infinite hangs on network requests
const withTimeout = <T,>(promise: Promise<T>, ms: number, errorMsg: string): Promise<T> => {
    let timer: any;
    const timeoutPromise = new Promise<T>((_, reject) => {
        timer = setTimeout(() => reject(new Error(errorMsg)), ms);
    });
    return Promise.race([
        promise.then(val => { clearTimeout(timer); return val; }),
        timeoutPromise
    ]);
};

const LOGO_URL = 'https://res.cloudinary.com/marcusdiablo/image/upload/v1768537734/storymaps_sbmb9p.png';

function App() {
    const {
        user,
        loading,
        error: authError,
        loginWithGoogle,
        loginWithEmail,
        registerWithEmail,
        resetPassword,
        logout,
    } = useAuth();

    const [authMode, setAuthMode] = useState<'login' | 'signup' | 'reset'>('login');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [localAuthError, setLocalAuthError] = useState<string | null>(null);
    const [resetMessage, setResetMessage] = useState<string | null>(null);

    const [appState, setAppState] = useState<AppState>(AppState.PLANNING);
    const [route, setRoute] = useState<RouteDetails | null>(null);
    const [story, setStory] = useState<AudioStory | null>(null);
    const [loadingMessage, setLoadingMessage] = useState('');
    const [scriptError, setScriptError] = useState<string | null>(null);
    const [generationError, setGenerationError] = useState<string | null>(null);

    // --- Buffering Engine State ---
    const isGeneratingRef = useRef<boolean>(false);
    const [isBackgroundGenerating, setIsBackgroundGenerating] = useState(false);
    // Track which segment the user is currently listening to (fed back from StoryPlayer)
    const [currentPlayingIndex, setCurrentPlayingIndex] = useState<number>(0);

    // --- Google Maps Bootstrap ---
    useEffect(() => {
        const SCRIPT_ID = 'google-maps-script';

        const getMapsApiKey = () => {
            // Prioritize runtime-injected key
            const runtimeEnv = (window as any).__ENV__;
            if (runtimeEnv && runtimeEnv.GOOGLE_MAPS_API_KEY) {
                return runtimeEnv.GOOGLE_MAPS_API_KEY;
            }

            const key = process.env.GOOGLE_MAPS_API_KEY;
            // Check for 'undefined' string which Vite might inject if the var was missing at build time
            if (!key || key === 'undefined') return null;
            return key.replace(/["']/g, "").trim();
        };

        const mapsApiKey = getMapsApiKey();

        if (!mapsApiKey) {
            setScriptError("Google Maps API key is missing. Set GOOGLE_MAPS_API_KEY in your environment.");
            console.error("Critical: process.env.GOOGLE_MAPS_API_KEY is missing or empty.");
            return;
        }

        if (document.getElementById(SCRIPT_ID) || window.google?.maps) return;



        const script = document.createElement('script');
        script.id = SCRIPT_ID;
        script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(mapsApiKey)}&loading=async&v=weekly&libraries=places`;
        script.async = true;
        script.defer = true;
        script.onerror = () => setScriptError("Google Maps failed to load.");
        // @ts-ignore
        window.gm_authFailure = () => setScriptError("Google Maps authentication failed. Please check your API key.");
        document.head.appendChild(script);
    }, []);

    const handleEmailSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLocalAuthError(null);
        setResetMessage(null);

        if (authMode === 'signup') {
            if (password !== confirmPassword) {
                setLocalAuthError("Passwords don't match");
                return;
            }
            if (password.length < 6) {
                setLocalAuthError('Password should be at least 6 characters');
                return;
            }
            await registerWithEmail(email, password);
        } else if (authMode === 'login') {
            await loginWithEmail(email, password);
        } else if (authMode === 'reset') {
            if (!email) {
                setLocalAuthError('Enter your email to reset your password');
                return;
            }
            await resetPassword(email);
            setResetMessage('If an account exists for that email, a reset link has been sent.');
        }
    };

    // --- Continuous Buffering Engine ---
    // Keeps 2 segments ahead of the current playback position
    useEffect(() => {
        if (!story || !route || appState < AppState.READY_TO_PLAY) return;

        const totalGenerated = story.segments.length;
        // We use index + 1 because playingIndex is 0-based, but segment count is 1-based total
        const neededBufferIndex = currentPlayingIndex + 3;

        if (totalGenerated < neededBufferIndex && totalGenerated < story.totalSegmentsEstimate && !isGeneratingRef.current) {
            generateNextSegment(totalGenerated + 1);
        }
    }, [story, route, appState, currentPlayingIndex]);

    const generateNextSegment = async (index: number) => {
        if (!route || !story || isGeneratingRef.current) return;

        try {
            isGeneratingRef.current = true;
            setIsBackgroundGenerating(true);
            console.log(`[Buffering] Starting generation for Segment ${index}...`);

            // Gather all previous text for robust context, but limit length to avoid token overflow
            const allPreviousText = story.segments.map(s => s.text).join(" ").slice(-3000);

            // Get the specific outline beat for this segment. 
            // Fallback to generic if we somehow exceed the outline length.
            const segmentOutline = story.outline[index - 1] || "Continue the journey towards the final destination, wrapping up any loose narrative threads.";

            // 1. Generate Text (increased to 60s timeout for safety)
            const segmentData = await withTimeout(
                generateSegment(route, index, story.totalSegmentsEstimate, segmentOutline, allPreviousText),
                60000,
                `Text generation timed out for segment ${index}`
            );

            // 2. Generate Audio (increased to 100s timeout as TTS can be slow under load)
            const audioUrl = await withTimeout(
                generateSegmentAudio(segmentData.text),
                100000,
                `Audio generation timed out for segment ${index}`
            );

            // 3. Append to stream
            setStory(prev => {
                if (!prev) return null;
                // Ensure we don't add duplicates if race conditions occurred
                if (prev.segments.some(s => s.index === index)) return prev;
                return {
                    ...prev,
                    segments: [...prev.segments, { ...segmentData, audioUrl }].sort((a, b) => a.index - b.index)
                };
            });
            console.log(`[Buffering] Segment ${index} ready.`);

        } catch (e) {
            console.error(`Failed to generate segment ${index}`, e);
            // We don't alert the user, we just hope the next attempt works.
            // The continuous loop in useEffect will retry if we are still behind buffer.
        } finally {
            isGeneratingRef.current = false;
            setIsBackgroundGenerating(false);
        }
    };

    // --- Handlers ---
    const handleGenerateStory = async (details: RouteDetails) => {
        setRoute(details);
        setGenerationError(null);

        try {
            setAppState(AppState.GENERATING_INITIAL_SEGMENT);
            window.scrollTo({ top: 0, behavior: 'smooth' });

            const totalSegmentsEstimate = calculateTotalSegments(details.durationSeconds);
            setLoadingMessage("Crafting story arc...1 - 2 minutes");

            // 1. Generate the Story Outline first
            // Increased timeout to 60s to handle long complex journeys
            const outline = await withTimeout(
                generateStoryOutline(details, totalSegmentsEstimate),
                60000, "Story outline generation timed out"
            );

            setLoadingMessage("Writing first chapter... 1 minute");

            // 2. Generate first segment using the first outline beat
            const firstOutlineBeat = outline[0] || "Begin the journey.";
            const seg1Data = await withTimeout(
                generateSegment(details, 1, totalSegmentsEstimate, firstOutlineBeat, ""),
                60000, "Initial text generation timed out"
            );

            setLoadingMessage("Preparing audio stream...30 seconds");
            const seg1AudioUrl = await withTimeout(
                generateSegmentAudio(seg1Data.text),
                100000, "Initial audio generation timed out"
            );

            setStory({
                totalSegmentsEstimate,
                outline,
                segments: [{ ...seg1Data, audioUrl: seg1AudioUrl }]
            });

            setAppState(AppState.READY_TO_PLAY);

        } catch (error: any) {
            console.error("Initial generation failed:", error);
            setAppState(AppState.PLANNING);

            let message = "Failed to start story stream. Please check your locations/connection and try again.";
            if (error.message && (error.message.includes("timed out") || error.message.includes("timeout"))) {
                message = "Story generation timed out. It might be that your journey is too long. Please try again.";
            }

            setGenerationError(message);
        }
    };

    const handleReset = () => {
        setAppState(AppState.PLANNING);
        setRoute(null);
        setStory(null);
        setCurrentPlayingIndex(0);
        setGenerationError(null);
        isGeneratingRef.current = false;
        setIsBackgroundGenerating(false);
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // --- Render Helpers ---
    const isHeroVisible = appState < AppState.READY_TO_PLAY;

    if (loading) {
        return (
            <div className="min-h-screen bg-editorial-100 flex items-center justify-center">
                <div className="flex flex-col items-center gap-4">
                    <img
                        src={LOGO_URL}
                        alt="StoryMaps"
                        className="h-12 w-auto"
                        loading="eager"
                        decoding="async"
                    />
                    <p className="text-stone-600">Checking your session...</p>
                </div>
            </div>
        );
    }

    if (!user) {
        return (
            <div className="min-h-screen bg-editorial-100 flex items-center justify-center px-6">
                <div className="bg-white p-8 md:p-10 rounded-[2rem] shadow-xl max-w-md w-full space-y-6 border border-stone-100">
                    <div className="flex justify-center">
                        <img
                            src={LOGO_URL}
                            alt="StoryMaps"
                            className="h-16 w-auto"
                            loading="eager"
                            decoding="async"
                        />
                    </div>
                    <h1 className="text-3xl font-display text-editorial-900 text-center">
                        Welcome to StoryMaps.
                    </h1>
                    <p className="text-stone-500 text-center">
                        Sign in to create and listen to personalized journey stories.
                    </p>

                    <div className="flex rounded-full bg-stone-100 p-1 text-sm font-medium">
                        <button
                            type="button"
                            onClick={() => setAuthMode('login')}
                            className={`flex-1 py-2 rounded-full transition-all ${authMode === 'login'
                                ? 'bg-white text-editorial-900 shadow-sm'
                                : 'text-stone-500'
                                }`}
                        >
                            Sign in
                        </button>
                        <button
                            type="button"
                            onClick={() => setAuthMode('signup')}
                            className={`flex-1 py-2 rounded-full transition-all ${authMode === 'signup'
                                ? 'bg-white text-editorial-900 shadow-sm'
                                : 'text-stone-500'
                                }`}
                        >
                            Sign up
                        </button>
                    </div>

                    <form onSubmit={handleEmailSubmit} className="space-y-4">
                        <div className="space-y-1">
                            <label className="text-sm font-medium text-stone-600">Email</label>
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-editorial-900/40"
                                required
                            />
                        </div>

                        {authMode !== 'reset' && (
                            <>
                                <div className="space-y-1">
                                    <label className="text-sm font-medium text-stone-600">Password</label>
                                    <input
                                        type="password"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-editorial-900/40"
                                        required
                                    />
                                </div>
                                {authMode === 'signup' && (
                                    <div className="space-y-1">
                                        <label className="text-sm font-medium text-stone-600">Confirm password</label>
                                        <input
                                            type="password"
                                            value={confirmPassword}
                                            onChange={(e) => setConfirmPassword(e.target.value)}
                                            className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-editorial-900/40"
                                            required
                                        />
                                    </div>
                                )}
                            </>
                        )}

                        {(localAuthError || authError) && (
                            <p className="text-xs text-red-600 bg-red-50 px-3 py-2 rounded-lg">
                                {localAuthError || authError}
                            </p>
                        )}

                        {resetMessage && (
                            <p className="text-xs text-green-700 bg-green-50 px-3 py-2 rounded-lg">
                                {resetMessage}
                            </p>
                        )}

                        <button
                            type="submit"
                            className="w-full bg-editorial-900 text-white py-3 rounded-full font-semibold text-sm hover:bg-stone-800 transition-all"
                        >
                            {authMode === 'signup'
                                ? 'Create account'
                                : authMode === 'reset'
                                    ? 'Send reset link'
                                    : 'Sign in with email'}
                        </button>

                        {authMode === 'login' && (
                            <button
                                type="button"
                                onClick={() => setAuthMode('reset')}
                                className="block w-full text-xs text-center text-stone-500 hover:text-editorial-900 mt-1 underline"
                            >
                                Forgot password?
                            </button>
                        )}
                        {authMode === 'reset' && (
                            <button
                                type="button"
                                onClick={() => setAuthMode('login')}
                                className="block w-full text-xs text-center text-stone-500 hover:text-editorial-900 mt-1 underline"
                            >
                                Back to sign in
                            </button>
                        )}
                    </form>

                    <div className="flex items-center gap-3">
                        <div className="h-px bg-stone-200 flex-1" />
                        <span className="text-xs text-stone-400 uppercase tracking-widest">or</span>
                        <div className="h-px bg-stone-200 flex-1" />
                    </div>

                    <button
                        onClick={loginWithGoogle}
                        className="w-full border border-stone-200 bg-white text-editorial-900 py-3 rounded-full font-semibold text-sm hover:bg-stone-50 transition-all"
                    >
                        Continue with Google
                    </button>
                </div>
            </div>
        );
    }

    if (scriptError) {
        return (
            <div className="min-h-screen bg-editorial-100 flex items-center justify-center p-6">
                <div className="bg-white p-8 rounded-[2rem] shadow-xl max-w-md text-center space-y-4 border-2 border-red-100">
                    <div className="flex justify-center pb-2">
                        <img
                            src={LOGO_URL}
                            alt="StoryMaps"
                            className="h-12 w-auto"
                            loading="eager"
                            decoding="async"
                        />
                    </div>
                    <AlertTriangle size={32} className="text-red-500 mx-auto" />
                    <p className="text-stone-600 font-medium">{scriptError}</p>
                </div>
            </div>
        )
    }

    return (
        <div className="min-h-screen bg-editorial-100 text-editorial-900 relative selection:bg-stone-200">
            <MapBackground route={route} />

            <main className="relative z-10 max-w-7xl mx-auto px-6 pt-16 pb-32">
                <header className="max-w-4xl mx-auto flex items-center justify-between mb-12">
                    <img
                        src={LOGO_URL}
                        alt="StoryMaps"
                        className="h-10 w-auto opacity-90"
                        loading="eager"
                        decoding="async"
                    />
                    <button
                        onClick={logout}
                        className="text-xs text-stone-500 hover:text-editorial-900 underline"
                    >
                        Sign out
                    </button>
                </header>
                {/* Hero Section */}
                <div className={`transition-all duration-700 origin-top ease-in-out max-w-4xl mx-auto ${isHeroVisible ? 'opacity-100 translate-y-0 mb-16' : 'opacity-0 -translate-y-10 h-0 overflow-hidden mb-0'}`}>
                    <h1 className="text-[2rem] font-display leading-[1.05] tracking-tight mb-8">
                        Your Journey. Your Soundtrack.<br /> <span className="italic text-stone-500">Your Story.</span>
                    </h1>
                    <p className="text-[1.1rem] text-stone-600 max-w-xl leading-relaxed font-light">
                        Navigation apps tell you where to turn. StoryMaps tells you what it feels like. Simply drop a pin for your start and finish, pick a genre, and let us create a unique audio companion for the road ahead.
                    </p>
                </div>

                {/* Stage 1: Planning */}
                <div className={`max-w-4xl mx-auto transition-all duration-700 ${appState > AppState.GENERATING_INITIAL_SEGMENT ? 'hidden' : 'block'}`}>
                    <RoutePlanner
                        onRouteFound={handleGenerateStory}
                        appState={appState}
                        externalError={generationError}
                    />
                </div>

                {/* Stage 3: Loading Initial Segment (Formerly followed Stage 2 Confirmation) */}
                {appState === AppState.GENERATING_INITIAL_SEGMENT && (
                    <div className="mt-16 flex flex-col items-center justify-center space-y-8 animate-fade-in text-center py-12 max-w-4xl mx-auto">
                        <Loader2 size={48} className="animate-spin text-editorial-900" />
                        <h3 className="text-3xl font-display text-editorial-900">{loadingMessage}</h3>
                    </div>
                )}

                {/* Stage 4: Final Player (Continuous Stream) */}
                {appState >= AppState.READY_TO_PLAY && story && route && (
                    <div className="mt-8 animate-fade-in">
                        <StoryPlayer
                            story={story}
                            route={route}
                            onSegmentChange={(index) => setCurrentPlayingIndex(index)}
                            isBackgroundGenerating={isBackgroundGenerating}
                        />

                        <div className="mt-24 text-center border-t border-stone-200 pt-12">
                            <button
                                onClick={handleReset}
                                className="group bg-white hover:bg-stone-50 text-editorial-900 px-8 py-4 rounded-full font-bold flex items-center gap-3 mx-auto transition-all border-2 border-stone-100 hover:border-stone-200 shadow-sm"
                            >
                                End Journey & Start New
                                <ArrowRight size={20} className="group-hover:translate-x-1 transition-transform" />
                            </button>
                        </div>
                    </div>
                )}
            </main>
        </div>
    );
}

export default App;