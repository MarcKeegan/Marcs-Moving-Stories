/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

require('dotenv').config();
const express = require('express');
const fs = require('fs');
const axios = require('axios');
const https = require('https');
const path = require('path');
const WebSocket = require('ws');
const { URLSearchParams, URL } = require('url');
const rateLimit = require('express-rate-limit');

// Firebase Admin SDK for token verification
const admin = require('firebase-admin');

// Initialize Firebase Admin
// Option 1: Use GOOGLE_APPLICATION_CREDENTIALS environment variable (path to service account JSON)
// Option 2: Use FIREBASE_SERVICE_ACCOUNT_JSON environment variable (JSON string of service account)
// Option 3: On Google Cloud Run, uses default credentials automatically
let firebaseInitialized = false;
try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        // Parse JSON from environment variable
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            projectId: serviceAccount.project_id
        });
        firebaseInitialized = true;
        console.log('✅ Firebase Admin initialized with service account from env var');
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        // Use path to service account file
        admin.initializeApp({
            credential: admin.credential.applicationDefault()
        });
        firebaseInitialized = true;
        console.log('✅ Firebase Admin initialized with GOOGLE_APPLICATION_CREDENTIALS');
    } else {
        // Try application default credentials (works on Cloud Run)
        admin.initializeApp({
            credential: admin.credential.applicationDefault()
        });
        firebaseInitialized = true;
        console.log('✅ Firebase Admin initialized with application default credentials');
    }
} catch (error) {
    console.warn('⚠️ Firebase Admin SDK initialization failed:', error.message);
    console.warn('⚠️ Token verification will be disabled. Set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS.');
}

const app = express();
const port = process.env.PORT || 3000;
const externalApiBaseUrl = 'https://generativelanguage.googleapis.com';
const externalWsBaseUrl = 'wss://generativelanguage.googleapis.com';
// Prefer a dedicated server-side Gemini key to avoid client-type restrictions collisions (iOS/web).
// Fallback to legacy env var names for backwards compatibility.
const apiKey =
    process.env.GEMINI_SERVER_API_KEY ||
    process.env.GEMINI_API_KEY ||
    process.env.API_KEY;

// Google Directions API Key (used server-side to avoid iOS restrictions)
const googleDirectionsApiKey = process.env.GOOGLE_DIRECTIONS_API_KEY;
const googlePlacesApiKey =
    process.env.GOOGLE_PLACES_API_KEY ||
    process.env.GOOGLE_MAPS_API_KEY ||
    googleDirectionsApiKey;

const staticPath = path.join(__dirname, 'dist');
const publicPath = path.join(__dirname, 'public');


if (!apiKey) {
    // Only log an error, don't exit. The server will serve apps without proxy functionality
    console.error("Warning: GEMINI_API_KEY or API_KEY environment variable is not set! Proxy functionality will be disabled.");
}
else {
    console.log('Gemini API key configured.');
}

// Explicit opt-out of authentication for local development only.
const allowUnauthenticated = process.env.ALLOW_UNAUTHENTICATED === 'true';
if (allowUnauthenticated) {
    console.warn('⚠️ ALLOW_UNAUTHENTICATED=true — proxy requests will NOT require a verified token. Never use in production.');
}

// Comma-separated list of origins allowed to call the proxy cross-origin.
// The web app is served same-origin by this server, so this is normally empty.
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

const applyCorsHeaders = (req, res) => {
    const origin = req.headers.origin;
    if (origin && allowedOrigins.includes(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
    }
};

// Gemini payloads are prompts/config JSON; 1mb is generous.
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.set('trust proxy', 1 /* number of proxies between user and server */)

// Rate limiter for the proxy
const proxyLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // Set ratelimit window at 15min (in ms)
    max: 100, // Limit each IP to 100 requests per window
    message: 'Too many requests from this IP, please try again after 15 minutes',
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // no `X-RateLimit-*` headers
    handler: (req, res, next, options) => {
        console.warn(`Rate limit exceeded for IP: ${req.ip}. Path: ${req.path}`);
        res.status(options.statusCode).send(options.message);
    }
});

// Apply the rate limiter to the /api-proxy route before the main proxy logic
app.use('/api-proxy', proxyLimiter);

