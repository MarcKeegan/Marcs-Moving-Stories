# Stage 1: Build the frontend, and install server dependencies
FROM node:22-slim AS builder

WORKDIR /app

# Install dependencies first so they cache independently of source changes
COPY package.json package-lock.json ./
RUN npm ci

COPY server/package.json server/package-lock.json ./server/
RUN cd server && npm ci --omit=dev

# Copy the rest of the source (see .dockerignore for exclusions)
COPY . ./

# Build the frontend. Keys are provided at runtime via the server's
# window.__ENV__ injection, never baked into the bundle.
RUN npm run build


# Stage 2: Final server image
FROM node:22-slim

ENV NODE_ENV=production
WORKDIR /app

COPY --from=builder /app/server .
# Built frontend assets, served by the proxy server
COPY --from=builder /app/dist ./dist

EXPOSE 3000

USER node

CMD ["node", "server.js"]
