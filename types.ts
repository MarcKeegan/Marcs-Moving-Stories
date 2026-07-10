/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

export type StoryStyle = 'NOIR' | 'CHILDREN' | 'HISTORICAL' | 'FANTASY' | 'HISTORIAN_GUIDE';

export type TravelMode = 'WALKING' | 'DRIVING';

export interface RouteDetails {
  startAddress: string;
  endAddress: string;
  distance: string;
  duration: string;
  durationSeconds: number;
  travelMode: TravelMode;
  voiceName?: string;
  storyStyle: StoryStyle;
}

export interface StorySegment {
    index: number; // 1-based index
    text: string;
    audioUrl: string | null; // Blob URL for <audio> tag
}

export interface AudioStory {
  totalSegmentsEstimate: number;
  outline: string[];
  segments: StorySegment[];
}

export enum AppState {
  PLANNING,
  GENERATING_INITIAL_SEGMENT,
  READY_TO_PLAY
}