// Authentication middleware for proxy endpoints
// Properly verifies Firebase ID tokens when Firebase Admin is initialized
const authenticateProxyRequest = async (req, res, next) => {
    // Skip auth check for OPTIONS (CORS preflight)
    if (req.method === 'OPTIONS') {
        return next();
    }

    // Check for Authorization header (Firebase ID token)
    if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
        console.warn(`❌ Unauthorized access attempt to ${req.path} from IP: ${req.ip}. No/invalid Authorization header.`);
        return res.status(401).json({ error: 'Unauthorized', message: 'Authentication required.' });
    }

    const token = req.headers.authorization.split('Bearer ')[1];

    // If Firebase Admin is initialized, verify the token cryptographically
    if (firebaseInitialized) {
        try {
            const decodedToken = await admin.auth().verifyIdToken(token);
            req.user = decodedToken; // Attach user info to request
            // console.log(`✅ Token verified for user: ${decodedToken.uid}`);
            return next();
        } catch (error) {
            console.warn(`❌ Token verification failed for ${req.path} from IP: ${req.ip}. Error: ${error.message}`);
            return res.status(401).json({
                error: 'Unauthorized',
                message: 'Invalid or expired token.',
                code: error.code
            });
        }
    } else if (allowUnauthenticated) {
        console.warn('⚠️ Firebase Admin not initialized and ALLOW_UNAUTHENTICATED=true - request allowed WITHOUT verification (dev only).');
        return next();
    } else {
        // Fail closed: a misconfigured server must not become an open relay.
        console.error(`❌ Firebase Admin not initialized - rejecting ${req.path} from IP: ${req.ip}. Set ALLOW_UNAUTHENTICATED=true only for local dev.`);
        return res.status(503).json({
            error: 'Service Unavailable',
            message: 'Authentication service is not configured on the server.'
        });
    }
};

// Google Directions API proxy endpoint (server-side API key)
app.get('/api/directions', authenticateProxyRequest, async (req, res) => {
    try {
        if (!googleDirectionsApiKey) {
            console.error('❌ GOOGLE_DIRECTIONS_API_KEY not configured on server');
            return res.status(500).json({
                error: 'Server configuration error',
                message: 'Directions API key not configured'
            });
        }

        const { origin, destination, mode } = req.query;

        if (!origin || !destination) {
            return res.status(400).json({
                error: 'Missing parameters',
                message: 'origin and destination are required'
            });
        }

        const travelMode = mode || 'driving';
        const directionsUrl = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&mode=${encodeURIComponent(travelMode)}&key=${googleDirectionsApiKey}`;

        console.log(`🗺️  Directions API request: ${origin} → ${destination} (${travelMode})`);

        const response = await axios.get(directionsUrl);

        if (response.data.status !== 'OK') {
            console.error(`❌ Directions API error: ${response.data.status}`);
            return res.status(400).json({
                error: 'Directions API error',
                status: response.data.status,
                message: response.data.error_message || 'Failed to get directions'
            });
        }

        console.log('✅ Directions API success');
        res.json(response.data);

    } catch (error) {
        console.error('❌ Directions proxy error:', error.message);
        res.status(500).json({
            error: 'Proxy error',
            message: error.message
        });
    }
});

app.get('/api/nearby-pois', authenticateProxyRequest, async (req, res) => {
    try {
        if (!googlePlacesApiKey) {
            console.error('❌ GOOGLE_PLACES_API_KEY not configured on server');
            return res.status(500).json({
                error: 'Server configuration error',
                message: 'Places API key not configured'
            });
        }

        const { location, radius, keyword, type } = req.query;

        if (!location) {
            return res.status(400).json({
                error: 'Missing parameters',
                message: 'location is required'
            });
        }

        const searchRadius = Math.min(parseInt(radius, 10) || 650, 1500);
        const params = new URLSearchParams({
            location,
            radius: String(searchRadius),
            key: googlePlacesApiKey
        });

        if (keyword) {
            params.set('keyword', String(keyword));
        }
        if (type) {
            params.set('type', String(type));
        }

        const placesUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?${params.toString()}`;
        console.log(`📍 Nearby POI request: ${location} (${searchRadius}m)`);

        const response = await axios.get(placesUrl);
        const status = response.data.status;

        if (!['OK', 'ZERO_RESULTS'].includes(status)) {
            console.error(`❌ Nearby Places API error: ${status}`);
            return res.status(400).json({
                error: 'Places API error',
                status,
                message: response.data.error_message || 'Failed to fetch nearby POIs'
            });
        }

        const places = (response.data.results || []).slice(0, 10).map((place) => ({
            id: place.place_id,
            name: place.name,
            address: place.vicinity || place.formatted_address || '',
            coordinate: {
                latitude: place.geometry?.location?.lat,
                longitude: place.geometry?.location?.lng
            },
            types: place.types || [],
            rating: typeof place.rating === 'number' ? place.rating : null,
            userRatingsTotal: typeof place.user_ratings_total === 'number' ? place.user_ratings_total : null
        }));

        console.log(`✅ Nearby POI success (${places.length} results)`);
        res.json({ status, places });
    } catch (error) {
        console.error('❌ Nearby POI proxy error:', error.message);
        res.status(500).json({
            error: 'Proxy error',
            message: error.message
        });
    }
});

