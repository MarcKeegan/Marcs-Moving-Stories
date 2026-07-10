# Marc's Moving Stories — Application Assessment

_Assessment date: July 2026. Covers the web app (React 19 + Vite + TypeScript), the Node/Express proxy server (`server/`), deployment (Dockerfile / Cloud Run), and — at a review level — the native SwiftUI iOS app (`ios/`)._

---

## 1. What the app is

Marc's Moving Stories (a.k.a. "echopaths" / "StoryMode" / "StoryMaps") turns a real navigation route into a continuously generated, duration-synced AI audio story:

1. The user signs in with Firebase Auth (email/password or Google).
2. They plan a route with Google Places Autocomplete + Directions (walking or driving, journeys up to 4 hours), and pick a story style (Noir, Children's, Historical, Fantasy, Historian's Guide).
3. Gemini 2.0 Flash generates a chapter outline sized to the journey duration, then writes each segment; Gemini 2.5 Flash TTS narrates it. A buffering engine keeps ~3 segments ahead of playback.
4. A sticky player advances audio segments automatically while an inline map walks a progress marker along the route.

**Architecture:**

- **Frontend** — single-page React app, no router; screens are switched off an `AppState` enum and auth state in `App.tsx`. State is all local `useState`/`useRef`; auth lives in a small Context.
- **Proxy server** (`server/server.js`) — Express app for Cloud Run that serves the built frontend and proxies Gemini (HTTP + WebSocket), Google Directions, and Google Places, injecting the server-held API key so it never ships to the browser. Firebase ID tokens gate the HTTP proxy. In the browser, a global `fetch` interceptor, a service worker, and a `WebSocket` constructor proxy transparently reroute the Gemini SDK to `/api-proxy`.
- **iOS** — a fully separate native SwiftUI app that re-implements the client against the same proxy contract (`/api-proxy/...`, `/api/directions`, `/api/nearby-pois`). No shared code with the web app.

The proxy-based key handling, the segment-buffering design, and the duration-synced outline are genuinely good ideas and the core product works. The issues below are about hardening, efficiency, and maintainability.

---

## 2. Security findings

### P0 — Act immediately

| # | Finding | Location |
|---|---------|----------|
| S1 | **Leaked Google API key in git history.** A live shared Maps/Places/Directions key (`AIzaSy…rZ7VI`) was committed in plaintext in iOS troubleshooting docs and `ios/test_api_key.sh` across many commits (e.g. `5a744ac`, `8a92854`, `e10e189`, `999cc99`). Commit `9086364` scrubbed the working tree, but the key remains recoverable from history by anyone with repo access. | git history |
| S2 | **WebSocket proxy is unauthenticated.** The HTTP `/api-proxy` route verifies Firebase ID tokens, but the WebSocket `upgrade` handler only checks the URL path before proxying to Gemini with the server's API key — an open relay for anyone who can reach the server, with no rate limiting. | `server/server.js` upgrade handler |
| S3 | **Auth fails open.** If Firebase Admin fails to initialize (missing service account), the proxy logs "Request allowed but NOT SECURE" and lets every request through. | `server/server.js` `authenticateProxyRequest` |
| S4 | **Gemini API key injected into the client bundle.** `vite.config.ts` `define`s `GEMINI_API_KEY`/`API_KEY` as literals in the built JS. Deployed builds use the proxy (key is blank), but any build with a real key in `.env` embeds an extractable secret. | `vite.config.ts` |
| S5 | **`.env` tracked in git** despite `.gitignore` listing it (force-added in `a038bee`). Values are placeholders today, but the next person to fill in real keys will commit them. | `.env` |

**Required owner actions (cannot be fixed in code):**

1. **Rotate the leaked key `AIzaSy…rZ7VI` now** in Google Cloud Console, and restrict its replacement by API (Maps/Places/Directions only) and by referrer (web) / bundle ID (iOS). Treat every key that has ever appeared in a committed file as burned.
2. Consider a **history rewrite** (`git filter-repo` / BFG) to purge the key from old commits if the repo is or ever becomes public/shared. This rewrites commit hashes and requires force-pushing and re-cloning — a deliberate decision, not done in this pass.
3. Verify the **Google Maps browser key** (necessarily public in the client) is HTTP-referrer-restricted; the AI Studio export comment suggested an unrestricted key.

