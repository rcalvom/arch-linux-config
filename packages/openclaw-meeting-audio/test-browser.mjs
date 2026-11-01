// Optional integration check against the dedicated OpenClaw browser. Creates
// and closes its own blank tab; all audio is a synthetic local WebRTC tone.
import assert from 'node:assert/strict';
import { Cdp } from './index.mjs';
import { installCapture } from './capture.mjs';
const tab = await (await fetch('http://127.0.0.1:18800/json/new?about:blank', { method: 'PUT' })).json();
const cdp = await Cdp.connect(tab.webSocketDebuggerUrl);
let total = 0, peak = 0;
try {
  await cdp.call('Runtime.enable');
  await cdp.call('Runtime.addBinding', { name: '__localMeetingPcm' });
  cdp.onBinding = ({ payload }) => {
    const bytes = Buffer.from(payload, 'base64'); total += bytes.length;
    for (let i = 0; i < bytes.length; i += 2) peak = Math.max(peak, Math.abs(bytes.readInt16LE(i)));
  };
  for (const name of ['microphone', 'camera']) {
    await cdp.call('Browser.setPermission', { permission: { name }, setting: 'denied', origin: 'https://teams.microsoft.com' });
  }
  await cdp.evaluate(`(${installCapture.toString()})()`);
  await cdp.evaluate(`(async () => {
    const context = new AudioContext(), tone = context.createOscillator();
    const output = context.createMediaStreamDestination();
    tone.connect(output); tone.start(); await context.resume();
    const a = new RTCPeerConnection(), b = new RTCPeerConnection();
    window.testPeers = [a, b]; window.testAudio = context;
    b.ontrack = async e => {
      const audio = document.createElement('audio');
      audio.srcObject = new MediaStream([e.track]); audio.muted = true;
      document.body.append(audio); await audio.play();
    };
    a.onicecandidate = e => e.candidate && b.addIceCandidate(e.candidate);
    b.onicecandidate = e => e.candidate && a.addIceCandidate(e.candidate);
    a.addTrack(output.stream.getAudioTracks()[0], output.stream);
    await a.setLocalDescription(await a.createOffer());
    await b.setRemoteDescription(a.localDescription);
    await b.setLocalDescription(await b.createAnswer());
    await a.setRemoteDescription(b.localDescription);
    await window.__localMeetingCapture.start();
  })()`);
  await new Promise(r => setTimeout(r, 1500));
  await cdp.evaluate('window.__localMeetingCapture.scan()');
  await new Promise(r => setTimeout(r, 1500));
  console.log('Synthetic transport state:', await cdp.evaluate('({capture:window.__localMeetingCapture.status(), peers:window.testPeers.map(p=>({ice:p.iceConnectionState,connection:p.connectionState,receivers:p.getReceivers().length})), audio:window.testAudio.state})'));
  console.log('Captured byte and peak counts:', total, peak);
  assert.ok(total > 0 && peak > 0, 'No synthetic remote audio received');
  console.log('Receiver capture verified:', total, 'PCM bytes with nonzero signal.');
  await cdp.evaluate('window.__localMeetingCapture.stop()');
  const previous = total;
  await new Promise(r => setTimeout(r, 600));
  assert.equal(total, previous, 'Audio continued after stop');
  console.log('Capture cleanup verified.');
} finally {
  await cdp.call('Target.closeTarget', { targetId: tab.id }).catch(() => {});
  cdp.ws.close();
}