// Proxy route for Gemini API calls (HTTP)
app.use('/api-proxy', authenticateProxyRequest, async (req, res, next) => {
    // If the request is an upgrade request, it's for WebSockets, so pass to next middleware/handler
    if (req.headers.upgrade && req.headers.upgrade.toLowerCase() === 'websocket') {
        return next(); // Pass to the WebSocket upgrade handler
    }

    // Handle OPTIONS request for CORS preflight
    if (req.method === 'OPTIONS') {
        applyCorsHeaders(req, res);
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Goog-Api-Key');
        res.setHeader('Access-Control-Max-Age', '86400'); // Cache preflight response for 1 day
        return res.sendStatus(200);
    }
    applyCorsHeaders(req, res);

    // SECURITY: Don't log request bodies in production (may contain sensitive data)
    if (process.env.NODE_ENV === 'development' && req.body) {
        console.log("  Request Body (sanitized):", JSON.stringify(req.body).substring(0, 200) + '...');
    }
    try {
        // Construct the target URL by taking the part of the path after /api-proxy/
        const targetPath = req.url.startsWith('/') ? req.url.substring(1) : req.url;
        const apiUrl = `${externalApiBaseUrl}/${targetPath}`;

        // SECURITY: Only log path, not full URL (URL may contain query params)
        console.log(`HTTP Proxy: Forwarding ${req.method} to path: ${targetPath.split('?')[0]}`);

        // Prepare headers for the outgoing request
        const outgoingHeaders = {};
        // Copy most headers from the incoming request
        for (const header in req.headers) {
            // Exclude host-specific headers and others that might cause issues upstream
            if (!['host', 'connection', 'content-length', 'transfer-encoding', 'upgrade', 'sec-websocket-key', 'sec-websocket-version', 'sec-websocket-extensions', 'authorization'].includes(header.toLowerCase())) {
                outgoingHeaders[header] = req.headers[header];
            }
        }

        // Set the actual API key in the appropriate header
        outgoingHeaders['X-Goog-Api-Key'] = apiKey;

        // Set Content-Type from original request if present (for relevant methods)
        if (req.headers['content-type'] && ['POST', 'PUT', 'PATCH'].includes(req.method.toUpperCase())) {
            outgoingHeaders['Content-Type'] = req.headers['content-type'];
        } else if (['POST', 'PUT', 'PATCH'].includes(req.method.toUpperCase())) {
            // Default Content-Type to application/json if no content type for post/put/patch
            outgoingHeaders['Content-Type'] = 'application/json';
        }

        // For GET or DELETE requests, ensure Content-Type is NOT sent,
        // even if the client erroneously included it.
        if (['GET', 'DELETE'].includes(req.method.toUpperCase())) {
            delete outgoingHeaders['Content-Type']; // Case-sensitive common practice
            delete outgoingHeaders['content-type']; // Just in case
        }

        // Ensure 'accept' is reasonable if not set
        if (!outgoingHeaders['accept']) {
            outgoingHeaders['accept'] = '*/*';
        }


        const axiosConfig = {
            method: req.method,
            url: apiUrl,
            headers: outgoingHeaders,
            responseType: 'stream',
            validateStatus: function (status) {
                return true; // Accept any status code, we'll pipe it through
            },
        };

        if (['POST', 'PUT', 'PATCH'].includes(req.method.toUpperCase())) {
            axiosConfig.data = req.body;
        }
        // For GET, DELETE, etc., axiosConfig.data will remain undefined,
        // and axios will not send a request body.

        const apiResponse = await axios(axiosConfig);

        // Pass through response headers from Gemini API to the client
        for (const header in apiResponse.headers) {
            res.setHeader(header, apiResponse.headers[header]);
        }
        res.status(apiResponse.status);


        apiResponse.data.on('data', (chunk) => {
            res.write(chunk);
        });

        apiResponse.data.on('end', () => {
            res.end();
        });

        apiResponse.data.on('error', (err) => {
            console.error('Error during streaming data from target API:', err);
            if (!res.headersSent) {
                res.status(500).json({ error: 'Proxy error during streaming from target' });
            } else {
                // If headers already sent, we can't send a JSON error, just end the response.
                res.end();
            }
        });

    } catch (error) {
        console.error('Proxy error before request to target API:', error);
        if (!res.headersSent) {
            if (error.response) {
                const errorData = {
                    status: error.response.status,
                    message: error.response.data?.error?.message || 'Proxy error from upstream API',
                    details: error.response.data?.error?.details || null
                };
                res.status(error.response.status).json(errorData);
            } else {
                res.status(500).json({ error: 'Proxy setup error', message: error.message });
            }
        }
    }
});

