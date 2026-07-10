import { beforeAll, describe, expect, it, vi } from 'vitest';

beforeAll(() => {
  // audioUtils uses window.atob; provide it in the node test environment.
  vi.stubGlobal('window', { atob: globalThis.atob });
});

describe('base64ToArrayBuffer', () => {
  it('round-trips binary data', async () => {
    const { base64ToArrayBuffer } = await import('../services/audioUtils');
    const original = new Uint8Array([0, 1, 2, 127, 128, 255]);
    const base64 = Buffer.from(original).toString('base64');
    const result = new Uint8Array(base64ToArrayBuffer(base64));
    expect(Array.from(result)).toEqual(Array.from(original));
  });
});

describe('pcmToWav', () => {
  const readWav = async (pcm: Int16Array, sampleRate: number) => {
    const { pcmToWav } = await import('../services/audioUtils');
    const blob = pcmToWav(pcm.buffer, sampleRate);
    const view = new DataView(await blob.arrayBuffer());
    return { blob, view };
  };

  it('produces a valid RIFF/WAVE header', async () => {
    const pcm = new Int16Array([0, 1000, -1000, 32767, -32768]);
    const { blob, view } = await readWav(pcm, 24000);

    expect(blob.type).toBe('audio/wav');
    const ascii = (offset: number, len: number) =>
      String.fromCharCode(...new Uint8Array(view.buffer, offset, len));

    expect(ascii(0, 4)).toBe('RIFF');
    expect(ascii(8, 4)).toBe('WAVE');
    expect(ascii(12, 4)).toBe('fmt ');
    expect(ascii(36, 4)).toBe('data');

    expect(view.getUint32(4, true)).toBe(blob.size - 8); // RIFF chunk size
    expect(view.getUint16(20, true)).toBe(1); // PCM format
    expect(view.getUint16(22, true)).toBe(1); // mono
    expect(view.getUint32(24, true)).toBe(24000); // sample rate
    expect(view.getUint32(28, true)).toBe(24000 * 2); // byte rate
    expect(view.getUint16(34, true)).toBe(16); // bits per sample
    expect(view.getUint32(40, true)).toBe(pcm.length * 2); // data size
  });

  it('preserves the PCM samples verbatim', async () => {
    const pcm = new Int16Array([12, -34, 5678, -9012]);
    const { view } = await readWav(pcm, 16000);

    for (let i = 0; i < pcm.length; i++) {
      expect(view.getInt16(44 + i * 2, true)).toBe(pcm[i]);
    }
  });
});
