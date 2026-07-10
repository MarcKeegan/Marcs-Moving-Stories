import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { spawn, type ChildProcess } from 'node:child_process';
import { connect } from 'node:net';
import path from 'node:path';

/**
 * Black-box tests of the proxy server's auth posture: it must reject
 * unauthenticated HTTP and WebSocket traffic rather than relay it to Gemini.
 *
 * Depending on the environment, Firebase Admin either initializes with
 * application-default credentials (tokenless requests -> 401) or fails to
 * initialize (fail-closed -> 503/401). Both are rejections; 2xx never is.
 */

const PORT = 39131;
let server: ChildProcess;

const startServer = () =>
  new Promise<void>((resolve, reject) => {
    server = spawn('node', ['server.js'], {
      cwd: path.resolve(__dirname, '../server'),
      env: {
        ...process.env,
        PORT: String(PORT),
        GEMINI_SERVER_API_KEY: 'test-key-not-real',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const timer = setTimeout(() => reject(new Error('server did not start')), 10000);
    server.stdout?.on('data', (chunk: Buffer) => {
      if (chunk.toString().includes('Server listening')) {
        clearTimeout(timer);
        resolve();
      }
    });
    server.on('exit', (code) => reject(new Error(`server exited early (${code})`)));
  });

beforeAll(async () => {
  await startServer();
});

afterAll(() => {
  server?.kill();
});

describe('HTTP proxy authentication', () => {
  it('rejects requests without a token', async () => {
    const res = await fetch(`http://127.0.0.1:${PORT}/api-proxy/v1beta/models/gemini-2.0-flash:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    });
    expect(res.status).toBe(401);
  });

  it('rejects requests with a garbage bearer token', async () => {
    const res = await fetch(`http://127.0.0.1:${PORT}/api-proxy/v1beta/models/x:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer garbage' },
      body: '{}',
    });
    expect([401, 503]).toContain(res.status);
  });
});

describe('WebSocket proxy authentication', () => {
  it('rejects upgrade requests without an access_token', async () => {
    const statusLine = await new Promise<string>((resolve, reject) => {
      const socket = connect(PORT, '127.0.0.1', () => {
        socket.write(
          'GET /api-proxy/v1beta/live HTTP/1.1\r\n' +
          `Host: 127.0.0.1:${PORT}\r\n` +
          'Connection: Upgrade\r\n' +
          'Upgrade: websocket\r\n' +
          'Sec-WebSocket-Version: 13\r\n' +
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n' +
          '\r\n'
        );
      });
      socket.setTimeout(8000, () => reject(new Error('timeout')));
      socket.once('data', (data) => {
        resolve(data.toString().split('\r\n')[0]);
        socket.destroy();
      });
      socket.on('error', reject);
    });

    // 101 Switching Protocols would mean the relay is open to anyone.
    expect(statusLine).toMatch(/^HTTP\/1\.1 (401|503) /);
  });
});