const webSocketInterceptorScriptTag = `<script src="/public/websocket-interceptor.js" defer></script>`;

// Prepare service worker registration script content
const serviceWorkerRegistrationScript = `
<script>
if ('serviceWorker' in navigator) {
  window.addEventListener('load' , () => {
    navigator.serviceWorker.register('./service-worker.js')
      .then(registration => {
        console.log('Service Worker registered successfully with scope:', registration.scope);
      })
      .catch(error => {
        console.error('Service Worker registration failed:', error);
      });
  });
} else {
  console.log('Service workers are not supported in this browser.');
}
</script>
`;

// Serve index.html or placeholder based on API key and file availability
app.get('/', (req, res) => {
    const placeholderPath = path.join(publicPath, 'placeholder.html');

    // Try to serve index.html
    console.log("LOG: Route '/' accessed. Attempting to serve index.html.");
    const indexPath = path.join(staticPath, 'index.html');

    fs.readFile(indexPath, 'utf8', (err, indexHtmlData) => {
        if (err) {
            // index.html not found or unreadable, serve the original placeholder
            console.log('LOG: index.html not found or unreadable. Falling back to original placeholder.');
            return res.sendFile(placeholderPath);
        }

        // If API key is not set, serve original HTML without injection
        if (!apiKey) {
            console.log("LOG: API key not set. Serving original index.html without script injections.");
            return res.sendFile(indexPath);
        }

        // index.html found and apiKey set, inject scripts
        console.log("LOG: index.html read successfully. Injecting scripts.");
        let injectedHtml = indexHtmlData;


        const mapsApiKey = process.env.GOOGLE_MAPS_API_KEY || "";
        // Do NOT expose the server-side Gemini API key to the browser.
        // The web app talks to Gemini via /api-proxy (service worker + ws interceptor).
        const geminiApiKey = "";

        const firebaseApiKey = process.env.FIREBASE_API_KEY || process.env.VITE_FIREBASE_API_KEY || "";
        const firebaseAuthDomain = process.env.FIREBASE_AUTH_DOMAIN || process.env.VITE_FIREBASE_AUTH_DOMAIN || "";
        const firebaseProjectId = process.env.FIREBASE_PROJECT_ID || process.env.VITE_FIREBASE_PROJECT_ID || "";
        const firebaseAppId = process.env.FIREBASE_APP_ID || process.env.VITE_FIREBASE_APP_ID || "";

        const clientEnv = {
            GOOGLE_MAPS_API_KEY: mapsApiKey,
            API_KEY: geminiApiKey,
            GEMINI_USE_PROXY: true,
            FIREBASE_API_KEY: firebaseApiKey,
            FIREBASE_AUTH_DOMAIN: firebaseAuthDomain,
            FIREBASE_PROJECT_ID: firebaseProjectId,
            FIREBASE_APP_ID: firebaseAppId
        };
        // JSON-encode and escape '<' so no env value can break out of the inline <script>.
        const envScript = `<script>window.__ENV__ = ${JSON.stringify(clientEnv).replace(/</g, '\\u003c')};</script>`;

        if (injectedHtml.includes('<head>')) {
            // Inject WebSocket interceptor first, then service worker script
            injectedHtml = injectedHtml.replace(
                '<head>',
                `<head>${envScript}${webSocketInterceptorScriptTag}${serviceWorkerRegistrationScript}`
            );
            console.log("LOG: Scripts injected into <head>.");
        } else {
            console.warn("WARNING: <head> tag not found in index.html. Prepending scripts to the beginning of the file as a fallback.");
            injectedHtml = `${envScript}${webSocketInterceptorScriptTag}${serviceWorkerRegistrationScript}${indexHtmlData}`;
        }
        res.send(injectedHtml);
    });
});

