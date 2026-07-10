/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React from 'react';
import { ArrowRight, Loader2, AlertTriangle } from 'lucide-react';
import RoutePlanner from './components/RoutePlanner';
import StoryPlayer from './components/StoryPlayer';
import MapBackground from './components/MapBackground';
import AuthScreen from './components/AuthScreen';
import { AppState } from './types';
import { useAuth } from './AuthContext';
import { useGoogleMaps } from './hooks/useGoogleMaps';
import { useStoryEngine } from './hooks/useStoryEngine';

const LOGO_URL = 'https://res.cloudinary.com/marcusdiablo/image/upload/v1768537734/storymaps_sbmb9p.png';

function App() {
    const { user, loading, logout } = useAuth();
    const { error: mapsError } = useGoogleMaps();
    const {
        appState,
        route,
        directions,
        story,
        loadingMessage,
        generationError,
        streamError,
        isBackgroundGenerating,
        startStory,
        reset,
        retryStream,
        onSegmentChange,
    } = useStoryEngine();

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
        return <AuthScreen />;
    }

    if (mapsError) {
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
                    <p className="text-stone-600 font-medium">{mapsError}</p>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-editorial-100 text-editorial-900 relative selection:bg-stone-200">
            <MapBackground directions={directions} />

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
                        Every journey has a story.
                    </h1>
                    <p className="text-[1.1rem] text-stone-600 max-w-xl leading-relaxed font-light">
                        Navigation apps tell you where to turn. StoryPath tells you what it feels like. Simply select your start and finish, pick a genre, and let us create a unique audio companion for the road ahead.
                    </p>
                </div>

                {/* Stage 1: Planning */}
                <div className={`max-w-4xl mx-auto transition-all duration-700 ${appState > AppState.GENERATING_INITIAL_SEGMENT ? 'hidden' : 'block'}`}>
                    <RoutePlanner
                        onRouteFound={startStory}
                        appState={appState}
                        externalError={generationError}
                    />
                </div>

                {/* Stage 2: Generating the first segment */}
                {appState === AppState.GENERATING_INITIAL_SEGMENT && (
                    <div className="mt-16 flex flex-col items-center justify-center space-y-8 animate-fade-in text-center py-12 max-w-4xl mx-auto">
                        <Loader2 size={48} className="animate-spin text-editorial-900" />
                        <h3 className="text-3xl font-display text-editorial-900">{loadingMessage}</h3>
                    </div>
                )}

                {/* Stage 3: Player (continuous stream) */}
                {appState >= AppState.READY_TO_PLAY && story && route && (
                    <div className="mt-8 animate-fade-in">
                        <StoryPlayer
                            story={story}
                            route={route}
                            directions={directions}
                            onSegmentChange={onSegmentChange}
                            isBackgroundGenerating={isBackgroundGenerating}
                            streamError={streamError}
                            onRetryStream={retryStream}
                        />

                        <div className="mt-24 text-center border-t border-stone-200 pt-12">
                            <button
                                onClick={reset}
                                className="group bg-white hover:bg-stone-50 text-editorial-900 px-8 py-4 rounded-full font-bold flex items-center gap-3 mx-auto transition-all border-2 border-stone-100 hover:border-stone-200 shadow-sm"
                            >
                                End Journey &amp; Start New
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
