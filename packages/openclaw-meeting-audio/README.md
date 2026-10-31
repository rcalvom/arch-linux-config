# Local meeting audio (experimental)

Native OpenClaw plugin for `meeting_notetaker`, exposing `meeting_audio` actions
`open`, `start`, `status`, `stop`, and `transcript`. The upstream Teams plugin's
caption-only workflow remains available separately.

Open the dedicated OpenClaw Chrome profile first (CDP on loopback port 18800).
`open` accepts authorized Teams work and consumer links, including numeric
`/meet/` links. It installs a receiver-track hook before navigation. The user
completes login and joins manually. Microphone/camera permissions are denied for
that Teams origin in this browser context. `start` refuses to capture before the
in-call hang-up control is present. Never run both meeting audio engines on the
same tab. If the tab was already loaded without the hook, use `open` first.

Only incoming WebRTC audio tracks enter the capture graph. This implementation
does not call getUserMedia, create media senders, synthesize speech, or send chat
messages. A zero-gain sink runs the audio graph without replaying captured audio;
the meeting's normal speaker playback is unchanged. It does not click Join.

Whisper uses the already installed `/usr/bin/python3`, numpy, torch, openai-whisper
and `~/.cache/whisper/base.pt`. No model download is triggered. CPU inference uses
four threads, with approximately 20-second chunks. Raw audio stays in memory;
the queue is bounded and capture fails explicitly if transcription cannot keep
up. Transcription quality and phrase boundaries are limited by the base model
and chunking; speaker identification is not implemented.

Text is stored outside Git at `~/.local/share/openclaw-meeting-audio/<uuid>.jsonl`
(directory 700, files 600). No meeting URL or raw recording is stored by this
plugin. OpenClaw may retain tool arguments in its own history. Transcripts
requested by the agent enter its model context and may be sent to its configured
remote model; local speech recognition does not imply wholly local note-taking.
`transcript` returns the last 100 segments. The agent summarizes those on request;
this is not integrated with the upstream automatic meeting-notes database.

Capture stops on departure, browser disconnect, queue overflow, explicit stop,
or after four hours. Stop drains pending chunks for up to 90 seconds and reports
incomplete draining. It does not leave or close the meeting tab. Gateway restarts
end the listener; saved transcripts remain on disk, but session recovery is not
implemented. Use status to distinguish opening, listening and actual audio flow.

Deploy source files (excluding tests) to
`~/.openclaw/extensions/local-meeting-audio/`. Enable that plugin and add it to
`plugins.allow`. Add `meeting_audio` to the meeting agent's `tools.alsoAllow` and
`tools.sandbox.tools.allow`; its factory is unavailable to other agent IDs.
Reload the plugin with `openclaw plugins reload local-meeting-audio`.

Run `node --test test.mjs` and `node --check index.mjs`. Synthetic tests cover
destination validation, prejoin gating, bounded queues, receiver-track isolation,
PCM encoding and cleanup. Actual Teams UI selectors and audio transport still
require a controlled live verification with participant authorization.

`node test-browser.mjs` additionally verifies incoming WebRTC PCM and stop cleanup
using a synthetic tone in a temporary Chrome tab. It requires the dedicated
browser to be running. This integration check and a local Whisper model-load/
silence check passed on 2026-10-15; live Teams speech recognition is still pending.