app.get('/service-worker.js', (req, res) => {
    return res.sendFile(path.join(publicPath, 'service-worker.js'));
});

app.use('/public', express.static(publicPath));
app.use(express.static(staticPath));

// Start the HTTP server
const server = app.listen(port, () => {
    console.log(`Server listening on port ${port}`);
    console.log(`HTTP proxy active on /api-proxy/**`);
    console.log(`WebSocket proxy active on /api-proxy/**`);
});

// Create WebSocket server and attach it to the HTTP server
const wss = new WebSocket.Server({ noServer: true });

// Browsers cannot set an Authorization header on the WebSocket constructor, so the
// client passes its Firebase ID token as an `access_token` query parameter (appended
// by public/websocket-interceptor.js). It is verified here and stripped before the
// request is forwarded upstream.
const authenticateWsRequest = async (requestUrl) => {
    if (!firebaseInitialized) {
        if (allowUnauthenticated) {
            console.warn('⚠️ WebSocket proxy: Firebase Admin not initialized and ALLOW_UNAUTHENTICATED=true - connection allowed WITHOUT verification (dev only).');
            return { ok: true };
        }
        return { ok: false, status: 503, reason: 'authentication service not configured' };
    }
    const token = requestUrl.searchParams.get('access_token');
    if (!token) {
        return { ok: false, status: 401, reason: 'missing access_token' };
    }
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        return { ok: true, uid: decodedToken.uid };
    } catch (error) {
        return { ok: false, status: 401, reason: `invalid token (${error.code || error.message})` };
    }
};

// Simple per-IP cap on concurrent WebSocket connections (the HTTP rate limiter
// does not cover upgrade requests).
const MAX_WS_CONNECTIONS_PER_IP = 10;
const wsConnectionsPerIp = new Map();

const rejectUpgrade = (socket, status, reason) => {
    const statusText = status === 401 ? 'Unauthorized' : status === 429 ? 'Too Many Requests' : 'Service Unavailable';
    socket.write(`HTTP/1.1 ${status} ${statusText}\r\nConnection: close\r\n\r\n`);
    socket.destroy();
    console.warn(`WebSocket proxy: rejected upgrade (${status} - ${reason}).`);
};

