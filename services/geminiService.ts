/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/



import { GoogleGenAI, Modality } from "@google/genai";
import { RouteDetails, StorySegment, StoryStyle } from "../types";
import { base64ToArrayBuffer, pcmToWav } from "./audioUtils";
import { auth } from "../firebase";

// Sanitize the key to ensure no extra quotes or whitespace
const getApiKey = () => {
  const runtimeEnv = (window as any).__ENV__;
  const runtimeKey = runtimeEnv?.API_KEY;
  if (runtimeKey && runtimeKey !== "undefined") {
    return String(runtimeKey).replace(/["']/g, "").trim();
  }

  // When deployed behind our server, we proxy all Gemini calls via /api-proxy.
  // In that mode, the browser does NOT need the real API key; the server injects it upstream.
  if (runtimeEnv?.GEMINI_USE_PROXY) {
    return "proxy";
  }

  // Local dev (vite preview/dev without the proxy server): fall back to Vite env.
  // Prefer VITE_GEMINI_API_KEY, but keep legacy VITE_API_KEY support.
  const viteEnv = (import.meta as any)?.env;
  const key = viteEnv?.VITE_GEMINI_API_KEY || viteEnv?.VITE_API_KEY || "";
  if (!key || key === "undefined") return "";
  return String(key).replace(/["']/g, "").trim();
}

const API_KEY = getApiKey();

if (!API_KEY) {
  console.warn("ECHO_PATHS WARNING: API_KEY is missing from environment.");
}


const customFetch = async (url: RequestInfo | URL, init?: RequestInit) => {
  console.log("CustomFetch PROXY: Intercepting request to", url);
  const token = await auth.currentUser?.getIdToken();
  console.error("CustomFetch PROXY: Token present?", !!token); // Using error to ensure visibility
  const newInit = { ...init, headers: new Headers(init?.headers) };
  if (token) {
    newInit.headers.set('Authorization', `Bearer ${token}`);
    console.log("CustomFetch PROXY: Authorization header set.");
  } else {
    console.warn("CustomFetch PROXY: No token found for user.");
    // If we are using the proxy, we MUST have a token.
    if (API_KEY === "proxy") {
      throw new Error("Authentication required: Please sign in.");
    }
  }
  return fetch(url, newInit);
};

const ai = new GoogleGenAI({ apiKey: API_KEY, fetch: customFetch });

// CONSTANTS FOR CONTINUOUS STREAMING
const TARGET_SEGMENT_DURATION_SEC = 60;
const WORDS_PER_MINUTE = 145;
const WORDS_PER_SEGMENT = Math.round((TARGET_SEGMENT_DURATION_SEC / 60) * WORDS_PER_MINUTE);

export const calculateTotalSegments = (durationSeconds: number): number => {
  return Math.max(1, Math.ceil(durationSeconds / TARGET_SEGMENT_DURATION_SEC));
};

const getStyleInstruction = (style: StoryStyle): string => {
  switch (style) {
    case 'NOIR':
      return "Style: Noir Thriller. Gritty, cynical, atmospheric. Use inner monologue. The traveler is a detective or someone with a troubled past. The city is a character itself—dark, rainy, hiding secrets. Use metaphors of shadows, smoke, and cold neon.";

    case 'CHILDREN':
      return "Style: Children's Story. Whimsical, magical, full of wonder and gentle humor. The world is bright and alive; maybe inanimate objects (like traffic lights or trees) have slight personalities. Simple but evocative language. A sense of delightful discovery.";
    case 'HISTORICAL':
      return "Style: Historical Epic. Grandiose, dramatic, and timeless. Treat the journey as a significant pilgrimage or quest in a bygone era (even though it's modern day, overlay it with historical grandeur). Use slightly archaic but understandable language. Focus on endurance, destiny, and the weight of history.";
    case 'FANTASY':
      return "Style: Fantasy Adventure. Heroic, mystical, and epic. The real world is just a veil over a magical realm. Streets are ancient paths, buildings are towers or ruins. The traveler is on a vital quest. Use metaphors of magic, mythical creatures (shadows might be lurking beasts), and destiny.";
    case 'HISTORIAN_GUIDE':
      return `Style: The Historian Guide. Clear, authoritative, engaging but grounded in fact. 
        Purpose: Provide historically accurate, contextual information about the route and key locations encountered along the journey.
        Voice Characteristics: Confident and knowledgeable; engaging without being theatrical; speaks like a skilled local historian or academic guide.
        Content Focus: Verified historical events tied to specific locations on the route, dates, names, and cultural context. Explain how the place has changed and why landmarks matter.
        Accuracy Requirements: All information MUST be accurate and conservative. If uncertain, acknowledge it. DO NOT invent events, people, or interpretations. 
        Constraints: Do not fictionalize. Avoid modern opinions or political framing.`;
    default:
      return "Style: Immersive, 'in the moment' narration. Focus on the sensation of movement and the immediate environment.";
  }
};

export const generateStoryOutline = async (
  route: RouteDetails,
  totalSegments: number
): Promise<string[]> => {
  const styleInstruction = getStyleInstruction(route.storyStyle);
  const prompt = `
    You are an expert storyteller. Write an outline for a story that is exactly ${totalSegments} chapters long and has a complete cohesive story arc with a clear set up, inciting incident, rising action, climax, success, falling action, and resolution. 

    Your outline should be tailored to match this journey:

    Journey: ${route.startAddress} to ${route.endAddress} by ${route.travelMode.toLowerCase()}.
    Total Duration: Approx ${route.duration}.
    Total Narrative Segments needed: ${totalSegments}.
    
    ${styleInstruction}

    Output strictly valid JSON: An array of ${totalSegments} strings. Example: ["Chapter 1 summary...", "Chapter 2 summary...", ...]
    `;

  try {
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
      config: { responseMimeType: 'application/json' }
    });

    const text = response.text?.trim();
    if (!text) throw new Error("No outline generated.");

    const outline = JSON.parse(text);
    if (!Array.isArray(outline) || outline.length === 0) {
      throw new Error("Invalid outline format received.");
    }

    // Ensure we have exactly enough segments, pad if necessary (though Gemini is usually good with explicit counts)
    while (outline.length < totalSegments) {
      outline.push("Continue the journey towards the destination.");
    }

    const finalOutline = outline.slice(0, totalSegments);
    console.log(">> STORY OUTLINE:", finalOutline);
    return finalOutline;

  } catch (error) {
    console.error("Outline Generation Error:", error);
    // Fallback outline if generation fails
    return Array(totalSegments).fill("Continue the immersive narrative of the journey.");
  }
};

export const generateSegment = async (
  route: RouteDetails,
  segmentIndex: number,
  totalSegmentsEstimate: number,
  segmentOutline: string,
  previousContext: string = ""
): Promise<StorySegment> => {

  const isFirst = segmentIndex === 1;

  let contextPrompt = "";
  if (!isFirst) {
    contextPrompt = `
      PREVIOUS NARRATIVE CONTEXT (The story so far):
      ...${previousContext.slice(-1500)} 
      (CONTINUE SEAMLESSLY from the above. Do not repeat it. Do not start with "And so..." or similar connectors every time.)
      `;
  }

  const styleInstruction = getStyleInstruction(route.storyStyle);

  const prompt = `
    You are an AI storytelling engine generating a continuous, immersive audio stream for a traveler.
    Journey: ${route.startAddress} to ${route.endAddress} by ${route.travelMode.toLowerCase()}.
    Current Status: Segment ${segmentIndex} of approx ${totalSegmentsEstimate}.
    
    ${styleInstruction}

    CURRENT CHAPTER GOAL: ${segmentOutline}

    ${contextPrompt}

    Task: Write the next ~${TARGET_SEGMENT_DURATION_SEC} seconds of narration (approx ${WORDS_PER_SEGMENT} words) based on the Current Chapter Goal.
    Keep the narrative moving forward. This is a transient segment of a longer journey.

    IMPORTANT: Output ONLY the raw narration text for this segment. Do not include titles, chapter headings, or JSON. Just the text to be spoken.
  `;

  try {
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: prompt,
    });

    const text = response.text?.trim();
    if (!text) throw new Error("No text generated for segment.");

    return {
      index: segmentIndex,
      text: text,
      audioUrl: null, // Audio generated separately
      audioBuffer: null // Deprecated
    };

  } catch (error) {
    console.error(`Segment ${segmentIndex} Text Generation Error:`, error);
    throw error; // Re-throw to be caught by buffering engine
  }
};

// MODIFIED: Returns Blob URL instead of AudioBuffer
export const generateSegmentAudio = async (text: string, voiceName: string = 'Kore'): Promise<string> => {
  try {
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash-preview-tts',
      contents: [{ parts: [{ text: text }] }],
      config: {
        responseModalities: [Modality.AUDIO],
        speechConfig: {
          voiceConfig: { prebuiltVoiceConfig: { voiceName: voiceName } }
        }
      }
    });

    const part = response.candidates?.[0]?.content?.parts?.[0];
    const audioData = part?.inlineData?.data;
    if (!audioData) throw new Error("No audio data received from Gemini TTS.");

    const mimeType = part?.inlineData?.mimeType || "audio/pcm;rate=24000";
    const match = mimeType.match(/rate=(\d+)/);
    const sampleRate = match ? parseInt(match[1], 10) : 24000;

    // Convert to WAV Blob
    const wavBlob = pcmToWav(base64ToArrayBuffer(audioData), sampleRate);

    // Create and return Blob URL
    return URL.createObjectURL(wavBlob);

  } catch (error) {
    console.error("Audio Generation Error:", error);
    throw error; // Re-throw to be caught by buffering engine
  }
};