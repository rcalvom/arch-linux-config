// Installed before Teams loads. Only RTCPeerConnection receiver tracks enter
// this graph: no microphone acquisition, media sender or audible output exists.
export function installCapture() {
  if (window.__localMeetingCapture || !window.RTCPeerConnection) return;
  const tracks = new Map();
  const NativePeer = window.RTCPeerConnection;
  window.RTCPeerConnection = new Proxy(NativePeer, {
    construct(target, args, newTarget) {
      const peer = Reflect.construct(target, args, newTarget);
      peer.addEventListener('track', ({ track }) => {
        if (track.kind === 'audio') tracks.set(track.id, track);
      });
      return peer;
    },
  });
  let context, processor, mute, enabled = false;
  const nodes = new Map();
  const state = {
    scan() {
      for (const [id, node] of nodes) {
        if (tracks.get(id)?.readyState !== 'live') {
          node.disconnect(); nodes.delete(id); tracks.delete(id);
        }
      }
      if (!enabled) return;
      for (const [id, track] of tracks) {
        if (track.readyState !== 'live' || nodes.has(id)) continue;
        const node = context.createMediaStreamSource(new MediaStream([track]));
        node.connect(processor); nodes.set(id, node);
      }
    },
    async start() {
      if (enabled) return;
      context = new AudioContext({ sampleRate: 16000 });
      if (context.sampleRate !== 16000) throw new Error('Unexpected audio sample rate');
      processor = context.createScriptProcessor(4096, 1, 1);
      mute = context.createGain(); mute.gain.value = 0;
      processor.connect(mute); mute.connect(context.destination);
      processor.onaudioprocess = event => {
        if (!enabled || nodes.size === 0) return;
        const samples = event.inputBuffer.getChannelData(0);
        const bytes = new Uint8Array(samples.length * 2);
        const view = new DataView(bytes.buffer);
        for (let i = 0; i < samples.length; i++) {
          view.setInt16(i * 2, Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), true);
        }
        window.__localMeetingPcm(btoa(String.fromCharCode(...bytes)));
      };
      await context.resume();
      if (context.state !== 'running') throw new Error('Audio playback needs a user gesture');
      enabled = true; state.scan();
    },
    async stop() {
      enabled = false;
      for (const node of nodes.values()) node.disconnect();
      nodes.clear();
      if (processor) { processor.onaudioprocess = null; processor.disconnect(); }
      if (mute) mute.disconnect();
      if (context) await context.close();
    },
    status() {
      const inCall = Boolean(document.querySelector(
        'button#hangup-button,button[data-tid="call-hangup"],button[data-tid="hangup-button"],button[data-tid="call-hangup-button"]'
      ));
      return { inCall, enabled, tracks: nodes.size, hooked: true };
    },
  };
  window.__localMeetingCapture = state;
}