server.on('upgrade', async (request, socket, head) => {
    socket.on('error', () => socket.destroy());
    const requestUrl = new URL(request.url, `http://${request.headers.host}`);
    const pathname = requestUrl.pathname;

    if (pathname.startsWith('/api-proxy/')) {
        if (!apiKey) {
            console.error("WebSocket proxy: API key not configured. Closing connection.");
            socket.destroy();
            return;
        }

        // Behind Cloud Run / a load balancer the real client IP is in X-Forwarded-For.
        const forwardedFor = String(request.headers['x-forwarded-for'] || '').split(',')[0].trim();
        const clientIp = forwardedFor || request.socket.remoteAddress || 'unknown';
        if ((wsConnectionsPerIp.get(clientIp) || 0) >= MAX_WS_CONNECTIONS_PER_IP) {
            return rejectUpgrade(socket, 429, `connection limit reached for ${clientIp}`);
        }

        const authResult = await authenticateWsRequest(requestUrl);
        if (!authResult.ok) {
            return rejectUpgrade(socket, authResult.status, authResult.reason);
        }

        wss.handleUpgrade(request, socket, head, (clientWs) => {
            console.log('Client WebSocket connected to proxy for path:', pathname);
            wsConnectionsPerIp.set(clientIp, (wsConnectionsPerIp.get(clientIp) || 0) + 1);
            clientWs.on('close', () => {
                const remaining = (wsConnectionsPerIp.get(clientIp) || 1) - 1;
                if (remaining <= 0) {
                    wsConnectionsPerIp.delete(clientIp);
                } else {
                    wsConnectionsPerIp.set(clientIp, remaining);
                }
            });

            const targetPathSegment = pathname.substring('/api-proxy'.length);
            const clientQuery = new URLSearchParams(requestUrl.search);
            clientQuery.delete('access_token'); // Never forward the Firebase token upstream.
            clientQuery.set('key', apiKey);
            const targetGeminiWsUrl = `${externalWsBaseUrl}${targetPathSegment}?${clientQuery.toString()}`;
            // Log the path only - the full URL contains the API key.
            console.log(`Attempting to connect to target WebSocket path: ${targetPathSegment}`);

            const geminiWs = new WebSocket(targetGeminiWsUrl, {
                protocol: request.headers['sec-websocket-protocol'],
            });

            const messageQueue = [];

            geminiWs.on('open', () => {
                console.log('Proxy connected to Gemini WebSocket');
                // Send any queued messages
                while (messageQueue.length > 0) {
                    const message = messageQueue.shift();
                    if (geminiWs.readyState === WebSocket.OPEN) {
                        // console.log('Sending queued message from client -> Gemini');
                        geminiWs.send(message);
                    } else {
                        // Should not happen if we are in 'open' event, but good for safety
                        console.warn('Gemini WebSocket not open when trying to send queued message. Re-queuing.');
                        messageQueue.unshift(message); // Add it back to the front
                        break; // Stop processing queue for now
                    }
                }
            });

            geminiWs.on('message', (message) => {
                // console.log('Message from Gemini -> client');
                if (clientWs.readyState === WebSocket.OPEN) {
                    clientWs.send(message);
                }
            });

            geminiWs.on('close', (code, reason) => {
                console.log(`Gemini WebSocket closed: ${code} ${reason.toString()}`);
                if (clientWs.readyState === WebSocket.OPEN || clientWs.readyState === WebSocket.CONNECTING) {
                    clientWs.close(code, reason.toString());
                }
            });

            geminiWs.on('error', (error) => {
                console.error('Error on Gemini WebSocket connection:', error);
                if (clientWs.readyState === WebSocket.OPEN || clientWs.readyState === WebSocket.CONNECTING) {
                    clientWs.close(1011, 'Upstream WebSocket error');
                }
            });

            clientWs.on('message', (message) => {
                if (geminiWs.readyState === WebSocket.OPEN) {
                    // console.log('Message from client -> Gemini');
                    geminiWs.send(message);
                } else if (geminiWs.readyState === WebSocket.CONNECTING) {
                    // console.log('Queueing message from client -> Gemini (Gemini still connecting)');
                    messageQueue.push(message);
                } else {
                    console.warn('Client sent message but Gemini WebSocket is not open or connecting. Message dropped.');
                }
            });

            clientWs.on('close', (code, reason) => {
                console.log(`Client WebSocket closed: ${code} ${reason.toString()}`);
                if (geminiWs.readyState === WebSocket.OPEN || geminiWs.readyState === WebSocket.CONNECTING) {
                    geminiWs.close(code, reason.toString());
                }
            });

            clientWs.on('error', (error) => {
                console.error('Error on client WebSocket connection:', error);
                if (geminiWs.readyState === WebSocket.OPEN || geminiWs.readyState === WebSocket.CONNECTING) {
                    geminiWs.close(1011, 'Client WebSocket error');
                }
            });
        });
    } else {
        console.log(`WebSocket upgrade request for non-proxy path: ${pathname}. Closing connection.`);
        socket.destroy();
    }
});
