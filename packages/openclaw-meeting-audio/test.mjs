import test from 'node:test';
import assert from 'node:assert/strict';
import { meetingUrl, Listener } from './index.mjs';
import { installCapture } from './capture.mjs';

test('Teams URL validation accepts numeric links and rejects foreign destinations', () => {
  assert.equal(meetingUrl('https://teams.microsoft.com/meet/123456?p=test'), 'https://teams.microsoft.com/meet/123456?p=test');
  for (const url of ['http://teams.microsoft.com/meet/123', 'https://teams.microsoft.com.evil.test/meet/123',
    'https://user@teams.microsoft.com/meet/123', 'https://teams.microsoft.com:444/meet/123',
    'file:///etc/passwd', 'https://teams.microsoft.com/settings']) assert.throws(() => meetingUrl(url));
});

test('start waits for an actual call without launching Whisper', async () => {
  const listener = new Listener(); listener.phase = 'opened';
  listener.cdp = { evaluate: async () => ({ inCall: false }) };
  const result = await listener.start();
  assert.ok(result.manualAction); assert.equal(listener.worker, undefined);
});

test('backpressure stops capture instead of allowing unbounded audio', async () => {
  const listener = new Listener(); listener.phase = 'listening';
  listener.queue = Array(4).fill(Buffer.alloc(2)); listener.bytes = 2;
  listener.chunks = [Buffer.alloc(2)];
  listener.flush();
  assert.equal(listener.phase, 'failed'); assert.equal(listener.queue.length, 0);
});

test('capture hooks receiver tracks, never acquires a microphone or creates senders', async () => {
  const peers = [];
  class Peer {
    constructor() { peers.push(this); }
    addEventListener(name, callback) { assert.equal(name, 'track'); this.callback = callback; }
  }
  const sources = []; const processed = []; let audioProcessor;
  globalThis.window = { RTCPeerConnection: Peer, __localMeetingPcm: data => processed.push(data) };
  globalThis.document = { querySelector: () => ({}) };
  globalThis.MediaStream = class { constructor(tracks) { this.tracks = tracks; } };
  globalThis.AudioContext = class {
    sampleRate = 16000; state = 'running'; destination = {};
    createMediaStreamSource(stream) { sources.push(stream); return { connect() {}, disconnect() {} }; }
    createScriptProcessor() { audioProcessor = { connect() {}, disconnect() {} }; return audioProcessor; }
    createGain() { return { gain: {}, connect() {}, disconnect() {} }; }
    async resume() {} async close() {}
  };
  try {
    installCapture(); new window.RTCPeerConnection();
    peers[0].callback({ track: { id: 'remote-audio', kind: 'audio', readyState: 'live' } });
    peers[0].callback({ track: { id: 'remote-video', kind: 'video', readyState: 'live' } });
    await window.__localMeetingCapture.start();
    assert.equal(sources.length, 1); assert.equal(sources[0].tracks[0].id, 'remote-audio');
    audioProcessor.onaudioprocess({ inputBuffer: { getChannelData: () => new Float32Array([0, 1, -1]) } });
    const samples = Buffer.from(processed[0], 'base64');
    assert.equal(samples.readInt16LE(2), 32767); assert.equal(samples.readInt16LE(4), -32767);
    await window.__localMeetingCapture.stop(); assert.equal(audioProcessor.onaudioprocess, null);
  } finally {
    for (const key of ['window', 'document', 'MediaStream', 'AudioContext']) delete globalThis[key];
  }
});
