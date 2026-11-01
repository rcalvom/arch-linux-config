import { mkdir, appendFile, readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { randomUUID } from 'node:crypto';
import { installCapture } from './capture.mjs';

const endpoint = 'http://127.0.0.1:18800';
const allowedHosts = new Set(['teams.microsoft.com', 'teams.live.com']);
const stateRoot = join(homedir(), '.local/share/openclaw-meeting-audio');

export function meetingUrl(value) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.port || url.username || url.password ||
      !allowedHosts.has(url.hostname) ||
      !(/^\/meet\/[a-z0-9_-]+\/?$/i.test(url.pathname) ||
        /^\/l\/meetup-join\/[^/]+(?:\/0)?\/?$/i.test(url.pathname))) {
    throw new Error('A supported HTTPS Teams meeting link is required');
  }
  return url.href;
}

export class Cdp {
  constructor(ws) {
    this.ws = ws; this.next = 0; this.pending = new Map(); this.onBinding = () => {};
    ws.addEventListener('message', ({ data }) => {
      const msg = JSON.parse(data);
      if (msg.method === 'Runtime.bindingCalled') this.onBinding(msg.params);
      const pending = this.pending.get(msg.id);
      if (!pending) return;
      this.pending.delete(msg.id); clearTimeout(pending.timer);
      if (msg.error) pending.reject(new Error('Browser command failed'));
      else pending.resolve(msg.result);
    });
    ws.addEventListener('close', () => {
      for (const p of this.pending.values()) {
        clearTimeout(p.timer); p.reject(new Error('Meeting tab disconnected'));
      }
      this.pending.clear();
    });
  }
  static async connect(address) {
    const url = new URL(address);
    if (url.hostname !== '127.0.0.1' || url.port !== '18800' || url.protocol !== 'ws:') {
      throw new Error('Unexpected browser control endpoint');
    }
    const ws = new WebSocket(address);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { ws.close(); reject(new Error('Browser connection timed out')); }, 10000);
      ws.addEventListener('open', () => { clearTimeout(timer); resolve(); }, { once: true });
      ws.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Browser unavailable')); }, { once: true });
    });
    return new Cdp(ws);
  }
  call(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.next;
      const timer = setTimeout(() => {
        this.pending.delete(id); reject(new Error('Browser command timed out'));
      }, 10000);
      this.pending.set(id, { resolve, reject, timer });
      try { this.ws.send(JSON.stringify({ id, method, params })); }
      catch { clearTimeout(timer); this.pending.delete(id); reject(new Error('Browser disconnected')); }
    });
  }
  async evaluate(expression) {
    const result = await this.call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true, userGesture: true });
    if (result.exceptionDetails) throw new Error('Meeting page evaluation failed');
    return result.result?.value;
  }
}