### P1 — Hardening gaps

- **CORS `Access-Control-Allow-Origin: *`** on the proxy.
- **50 MB body limit** on Express JSON/urlencoded parsing — a DoS amplification vector.
- **Unescaped env interpolation** into the inline `window.__ENV__` `<script>` the server injects into `index.html` — an env value containing `</script>` or quotes would break out of the script context.
- **Key fragment logged at startup** (first 5 + last 4 chars).
- `validateStatus: () => true` pipes upstream Google error bodies straight to clients.
- **Prompt injection surface**: user-controlled addresses are string-interpolated into Gemini prompts unsanitized. Blast radius is low (output is narration text played back to the same user), so this is noted rather than fixed.

### What was already done well

- Firebase ID-token verification on HTTP proxy routes; upstream `Authorization` header stripped before forwarding to Google.
- Rate limiting (100 req/15 min/IP) on the HTTP proxy.
- Server Gemini key deliberately blanked in the injected client config.
- iOS secrets (`Secrets.plist`, `GoogleService-Info.plist`) gitignored with `.example` templates; no `eval`/`exec`/shell in the server.
- Story text rendered as text, not HTML — no XSS via model output.

---

## 3. Performance findings

| # | Finding | Impact |
|---|---------|--------|
| P1 | **CDN import map defeats the build.** `index.html` maps `react`, `react-dom`, `@google/genai`, and `lucide-react` to `aistudiocdn.com` — so Vite's bundling, tree-shaking, and version pinning do nothing, `lucide-react` loads in full, and a duplicate-React hazard exists. (AI Studio export artifact.) | Large, uncacheable-together payload; fragile |
| P2 | **`cdn.tailwindcss.com` in production** — the in-browser JIT dev build: ~300 KB script, runtime style generation, FOUC, explicitly not for production. | Slow first paint |
| P3 | **3 billed Directions requests per journey** — RoutePlanner computes the route, then InlineMap and MapBackground each recompute the identical route. | 3× API cost + latency |
| P4 | **Blob URL memory leak** — every TTS segment creates an object URL that is never revoked; long journeys and repeated "new journey" resets accumulate audio buffers for the session's lifetime. | Growing memory use |
| P5 | **Fully serialized generation** — outline → segment text → segment audio, one segment at a time, so time-to-first-audio is the sum of three round-trips, and a fresh render-created `onSegmentChange` prop re-runs a player effect on every parent render. | Slow start, wasted renders |
| P6 | **Triple analytics** — GTM + gtag + Firebase Analytics all load. | Extra ~100 KB+ and duplicate events |
| P7 | **Docker image** — full `node:22` runtime (~1 GB) running as root, `COPY . .` with no `.dockerignore` (ships `.git`, `ios/`, docs into the build context), unpinned `npm install` with no `server/` lockfile. | Slow deploys, larger attack surface, unreproducible builds |

---

## 4. Code quality findings

- **Monolithic `App.tsx` (573 lines)** mixing the auth form (~140 lines), Google Maps script bootstrap, story-generation orchestration, and the buffering engine in one component.
- **Duplication**: the ~90-line Google Maps style JSON is copy-pasted in `InlineMap.tsx` and `MapBackground.tsx`; three separate "wait for `window.google`" bootstraps exist.
- **Loose TypeScript**: `tsconfig.json` has no `strict`, and the build never typechecks (`vite build` only). Consequence: pervasive `any` (Maps callbacks, refs, `window.google`, `catch (e: any)`), unnoticed dead code.
- **Dead code**: `AppState.CALCULATING_ROUTE`/`ROUTE_CONFIRMED`/`PLAYING` are never set (RoutePlanner's "locked" styling gates on a state that can't occur); a deprecated `audioBuffer` field survives in types and service returns; `index.css` is empty but linked; `animate-fade-in` is used in four places but no `fade-in` keyframes are defined anywhere, so the animation silently does nothing.
- **Controlled/uncontrolled input hybrid**: RoutePlanner mutates `input.value` directly alongside React state for the same fields.
- **Silent failure modes**: a background segment-generation failure is only `console.error`'d, leaving the player stuck on "Buffering stream…" forever; audio errors skip to the next segment silently; Directions non-`OK` statuses are ignored in two components; no React error boundary anywhere, so one throw white-screens the app; `getAnalytics` is called without an `isSupported()` guard.
- **Global monkeypatching**: `window.fetch` is replaced at module import time to inject Firebase tokens. It's load-bearing for the proxy architecture (kept, but scoped and documented in this pass) — a future refactor could use the SDK's custom-fetch/baseUrl options instead.
- **Accessibility**: form inputs have placeholders but no associated `<label>`s; icon-only buttons (play/pause, auto-scroll) lack `aria-label`s; live status is conveyed by color alone.

