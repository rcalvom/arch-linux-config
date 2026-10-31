# OpenClaw Sandboxes

This document describes the portable security model and recovery procedure for
the local OpenClaw deployment. It deliberately excludes `~/.openclaw/openclaw.json`,
gateway tokens, provider credentials, Telegram tokens, deploy keys, session
transcripts, and generated sandbox state.

OpenClaw is an optional AUR package declared in `packages/aur.txt`. Its runtime
configuration is operator-managed because it contains host-specific paths and
secrets.

## Package-Managed Gateway

Install the OpenClaw core through the reviewed AUR package, then let the
installed release generate its matching user service:

```bash
yay -S --needed openclaw
openclaw gateway install --force --port 18789 --runtime node
openclaw gateway start
```

The generated unit invokes the package-owned runtime with release-specific
memory and shutdown settings and contains no credential values. Keep the
gateway bound to configured loopback endpoints in the live
`~/.openclaw/openclaw.json`; that file remains untracked.

`openclaw/systemd/user/openclaw-gateway.service` is a portable fallback and
policy reference, not the preferred deployed unit. Regenerate the active unit
after package upgrades so runtime paths, heap sizing, `KillMode=mixed`, and the
extended drain timeout match the installed release.

OpenClaw's bundled extensions are included with the AUR package. Some optional
channel and provider plugins may remain under `~/.openclaw/npm/` when no
official or AUR package exists. Preserve that directory during upgrades and
migrations; it is runtime state, not the deprecated global npm installation.

After an OpenClaw package update, restart and check the gateway explicitly:

```bash
openclaw gateway install --force --port 18789 --runtime node
openclaw gateway start
openclaw health
openclaw channels status
openclaw plugins doctor
```

## Topology

The gateway is a user systemd service bound to loopback with token
authentication. It launches Docker-backed sandbox containers for agent tools.

The intended agent layout is:

| Agent | Workspace access | Sandbox scope | Network | Intended role |
| --- | --- | --- | --- | --- |
| `main` | `none` | `agent` | default | General assistant |
| `labnotes` | `rw` | `agent` | `bridge` | Lab-notes repository workflow |
| `csap` | `rw` | `agent` | `bridge` | CSAP repository workflow |
| `meeting_notetaker` | `none` | `session` | `none` | Authorized meeting transcription and notes |

`mode: "all"` is used so every session is sandboxed. `scope: "agent"` means
an agent reuses one persistent container across its sessions. Recreate that
container after changing its image, network, workspace contents, or sandbox
policy.

`workspaceAccess: "rw"` mounts an agent workspace at `/workspace`. This is
necessary for the two repository agents to edit, commit, and push their
repositories, but it is not a read-only review boundary. Keep every file in
those workspaces within the agent's intended authority.

## Tool And Host Boundaries

The effective agent policies must be verified with `openclaw sandbox explain`
after every OpenClaw upgrade. The intended sandbox boundary is:

- `exec.host` must report `sandbox` for `main`, `labnotes`, and `csap`.
- `security: "full"` and `ask: "off"` apply inside the Docker sandbox; they
  do not grant host execution while the effective runtime remains sandboxed.
- Elevated execution must remain disabled.
- Browser, gateway, and external messaging tools should remain denied unless a
  narrowly reviewed workflow needs them.

If an agent ever reports `exec.host: "gateway"` or a non-sandboxed runtime,
treat it as host-level authority and do not route untrusted work through it.

No extra Docker bind mounts or Docker socket mounts are part of this design.
Never add `/var/run/docker.sock`, the user's home directory, or credential
directories to a sandbox. Docker socket access defeats the container boundary.

## Meeting Notes

For local audio-only note-taking, the experimental
[`openclaw-meeting-audio`](../packages/openclaw-meeting-audio/README.md) package
adds `meeting_audio` to `meeting_notetaker`. It supports numeric Teams `/meet/`
links, manual entry, receive-only WebRTC capture and the existing local Whisper
base model. Grant it in the agent's `alsoAllow` and sandbox allowlist. It neither
speaks nor joins automatically; audio remains in memory and resulting text is
stored privately outside Git. Opening a tab is not proof of audio capture: check
`status.audioSeconds` and `status.transcriptSegments` after `start`.