export class Listener {
  constructor() { this.phase = 'idle'; this.totalBytes = 0; this.lines = 0; this.queue = []; this.chunks = []; this.bytes = 0; }
  summary() {
    return { phase: this.phase, sessionId: this.id, audioSeconds: Math.round(this.totalBytes / 32000),
      transcriptSegments: this.lines, queuedChunks: this.queue.length, error: this.error,
      mode: 'local-whisper-listen-only', microphone: 'not-acquired', speakerOutput: 'disabled' };
  }
  async open(value) {
    if (!['idle', 'stopped', 'failed'].includes(this.phase)) throw new Error('Stop the current listener before opening another meeting');
    const url = meetingUrl(value);
    if (this.cdp) this.cdp.ws.close();
    const response = await fetch(`${endpoint}/json/new?about:blank`, { method: 'PUT', signal: AbortSignal.timeout(10000) });
    if (!response.ok) throw new Error('Start the OpenClaw browser first');
    const tab = await response.json();
    this.cdp = await Cdp.connect(tab.webSocketDebuggerUrl);
    await this.cdp.call('Runtime.enable');
    await this.cdp.call('Page.enable');
    await this.cdp.call('Runtime.addBinding', { name: '__localMeetingPcm' });
    await this.cdp.call('Page.addScriptToEvaluateOnNewDocument', { source: `(${installCapture.toString()})()` });
    // Deny device access in this dedicated browser context. Receiver audio does
    // not need microphone or camera permission, and no sender is created here.
    for (const name of ['microphone', 'camera']) {
      await this.cdp.call('Browser.setPermission', {
        permission: { name }, setting: 'denied', origin: new URL(url).origin,
      });
    }
    this.id = randomUUID(); this.file = join(stateRoot, `${this.id}.jsonl`);
    this.totalBytes = 0; this.lines = 0; this.error = undefined;
    this.queue = []; this.chunks = []; this.bytes = 0; this.busy = false;
    this.phase = 'opened';
    await this.cdp.call('Page.navigate', { url });
    return { ...this.summary(), manualAction: 'Complete Teams login and join without microphone/camera. Then call start.' };
  }
  async start() {
    if (this.phase !== 'opened') throw new Error('Open a meeting first; the listener is not ready to start');
    const page = await this.cdp.evaluate('window.__localMeetingCapture?.status()');
    if (!page?.inCall) return { ...this.summary(), manualAction: 'Enter the Teams call manually, then retry start.' };
    await mkdir(stateRoot, { recursive: true, mode: 0o700 });
    this.phase = 'loading-model';
    this.worker = spawn('/usr/bin/python3', [fileURLToPath(new URL('./whisper-worker.py', import.meta.url))], {
      stdio: ['pipe', 'pipe', 'ignore'], env: { ...process.env, OMP_NUM_THREADS: '4' },
    });
    const output = createInterface({ input: this.worker.stdout });
    this.worker.stdin.on('error', () => this.fail('Whisper input failed'));
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Whisper model loading timed out')), 60000);
      this.worker.once('error', () => { clearTimeout(timer); reject(new Error('Whisper could not start')); });
      this.worker.once('exit', () => {
        clearTimeout(timer); reject(new Error('Whisper worker exited'));
        if (!['stopped', 'failed', 'stopping'].includes(this.phase)) this.fail('Whisper worker exited');
      });
      output.on('line', line => {
        let result;
        try { result = JSON.parse(line); } catch { this.fail('Invalid Whisper output'); return; }
        if (result.ready) { clearTimeout(timer); resolve(); }
        if (result.error) { clearTimeout(timer); reject(new Error(result.error)); this.fail(result.error); }
        if (result.done) {
          this.writeTail = (this.writeTail ?? Promise.resolve()).then(async () => {
            if (result.text) {
              await appendFile(this.file, JSON.stringify({ time: new Date().toISOString(), text: result.text }) + '\n', { mode: 0o600 });
              this.lines++;
            }
            this.busy = false; this.pump();
          }).catch(() => this.fail('Transcript write failed'));
        }
      });
    }).catch(async error => { await this.fail(error.message); throw error; });
    this.cdp.onBinding = ({ name, payload }) => {
      if (name !== '__localMeetingPcm' || this.phase !== 'listening') return;
      if (payload.length > 24000 || !/^[A-Za-z0-9+/]*={0,2}$/.test(payload)) { this.fail('Invalid audio chunk'); return; }
      const bytes = Buffer.from(payload, 'base64');
      this.chunks.push(bytes); this.bytes += bytes.length; this.totalBytes += bytes.length;
      if (this.bytes >= 32000 * 20) this.flush();
    };
    this.phase = 'listening';
    try { await this.cdp.evaluate('window.__localMeetingCapture.start()'); }
    catch (error) { await this.fail(error.message); throw error; }
    this.startedAt = Date.now(); this.checking = false;
    this.timer = setInterval(async () => {
      if (this.checking || this.phase !== 'listening') return;
      this.checking = true;
      try {
        const status = await this.cdp.evaluate('window.__localMeetingCapture?.status()');
        if (!status?.inCall || Date.now() - this.startedAt > 4 * 3600000) await this.stop();
        else await this.cdp.evaluate('window.__localMeetingCapture.scan()');
      } catch { await this.fail('Meeting tab disconnected or navigated'); }
      finally { this.checking = false; }
    }, 1000);
    return this.summary();
  }
  flush() {
    if (!this.bytes) return;
    if (this.queue.length >= 4) { this.fail('Whisper cannot keep up; capture stopped rather than dropping audio'); return; }
    this.queue.push(Buffer.concat(this.chunks)); this.chunks = []; this.bytes = 0;
    this.pump();
  }
  pump() {
    if (this.busy || !this.queue.length || !this.worker || this.phase === 'failed') return;
    this.busy = true;
    this.worker.stdin.write(JSON.stringify({ pcm: this.queue.shift().toString('base64') }) + '\n');
  }
  async fail(message) {
    this.error = message; this.phase = 'failed'; clearInterval(this.timer);
    this.worker?.kill(); this.queue = []; this.chunks = []; this.bytes = 0;
    try { await this.cdp?.evaluate('window.__localMeetingCapture?.stop()'); } catch {}
  }
  async stop() {
    clearInterval(this.timer);
    if (this.phase === 'listening') {
      this.phase = 'stopping';
      try { await this.cdp.evaluate('window.__localMeetingCapture?.stop()'); } catch {}
      this.flush();
      const deadline = Date.now() + 90000;
      while ((this.busy || this.queue.length) && Date.now() < deadline) await new Promise(r => setTimeout(r, 100));
      await this.writeTail;
      if (this.busy || this.queue.length) this.error = 'Final transcription did not finish within 90 seconds';
    }
    this.worker?.kill(); this.worker = undefined;
    this.phase = this.error ? 'failed' : 'stopped';
    return this.summary();
  }
  async transcript() {
    if (!this.file) return { ...this.summary(), segments: [] };
    let text;
    try { text = await readFile(this.file, 'utf8'); }
    catch (error) { if (error.code === 'ENOENT') text = ''; else throw error; }
    return { ...this.summary(), segments: text.trim().split('\n').filter(Boolean).slice(-100).map(JSON.parse) };
  }
}