---

## 5. Testing & infrastructure

There were **no tests, no linting, no formatting config, no CI, and no typechecking** in the repository. Nothing prevents a regression in the WAV encoder, the prompt builders, or the server auth path from shipping.

Added in this pass: strict TypeScript + `typecheck` script, ESLint (flat config with typescript-eslint + react-hooks), Vitest unit tests (PCM→WAV encoding, prompt construction, server HTTP/WS auth rejection), and a GitHub Actions workflow running typecheck → lint → test → build.

---

## 6. Repository hygiene

- `.DS_Store` tracked in 5 locations (gitignored but force-added at some point).
- 17 internal troubleshooting markdown docs under `ios/` (several containing fragments of the leaked key), a stray empty `Untitled.swift`, and `ios/test_api_key.sh`.
- ~10 MB of Google Sans `.ttf` fonts tracked in `ios/` — verified as genuinely used by the iOS app (registered in `Info.plist` and `FontExtensions.swift`), so they were kept; consider Git LFS if the repo grows.
- A built frontend bundle was committed historically (since removed).
- No `server/package-lock.json`, so server deps were unpinned at deploy time.

---

## 7. Feature recommendations (not implemented — product decisions)

Ordered roughly by value-to-effort:

1. **POI-aware stories** — ✅ **implemented for the web client in this pass** (see §8). The server already exposed `/api/nearby-pois` (Places Nearby Search) and the iOS app used it, but the web client didn't. Real landmarks along the route are now sampled and woven into each story segment. The iOS app could adopt the same segment-assignment logic server-side.
2. **Story history / library** — Firestore is already integrated (commit `5a744ac`); persist finished stories (outline, text, style, route) per user and let them replay. Audio could be regenerated on demand rather than stored.
3. **Resume an interrupted journey** — persist playback position + generated segments so closing the tab mid-drive doesn't lose the story.
4. **Voice & style preview** — a 5-second sample per voice/style on the planner screen; cheap to build (one cached TTS call per option), big UX payoff for a first-time user.
5. **Segment regeneration** — "didn't like that chapter" → regenerate one segment with a steer ("less dialogue", "more history"), reusing the existing per-segment pipeline.
6. **Downloadable / offline stories** — export concatenated WAV (the encoder exists in `audioUtils.ts`) or pre-generate the whole story before departure for connectivity-poor routes. Natural companion to (2).
7. **Sharing** — a read-only share link for a finished story (text + map thumbnail), leaning on the Firestore history from (2).
8. **Multi-language stories & narration** — Gemini TTS is multilingual; add a language picker threaded through the prompt and TTS voice selection.
9. **Live position sync** — instead of a timer walking the route marker, use watchPosition during real journeys so narration pace can adapt to actual progress (walking faster/slower, traffic).

**iOS**: the Swift app duplicates all story/prompt logic (`StoryService.swift`). Consider moving prompt construction server-side (e.g. a `/api/story/outline` endpoint) so both clients share one implementation — this would also eliminate the client-side prompt surface entirely.

---

## 8. What this improvement pass changed