`meeting_notetaker` is an isolated, no-filesystem agent for authorized meeting
notes. Its operating instructions require truthful disclosure, participant
consent when required, and explicit operator approval for every meeting. It
must not impersonate Ricardo, send chat messages, speak, create meetings, or
bypass sign-in, MFA, lobby, CAPTCHA, tenant, or organizer controls.

The reviewed `@openclaw/teams-meetings` plugin provides Microsoft Teams guest
participation. It is an OpenClaw plugin, not a Microsoft integration: it does
not call Microsoft Graph, read calendars or chats, create meetings, record
audio/video, or write to the meeting chat. Its `transcribe` mode uses Teams
live captions when available and stores the resulting notes in OpenClaw's
private runtime state.

Install or update meeting plugins only with explicit approval:

```bash
openclaw plugins install @openclaw/teams-meetings
```

The live runtime configuration remains untracked. Configure the Teams plugin
with these security properties:

- `defaultMode: "transcribe"`;
- a guest name that identifies the assistant as acting for Ricardo;
- `chrome.autoJoin: false` and `chrome.reuseExistingTab: false`;
- `realtime.agentId: "meeting_notetaker"` and `realtime.toolPolicy: "none"`.

The agent needs the plugin tool at both policy layers: use
`agents.entries.meeting_notetaker.tools.profile: "minimal"` with
`alsoAllow: ["teams_meetings"]`, and set its
`tools.sandbox.tools.allow` to `["session_status", "teams_meetings"]`.
Do not combine agent-level `allow` and `alsoAllow`. The existing browser,
filesystem, runtime and delegation denies remain in effect; the meeting plugin
operates its own Chrome transport through the Gateway. Keep `mode: "transcribe"`
in join requests and complete admission or login manually when requested.

The policy update was schema-validated and hot-reloaded on 2026-10-15. A real
meeting join still requires a separate authorized end-to-end test.

The bundled `browser` plugin must also be enabled and included in `plugins.allow`:
Teams uses its Gateway `browser.request` method even when the agent's generic
`browser` tool is denied. A missing method indicates a disabled backend, not an
agent tool-policy failure. Use `openclaw browser status --json` to verify it.
For interactive sign-in, the Gateway process must inherit the current desktop's
DISPLAY or WAYLAND_DISPLAY and XDG_RUNTIME_DIR. A service started before the
desktop environment was imported may report `linux-display-fallback` headless
mode; an operator-approved restart after desktop initialization refreshes its
environment. Verify visible browser operation before attempting a meeting.

Check prerequisites without joining a meeting:

```bash
openclaw teamsmeetings setup --mode transcribe
```

The `guest-join` check intentionally remains unsuccessful while auto-join and
tab reuse are disabled. Caption support and the local OpenClaw Chrome profile
must report ready before a controlled test. The first test must use an
authorized meeting link; the operator completes any sign-in, MFA, browser
permission, or lobby step manually and posts a disclosure such as:

> Hola, soy Ginger, el asistente de notas de Ricardo. Ricardo está ausente y
> tomaré notas para compartirle un resumen. Por favor, avisen si tienen alguna
> objeción.

Inspect completed notes locally; do not commit exported transcripts or
summaries:

```bash
openclaw transcripts list
openclaw transcripts show <selector>
```

Zoom support is intentionally deferred. If approved later, install
`@openclaw/zoom-meetings` and apply the same observe-only policy to the existing
`meeting_notetaker` agent.

## Network And Secrets

Docker sandboxes default to `network: "none"`. The two repository agents use
`bridge` deliberately so they can reach their Git remotes. This enables general
egress as well, so a prompt-injected command could send workspace data or an
available deploy key outside the host.

Keep the following permissions restrictive on the host:

```text
$HOME/.openclaw/                 0700
$HOME/.openclaw/openclaw.json    0600
$HOME/.openclaw/credentials/     0700
agent workspaces                 0700
private deploy keys              0600
```

The Git repositories inside protected workspaces may be mode `0755`; their
parent workspaces still prevent other local users from traversing to them.

