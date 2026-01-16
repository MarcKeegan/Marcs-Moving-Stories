/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/



import React, { useEffect, useRef, useState } from 'react';
import { Play, Pause, Volume2, MapPin, Clock, Footprints, Car, Loader2, ArrowDownCircle } from 'lucide-react';
import { AudioStory, RouteDetails, StorySegment } from '../types';
import InlineMap from './InlineMap';

interface Props {
    story: AudioStory;
    route: RouteDetails;
    onSegmentChange: (index: number) => void;
    isBackgroundGenerating: boolean;
}

const StoryPlayer: React.FC<Props> = ({ story, route, onSegmentChange, isBackgroundGenerating }) => {
    const [isPlaying, setIsPlaying] = useState(false);
    const [currentSegmentIndex, setCurrentSegmentIndex] = useState(0);
    const [isBuffering, setIsBuffering] = useState(false);
    const [autoScroll, setAutoScroll] = useState(true);

    // Audio Engine Refs
    const audioRef = useRef<HTMLAudioElement | null>(null);

    // CRITICAL FIX: Ref to track current index inside async audio callbacks
    const indexRef = useRef(currentSegmentIndex);

    const textContainerRef = useRef<HTMLDivElement>(null);

    const currentSegment = story.segments[currentSegmentIndex];

    // Keep ref in sync with state
    useEffect(() => {
        indexRef.current = currentSegmentIndex;
    }, [currentSegmentIndex]);

    // Notify parent App of current index for buffering purposes
    useEffect(() => {
        onSegmentChange(currentSegmentIndex);
    }, [currentSegmentIndex, onSegmentChange]);

    // Auto-play NEXT segment if we were buffering and it just arrived
    useEffect(() => {
        // Check if the *current* segment (which might have just arrived) is now ready
        const segmentNowReady = story.segments[currentSegmentIndex];

        if (isBuffering && isPlaying && segmentNowReady?.audioUrl) {
            console.log(`[StoryPlayer] Segment ${currentSegmentIndex} arrived while buffering. Resuming...`);
            setIsBuffering(false);
            playSegment(segmentNowReady);
        }
    }, [story.segments, currentSegmentIndex, isBuffering, isPlaying]);

    // Auto-scroll handling
    useEffect(() => {
        if (autoScroll && textContainerRef.current) {
            const lastParagraph = textContainerRef.current.lastElementChild;
            lastParagraph?.scrollIntoView({ behavior: 'smooth', block: 'end' });
        }
    }, [story.segments.length, currentSegmentIndex, autoScroll]);


    // --- Audio Engine ---

    // Setup audio element listeners on mount
    useEffect(() => {
        if (!audioRef.current) {
            audioRef.current = new Audio();
            audioRef.current.preload = "auto";
        }

        const audio = audioRef.current;

        const onEnded = () => {
            handleSegmentEnd();
        };

        const onError = (e: Event) => {
            console.error("[StoryPlayer] Audio playback error:", e);
            // Try to skip to next if error
            handleSegmentEnd();
        };

        audio.addEventListener('ended', onEnded);
        audio.addEventListener('error', onError);

        return () => {
            audio.pause();
            audio.src = "";
            audio.removeEventListener('ended', onEnded);
            audio.removeEventListener('error', onError);
        };
    }, []);

    const playSegment = async (segment: StorySegment) => {
        if (!segment?.audioUrl) {
            console.warn("Attempted to play segment without audio URL");
            setIsBuffering(true);
            return;
        }

        if (!audioRef.current) return;

        // Check if we are already playing this url (resume scenario)
        if (audioRef.current.src === segment.audioUrl && audioRef.current.paused) {
            try {
                await audioRef.current.play();
            } catch (e) {
                console.error("Resume failed", e);
            }
            return;
        }

        console.log(`[StoryPlayer] Playing segment ${segment.index}`);

        try {
            audioRef.current.src = segment.audioUrl;
            await audioRef.current.play();
        } catch (e) {
            console.error("[StoryPlayer] Play failed:", e);
            // If play fails (e.g. strict autoplay policy), we might need user interaction.
            // Since we are already in a "Playback" flow started by a click, this should be fine.
            setIsPlaying(false);
        }
    };

    const handleSegmentEnd = () => {
        // USE REF TO GET LATEST INDEX, NOT STALE CLOSURE
        const currentIndex = indexRef.current;
        const nextIndex = currentIndex + 1;

        console.log(`[StoryPlayer] Segment ${currentIndex} ended. Advancing to ${nextIndex}.`);

        setCurrentSegmentIndex(nextIndex);

        // Check if next segment is already available in the story prop
        if (story.segments[nextIndex]?.audioUrl) {
            playSegment(story.segments[nextIndex]);
        } else {
            // Check if we reached the absolute end of the estimated journey
            if (nextIndex >= story.totalSegmentsEstimate && !isBackgroundGenerating) {
                console.log("[StoryPlayer] Reached end of journey.");
                setIsPlaying(false);
            } else {
                console.log(`[StoryPlayer] Segment index ${nextIndex} not ready. Buffering...`);
                setIsBuffering(true);
            }
        }
    };

    const togglePlayback = async () => {
        if (!audioRef.current) return;

        if (isPlaying) {
            // PAUSE
            audioRef.current.pause();
            setIsPlaying(false);
            setAutoScroll(false); // User likely wants to read if they paused
        } else {
            // RESUME / PLAY
            setIsPlaying(true);
            if (currentSegment?.audioUrl) {
                setIsBuffering(false);
                // If we have a src already, just play, otherwise load the segment
                if (audioRef.current.src && audioRef.current.src === currentSegment.audioUrl) {
                    audioRef.current.play();
                    setAutoScroll(true);
                } else {
                    playSegment(currentSegment);
                    setAutoScroll(true);
                }
            } else {
                setIsBuffering(true);
            }
        }
    };

    const ModeIcon = route.travelMode === 'DRIVING' ? Car : Footprints;

    return (
        <div className="w-full max-w-5xl mx-auto animate-fade-in pb-24 px-4 md:px-6">

            {/* Hero Map (16:9) */}
            <div className="w-full aspect-video bg-stone-100 rounded-[2rem] shadow-2xl overflow-hidden relative mb-8 border-4 border-white">
                <InlineMap
                    route={route}
                    currentSegmentIndex={currentSegmentIndex}
                    totalSegments={story.totalSegmentsEstimate}
                />
                {/* Destination Overlay */}
                <div className="absolute bottom-4 left-4 right-4 md:bottom-6 md:left-6 md:right-auto bg-white/95 backdrop-blur-md p-4 rounded-[1.5rem] shadow-lg border border-white/50 flex items-center gap-4 md:max-w-md z-10">
                    <div className="bg-editorial-900 text-white p-3 rounded-full shrink-0">
                        <ModeIcon size={20} />
                    </div>
                    <div className="min-w-0 flex-1">
                        <div className="text-xs text-stone-500 font-bold uppercase tracking-wider mb-0.5">Destination</div>
                        <div className="text-editorial-900 font-display text-lg leading-tight truncate">{route.endAddress}</div>
                    </div>
                </div>
            </div>

            {/* Sticky Player Header */}
            <div className="sticky top-6 z-30 bg-editorial-900 text-white rounded-full p-4 md:p-5 shadow-2xl mb-16 flex items-center justify-between transition-transform ring-4 ring-editorial-100">
                <div className="flex items-center gap-4 pl-4">
                    {isBuffering ? (
                        <div className="flex items-center gap-2 text-amber-300 text-sm font-medium animate-pulse">
                            <Loader2 size={18} className="animate-spin" />
                            <span>Buffering stream...</span>
                        </div>
                    ) : (
                        <div className="flex items-center gap-3">
                            <div className={`w-3 h-3 rounded-full ${isPlaying ? 'bg-green-400 animate-pulse' : 'bg-stone-500'}`}></div>
                            <span className="text-sm font-medium text-stone-300 hidden md:block">
                                {isPlaying ? 'Live Story Stream' : 'Stream Paused'}
                            </span>
                        </div>
                    )}
                </div>

                <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center gap-2">
                    <span className="font-display text-lg md:text-xl">
                        {route.duration} Journey
                    </span>
                </div>

                <div className="flex items-center gap-4 pr-1">
                    <button onClick={() => setAutoScroll(!autoScroll)} className={`p-2 rounded-full transition-colors ${autoScroll ? 'text-white bg-white/10' : 'text-stone-500 hover:text-white'}`} title="Toggle Auto-scroll">
                        <ArrowDownCircle size={20} />
                    </button>
                    <button
                        onClick={togglePlayback}
                        // Don't disable if buffering, allow them to "pause" the buffering state if they want to stop altogether
                        className="bg-white text-editorial-900 p-3 md:p-4 rounded-full hover:scale-105 active:scale-95 transition-all disabled:opacity-50"
                    >
                        {isPlaying && !isBuffering ? <Pause size={24} className="fill-current" /> : <Play size={24} className="fill-current ml-1" />}
                    </button>
                </div>
            </div>

            {/* Continuous Story Stream */}
            <div ref={textContainerRef} className="max-w-3xl mx-auto space-y-12 min-h-[50vh]">
                {story.segments.map((segment, idx) => (
                    <div
                        key={segment.index}
                        className={`transition-all duration-1000 ${segment.index === currentSegmentIndex + 1 ? 'opacity-100 scale-100' : segment.index <= currentSegmentIndex ? 'opacity-60' : 'opacity-0 translate-y-10'}`}
                    >
                        <p className="prose prose-xl md:prose-2xl max-w-none font-display leading-relaxed text-editorial-900">
                            {segment.text}
                        </p>
                        {idx < story.segments.length - 1 && (
                            <div className="w-24 h-[2px] bg-stone-200 my-12 mx-auto"></div>
                        )}
                    </div>
                ))}

                {/* 'Typing' indicator when buffering next segment */}
                {(isBuffering || isBackgroundGenerating) && (
                    <div className="flex flex-col items-center justify-center gap-3 pt-12 pb-4 opacity-70 animate-pulse">
                        <div className="relative">
                            <Loader2 size={24} className="animate-spin text-editorial-900" />
                        </div>
                        <span className="text-sm font-medium text-stone-500 uppercase tracking-widest">Loading next paragraph...</span>
                    </div>
                )}
            </div>
        </div>
    );
};

export default StoryPlayer;