- **Security**: WebSocket proxy now requires a verified Firebase ID token and is rate-limited; auth fails closed (503) when Firebase Admin is uninitialized, with an explicit `ALLOW_UNAUTHENTICATED=true` dev escape hatch; CORS restricted to `ALLOWED_ORIGINS`; body limit 50 MB → 1 MB; `window.__ENV__` injection JSON-escaped; key-fragment logging removed; `.env` untracked and replaced with `.env.example`; Gemini keys no longer `define`d into the client bundle.
- **Build/perf**: CDN import map removed (Vite now bundles everything); Tailwind moved to a build-time dependency with the theme in CSS (missing `fade-in` animation now actually defined); blob URLs revoked on reset/replacement; one Directions call per journey shared across all three map consumers; first-segment text+audio pipeline tightened; callbacks memoized; Docker runtime on `node:22-slim` as non-root with `.dockerignore` and `npm ci` against a committed server lockfile.
- **Code quality**: `App.tsx` split (AuthScreen component, `useGoogleMaps` and `useStoryEngine` hooks); shared `mapStyles.ts`; `strict` TypeScript with `@types/google.maps` and `any`s eliminated; dead states/fields removed; generation and playback errors surfaced to the user; top-level error boundary; a11y labels on inputs and icon buttons.
- **Infra**: ESLint, Vitest suite, GitHub Actions CI, typecheck in the build.
- **Feature — POI-aware stories (web)**: the route polyline is sampled at up to 8 points (capped Places usage), real nearby landmarks are fetched through the existing `/api/nearby-pois` proxy, scored (landmark-ish types and popularity first, generic businesses excluded), deduplicated, and assigned ~2 per story segment. The outline prompt anchors chapters to them and each segment prompt receives the places the traveler is actually passing; the Historian Guide style is instructed to treat them factually. Fully best-effort: any lookup failure or timeout (6 s cap) falls back to the previous behavior.
- **Hygiene**: the 11 one-off iOS debugging docs (including those with key fragments), `test_api_key.sh`, the empty `Untitled.swift`, and all `.DS_Store` files removed from tracking; durable docs (README, SETUP, ARCHITECTURE, DEPENDENCIES, release checklists) kept.

---

# Part 2 — iOS App Assessment (StoryMaps, SwiftUI)

_Assessed after the web pass. The iOS app (`ios/StoryMapsIOS/StoryMaps/`) is a fully separate native codebase sharing only the server proxy contract with the web client. Changes in this pass were made without Xcode available, so **verify with a local build** — see the checklist at the end._

## Strengths

Solid MVVM layering (Views → ObservableObject view models → services), modern async/await throughout, correct `@MainActor` usage, typed error enums per layer, working background-audio configuration, FCM push wired end-to-end, secrets correctly externalized to a gitignored `Secrets.plist`, and a genuinely novel free-roam mode (live GPS + POI-aware contextual narration with off-route detection and rerouting) that the web app doesn't have.

## What this pass fixed