export default {
  id: 'local-meeting-audio', name: 'Local Meeting Audio',
  register(api) {
    const listener = new Listener();
    api.registerTool(ctx => {
      if (ctx.agentId !== 'meeting_notetaker') return null;
      return {
        name: 'meeting_audio', label: 'Local Meeting Audio',
        description: 'Open an explicitly authorized Teams link (including /meet/) in the dedicated OpenClaw browser. User joins manually with microphone/camera denied. Start captures only remote WebRTC audio and transcribes with local Whisper, without speaking. Status reports actual audio seconds and transcript counts; never claim capture from opened status. Stop ends capture, not the meeting. Transcript returns the most recent 100 locally stored segments for notes.',
        parameters: {
          type: 'object', properties: {
            action: { type: 'string', enum: ['open', 'start', 'status', 'stop', 'transcript'] },
            url: { type: 'string', description: 'Authorized Teams link; only needed for open. Do not repeat it in replies.' },
          }, required: ['action'], additionalProperties: false,
        },
        async execute(_id, params) {
          const result = params.action === 'open' ? await listener.open(params.url)
            : params.action === 'start' ? await listener.start()
            : params.action === 'stop' ? await listener.stop()
            : params.action === 'transcript' ? await listener.transcript() : listener.summary();
          return { content: [{ type: 'text', text: JSON.stringify(result) }], details: result };
        },
      };
    }, { name: 'meeting_audio', optional: true });
    api.registerService({ id: 'local-meeting-audio', start() {}, async stop() { await listener.stop(); listener.cdp?.ws.close(); } });
  },
};