Use OpenClaw SecretRefs rather than plaintext values in `openclaw.json`:

```bash
openclaw secrets configure
openclaw secrets audit --check
```

Do not commit the live JSON, its backups, deploy keys, workspace clones, or
host-specific service overrides. The tracked gateway unit is safe to version
because it contains only portable paths and no credential values.

## Kernel And Docker Bridge

The Docker `bridge` network needs the running kernel's `veth` module. After a
kernel package upgrade, reboot before recreating a sandbox that needs network
egress; the installed module tree must match `uname -r`.

```bash
uname -r
modinfo veth
docker run --rm --network bridge debian:bookworm-slim /bin/true
```

If the module is missing for the running kernel, do not weaken the sandbox to
host networking. Boot the matching installed kernel first, then rerun the
bridge check. The Compose build can use host networking only at build time; it
does not change this runtime requirement.

## Sandbox Images

The default Docker image is `openclaw-sandbox:bookworm-slim`. The two
repository agents require a local SSH-capable variant named
`openclaw-sandbox-ssh:bookworm-slim`. Docker image tags are local state and can
be removed by `docker system prune`; verify them before recreating a sandbox:

```bash
docker image inspect openclaw-sandbox:bookworm-slim
docker image inspect openclaw-sandbox-ssh:bookworm-slim
```

`openclaw/Dockerfile` defines a reviewed multi-stage replacement for both
images. Its Debian base is pinned by digest; review and update that digest
deliberately when applying base-image security updates. `openclaw/compose.yaml`
builds the tags without starting services:

```bash
docker compose -f openclaw/compose.yaml build
```

The `base` target matches the upstream minimal image. The `ssh` target extends
it with `openssh-client` for Git remotes. Never copy credentials into the build
context or image layers.

The Compose file uses host networking only while building because this host may
not permit Docker to create a temporary bridge endpoint during `RUN` steps. It
does not set a runtime `network_mode`; OpenClaw still applies each agent's
sandbox network policy when it creates containers.

If an agent needs additional tools, add them to a reviewed image recipe rather
than running a broad setup command with a writable root filesystem and network
access.

### Image Smoke Test

Rebuild both targets without cache, then verify their required tools under the
same non-root user used by the sandbox image:

```bash
docker compose -f openclaw/compose.yaml build --no-cache

docker run --rm --network none openclaw-sandbox:bookworm-slim sh -lc \
  'test "$(id -un)" = sandbox && command -v bash curl git jq python3 rg >/dev/null'

docker run --rm --network none openclaw-sandbox-ssh:bookworm-slim sh -lc \
  'test "$(id -un)" = sandbox && command -v ssh >/dev/null'
```

This verifies image construction and isolated container startup. It does not
create or modify an OpenClaw agent sandbox. Confirm configured agent containers
and their selected image separately with `openclaw sandbox list --json`; only
recreate an affected agent after preserving its workspace state.

## Operations

Inspect the configured and effective policies without changing state:

```bash
systemctl --user status openclaw-gateway.service
openclaw sandbox list
openclaw sandbox explain --agent main
openclaw sandbox explain --agent labnotes
openclaw sandbox explain --agent csap
openclaw doctor
openclaw security audit --deep
```

After an image or sandbox policy change, recreate only the affected agent:

```bash
openclaw sandbox recreate --agent labnotes
openclaw sandbox recreate --agent csap
```

`recreate` removes the existing container and its sandbox-local state. Commit
or otherwise preserve repository changes before using it. Do not run
`openclaw doctor --fix` blindly: review every proposed migration, policy, and
state cleanup first.

## Maintenance Checklist

1. Verify the gateway remains bound to loopback and uses token authentication.
2. Confirm image availability before starting a sandbox after Docker cleanup.
3. Review `bridge` network access and retain it only for agents that need
   remote Git access.
4. Keep deploy keys out of image layers and outside broad writable workspaces
   when possible.
5. Run `openclaw sandbox explain` and `openclaw security audit --deep` after
   upgrades or policy changes.
6. Update this document with sanitized behavior and recovery steps, never with
   credential values or runtime state.