- **Audio robustness** (`AudioPlayerViewModel.swift`): there was no `AVAudioSession` interruption handling — a phone call paused playback permanently — and no route-change handling, so unplugging headphones switched output to the loudspeaker mid-story. Both are now handled (pause on interruption, resume on `.shouldResume`, pause on device-unavailable). Lock-screen Now Playing previously hard-coded elapsed time to 0; it now tracks real position and play/pause state, and lock-screen scrubbing works (`changePlaybackPositionCommand`). Remote-command targets and observers are cleaned up in `deinit`.
- **Retry logic that never retried** (`GeminiProxyClient.swift`): the "5 attempts" loops rethrew unconditionally on the first error, and overload detection string-matched `localizedDescription` for "503". Rewritten: one shared generation path with an empty-STOP retry, plus typed transient-error detection (`HTTPError.statusCode` 500/503/429, timeout/connection-lost URLErrors) with exponential backoff. The duplicated text/audio retry loops are collapsed into one helper.
- **Client fails closed** (`HTTPClient.swift`): requests without a signed-in user (or with a failed token fetch) previously went out unauthenticated and bounced off the server; they now short-circuit with a "Please sign in" error, and 401/429/503 map to friendly messages instead of "HTTP error: 401".
- **Crash risk**: the Google polyline decoder force-unwrapped `asciiValue!` — malformed route data crashed the app. Rewritten to decode bytes safely and degrade to the valid prefix.
- **Sensitive logging**: the full FCM token (`AppDelegate`), API-key prefixes (`StoryMapsIOSApp`), and full auth/error response bodies (`HTTPClient`) were `print()`ed. Replaced with an `os.Logger`-based `Log` utility (redacts non-literal values in release builds); noisy notification-payload logging removed.
- **Feature parity — POI-grounded planned stories**: iOS only used `/api/nearby-pois` in free-roam mode; planned-route stories were not landmark-grounded. New `RoutePoiService.swift` (a direct Swift port of the web's `services/poiService.ts`: ≤8 polyline sample points, walking 400 m / driving 1200 m radius, notable-type scoring, dedupe, ~2 landmarks per segment, 6 s overall timeout, best-effort) now feeds `generateOutline`/`generateSegment` via the same prompt blocks the web uses. Segment-count math also aligned with the web (ceiling instead of floor division — iOS was generating fewer segments for identical routes).
- **Dead code/config**: the no-op rate limiter (`rateLimitDelay = 0.0`) removed from `StoryViewModel`; unused `GOOGLE_DIRECTIONS_API_KEY` removed from `AppConfig`/`Secrets.plist.example`/docs; stale doc index entries for the deleted troubleshooting files cleaned up.
- **Store readiness**: privacy manifest now declares the AdMob-related Device ID / Advertising Data collection (ads are live in the app; the manifest previously only covered location/email); ATS added to `Info.plist` (`NSAllowsArbitraryLoads=NO`); the app icon converted from a single JPEG to a flattened 1024×1024 PNG with the asset catalog updated; the typo'd duplicate location-usage string in `project.pbxproj` reconciled with `Info.plist`.

## Known issues left as recommendations (not coded blind)

1. **Free-roam background gap**: `Info.plist` promises background audio narration with location, but only When-In-Use authorization is ever requested and background location updates aren't enabled — free-roam narration stalls when the screen locks. Fixing this needs a product decision (Always-authorization prompts App Store scrutiny).
2. **`StoryViewModel` god object** (~470 lines): generation, buffering, live location, POI refresh, and rerouting in one class. Split a `LiveJourneyEngine` out of it.
3. **No tests**: `StoryMapsTests`/`StoryMapsUITests` targets exist but are empty, and singleton coupling (`*.shared` everywhere) blocks unit testing. Introduce protocol-based injection for `StoryService`/`GeminiProxyClient`/clients, then test the retry logic, polyline decoder, and `RoutePoiService` assignment (the web twin of that logic is tested in `tests/poiService.test.ts`).
4. **Prompt drift between platforms**: iOS uses `gemini-2.5-flash`, web uses `gemini-2.0-flash`; the style taxonomies differ entirely (6 iOS styles vs 5 web styles, different names and voice direction). Consider moving prompt construction server-side (e.g. `/api/story/outline`) so both clients share one implementation.
5. **Modernization**: Swift 5 language mode with `ObservableObject`/`@Published` despite the iOS 26 deployment target — `@Observable` migration and Swift 6 strict concurrency are natural upgrades. `UIScreen.main.bounds` in `StoryPlayerView` should become `GeometryReader`.
6. **Missing platform features**: no CarPlay (high value for a driving-story app), no story history (Firestore only stores profiles), dark/tinted app-icon variants still empty, very large SwiftUI `body` properties (~320 lines in `StoryPlayerView`).
7. **View-model/UIKit coupling**: `AuthViewModel` reaches into `UIApplication.shared.connectedScenes` for the Google Sign-In presenter; pass the presenting controller in from the view layer instead.

## Build-and-test checklist (run locally in Xcode)

1. Clean build (⇧⌘K, then ⌘B) — the new files (`Log.swift`, `RoutePoiService.swift`) are picked up automatically via the filesystem-synchronized group.
2. Planned route: create a story and confirm the narration references real places along the route ("Scouting landmarks on your route..." appears briefly during generation).
3. During playback: receive a phone call → narration pauses and resumes after the call; unplug headphones → playback pauses.
4. Lock screen: elapsed time advances, scrubbing works, play/pause state is correct.
5. Signed out (guest mode): attempting to create a story shows "Please sign in to continue." immediately, with no network round-trip.
6. Free-roam mode: unchanged behavior (live context, POI refresh, rerouting).
7. Archive → validate: the privacy manifest and PNG app icon should pass App Store validation checks that the JPEG/missing-AdMob-declaration setup risked failing.
