import { beforeAll, describe, expect, it, vi } from 'vitest';

// geminiService has import-time side effects (fetch interceptor, SDK client,
// Firebase auth). Stub them so the pure logic is testable in isolation.
vi.mock('../firebase', () => ({ auth: { currentUser: null } }));
vi.mock('@google/genai', () => ({
  GoogleGenAI: class {
    models = {};
  },
  Modality: { AUDIO: 'AUDIO' },
}));

beforeAll(() => {
  vi.stubGlobal('window', {
    __ENV__: undefined,
    fetch: vi.fn(),
    atob: globalThis.atob,
  });
});

describe('calculateTotalSegments', () => {
  it('sizes the story to ~60s segments, rounding up', async () => {
    const { calculateTotalSegments } = await import('../services/geminiService');
    expect(calculateTotalSegments(60)).toBe(1);
    expect(calculateTotalSegments(61)).toBe(2);
    expect(calculateTotalSegments(600)).toBe(10);
    expect(calculateTotalSegments(3600)).toBe(60);
  });

  it('never returns fewer than one segment', async () => {
    const { calculateTotalSegments } = await import('../services/geminiService');
    expect(calculateTotalSegments(0)).toBe(1);
    expect(calculateTotalSegments(5)).toBe(1);
  });
});
