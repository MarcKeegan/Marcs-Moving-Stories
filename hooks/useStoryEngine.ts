/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState, AudioStory, RouteDetails, StorySegment } from '../types';
import {
    calculateTotalSegments,
    generateSegment,
    generateSegmentAudio,
    generateStoryOutline,
} from '../services/geminiService';

// Helper to prevent infinite hangs on network requests
const withTimeout = <T,>(promise: Promise<T>, ms: number, errorMsg: string): Promise<T> => {
    let timer: ReturnType<typeof setTimeout>;
    const timeoutPromise = new Promise<T>((_, reject) => {
        timer = setTimeout(() => reject(new Error(errorMsg)), ms);
    });
    return Promise.race([
        promise.then(val => { clearTimeout(timer); return val; }),
        timeoutPromise
    ]);
};

const FALLBACK_OUTLINE_BEAT = 'Continue the journey towards the final destination, wrapping up any loose narrative threads.';

const revokeStoryAudio = (story: AudioStory | null) => {
    story?.segments.forEach((segment) => {
        if (segment.audioUrl) URL.revokeObjectURL(segment.audioUrl);
    });
};

/**
 * Owns the story lifecycle: initial generation, the continuous buffering
 * engine that keeps ~3 segments ahead of playback, error surfacing, and
 * cleanup of audio blob URLs.
 */
export function useStoryEngine() {
    const [appState, setAppState] = useState<AppState>(AppState.PLANNING);
    const [route, setRoute] = useState<RouteDetails | null>(null);
    const [directions, setDirections] = useState<google.maps.DirectionsResult | null>(null);
    const [story, setStory] = useState<AudioStory | null>(null);
    const [loadingMessage, setLoadingMessage] = useState('');
    const [generationError, setGenerationError] = useState<string | null>(null);
    const [streamError, setStreamError] = useState<string | null>(null);

    const isGeneratingRef = useRef<boolean>(false);
    const [isBackgroundGenerating, setIsBackgroundGenerating] = useState(false);
    // Which segment the user is currently listening to (fed back from StoryPlayer)
    const [currentPlayingIndex, setCurrentPlayingIndex] = useState<number>(0);

    // Revoke any outstanding audio blob URLs when the app unmounts.
    const storyRef = useRef<AudioStory | null>(null);
    useEffect(() => {
        storyRef.current = story;
    }, [story]);
    useEffect(() => () => revokeStoryAudio(storyRef.current), []);

    const generateNextSegment = useCallback(async (index: number) => {
        if (!route || !story || isGeneratingRef.current) return;

        try {
            isGeneratingRef.current = true;
            setIsBackgroundGenerating(true);

            // Gather all previous text for robust context, but limit length to avoid token overflow
            const allPreviousText = story.segments.map(s => s.text).join(' ').slice(-3000);
            const segmentOutline = story.outline[index - 1] || FALLBACK_OUTLINE_BEAT;

            // 1. Generate text
            const segmentData = await withTimeout(
                generateSegment(route, index, story.totalSegmentsEstimate, segmentOutline, allPreviousText),
                60000,
                `Text generation timed out for segment ${index}`
            );

            // 2. Generate audio and pre-fetch NEXT segment text in parallel
            const nextOutlineBeat = story.outline[index] || FALLBACK_OUTLINE_BEAT;
            const hasNextAlready = story.segments.some(s => s.index === index + 1);
            const [audioResult, nextSegDataResult] = await Promise.allSettled([
                withTimeout(
                    generateSegmentAudio(segmentData.text, route.voiceName),
                    100000,
                    `Audio generation timed out for segment ${index}`
                ),
                (!hasNextAlready && index < story.totalSegmentsEstimate)
                    ? withTimeout(
                        generateSegment(route, index + 1, story.totalSegmentsEstimate, nextOutlineBeat, allPreviousText + ' ' + segmentData.text),
                        60000,
                        `Text pre-fetch timed out for segment ${index + 1}`
                    )
                    : Promise.resolve(null)
            ]);

            if (audioResult.status === 'rejected') {
                throw new Error(audioResult.reason instanceof Error ? audioResult.reason.message : `Audio failed for segment ${index}`);
            }

            // 3. Append current segment (and optional pre-fetched next) to the stream
            setStory(prev => {
                if (!prev) return null;
                if (prev.segments.some(s => s.index === index)) return prev;
                const updated: StorySegment[] = [...prev.segments, { ...segmentData, audioUrl: audioResult.value }];

                const nextSegment = nextSegDataResult.status === 'fulfilled' ? nextSegDataResult.value : null;
                if (nextSegment && !prev.segments.some(s => s.index === index + 1)) {
                    updated.push({ ...nextSegment, audioUrl: null });
                }

                return { ...prev, segments: updated.sort((a, b) => a.index - b.index) };
            });

        } catch (e) {
            console.error(`Failed to generate segment ${index}`, e);
            // Surface the failure instead of leaving the player buffering forever.
            setStreamError('The story stream hit a snag while generating the next part.');
        } finally {
            isGeneratingRef.current = false;
            setIsBackgroundGenerating(false);
        }
    }, [route, story]);

    // Continuous buffering engine: keeps segments generating ahead of the
    // current playback position. Paused while a stream error is showing.
    useEffect(() => {
        if (!story || !route || appState < AppState.READY_TO_PLAY || streamError) return;

        const totalGenerated = story.segments.length;
        const neededBufferIndex = currentPlayingIndex + 3;

        if (totalGenerated < neededBufferIndex && totalGenerated < story.totalSegmentsEstimate && !isGeneratingRef.current) {
            generateNextSegment(totalGenerated + 1);
        }
    }, [story, route, appState, currentPlayingIndex, streamError, generateNextSegment]);

    const retryStream = useCallback(() => {
        // Clearing the error re-arms the buffering effect, which retries the
        // first missing segment.
        setStreamError(null);
    }, []);

    const startStory = useCallback(async (details: RouteDetails, routeDirections: google.maps.DirectionsResult) => {
        setRoute(details);
        setDirections(routeDirections);
        setGenerationError(null);
        setStreamError(null);

        try {
            setAppState(AppState.GENERATING_INITIAL_SEGMENT);
            window.scrollTo({ top: 0, behavior: 'smooth' });

            const totalSegmentsEstimate = calculateTotalSegments(details.durationSeconds);
            setLoadingMessage('Crafting story arc...');

            // 1. Generate the Story Outline first
            const outline = await withTimeout(
                generateStoryOutline(details, totalSegmentsEstimate),
                60000, 'Story outline generation timed out'
            );

            setLoadingMessage('Writing first chapter...');

            // 2. Generate first segment text using the first outline beat
            const firstOutlineBeat = outline[0] || 'Begin the journey.';
            const seg1Data = await withTimeout(
                generateSegment(details, 1, totalSegmentsEstimate, firstOutlineBeat, ''),
                60000, 'Initial text generation timed out'
            );

            setLoadingMessage('Preparing audio...');

            // 3. Generate audio for segment 1 AND pre-generate segment 2 text in parallel
            const secondOutlineBeat = outline[1] || 'Continue the journey.';
            const [seg1AudioUrl, seg2DataResult] = await Promise.allSettled([
                withTimeout(generateSegmentAudio(seg1Data.text, details.voiceName), 100000, 'Initial audio generation timed out'),
                withTimeout(
                    generateSegment(details, 2, totalSegmentsEstimate, secondOutlineBeat, seg1Data.text),
                    60000, 'Segment 2 text generation timed out'
                )
            ]);

            if (seg1AudioUrl.status === 'rejected') {
                throw new Error(seg1AudioUrl.reason instanceof Error ? seg1AudioUrl.reason.message : 'Audio generation failed');
            }

            const initialSegments: StorySegment[] = [{ ...seg1Data, audioUrl: seg1AudioUrl.value }];

            const seg2TextData = seg2DataResult.status === 'fulfilled' ? seg2DataResult.value : null;
            if (seg2TextData) {
                initialSegments.push({ ...seg2TextData, audioUrl: null });
            }

            setStory({
                totalSegmentsEstimate,
                outline,
                segments: initialSegments
            });

            setAppState(AppState.READY_TO_PLAY);

            // Generate audio for segment 2 in the background (don't block UI)
            if (seg2TextData && totalSegmentsEstimate > 1) {
                generateSegmentAudio(seg2TextData.text, details.voiceName)
                    .then(audioUrl => {
                        setStory(prev => {
                            if (!prev) return null;
                            return {
                                ...prev,
                                segments: prev.segments.map(s =>
                                    s.index === 2 ? { ...s, audioUrl } : s
                                )
                            };
                        });
                    })
                    .catch(e => console.warn('Background seg2 audio failed:', e));
            }

        } catch (error) {
            console.error('Initial generation failed:', error);
            setAppState(AppState.PLANNING);

            let message = 'Failed to start story stream. Please check your locations/connection and try again.';
            if (error instanceof Error && (error.message.includes('timed out') || error.message.includes('timeout'))) {
                message = 'Story generation timed out. It might be that your journey is too long. Please try again.';
            }

            setGenerationError(message);
        }
    }, []);

    const reset = useCallback(() => {
        setStory(prev => {
            revokeStoryAudio(prev);
            return null;
        });
        setAppState(AppState.PLANNING);
        setRoute(null);
        setDirections(null);
        setCurrentPlayingIndex(0);
        setGenerationError(null);
        setStreamError(null);
        isGeneratingRef.current = false;
        setIsBackgroundGenerating(false);
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }, []);

    return {
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
        onSegmentChange: setCurrentPlayingIndex,
    };
}
