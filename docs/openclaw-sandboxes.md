# OpenClaw Sandboxes

This document describes the portable security model and recovery procedure for
the local OpenClaw deployment. It deliberately excludes `~/.openclaw/openclaw.json`,
gateway tokens, provider credentials, Telegram tokens, deploy keys, session
transcripts, and generated sandbox state.

OpenClaw is an optional AUR package declared in `packages/aur.txt`. Its runtime
configuration is operator-managed because it contains host-specific paths and
secrets.

## Topology

The gateway is a user systemd service bound to loopback with token
authentication. It launches Docker-backed sandbox containers for agent tools.

The intended agent layout is:

| Agent | Workspace access | Sandbox scope | Network | Intended role |
| --- | --- | --- | --- | --- |
| `main` | `none` | `agent` | default | General assistant |
| `labnotes` | `rw` | `agent` | `bridge` | Lab-notes repository workflow |
| `csap` | `rw` | `agent` | `bridge` | CSAP repository workflow |

`mode: "all"` is used so every session is sandboxed. `scope: "agent"` means
an agent reuses one persistent container across its sessions. Recreate that
container after changing its image, network, workspace contents, or sandbox
policy.

`workspaceAccess: "rw"` mounts an agent workspace at `/workspace`. This is
necessary for the two repository agents to edit, commit, and push their
repositories, but it is not a read-only review boundary. Keep every file in
those workspaces within the agent's intended authority.

## Tool And Host Boundaries

The repository agents are configured for file and process work:

- Allowed agent tools: `read`, `write`, `edit`, `apply_patch`, `exec`, and
  `process`.
- Denied agent tools: browser, web, gateway, cross-session messaging/spawning,
  and subagents.
- Their `exec` host is `sandbox`; `security: "full"` and `ask: "off"` apply
  inside that sandbox rather than granting host execution.
- Elevated execution is disabled. Confirm the effective result with
  `openclaw sandbox explain --agent <id>` after every OpenClaw upgrade.

The `main` agent is an explicit exception: its configuration selects
`exec.host: "gateway"` with full security and no execution prompt. Treat this
as host-level authority even though sandbox mode is enabled globally. Do not
route untrusted or broad automation through that agent without an additional
approval boundary.

No extra Docker bind mounts or Docker socket mounts are part of this design.
Never add `/var/run/docker.sock`, the user's home directory, or credential
directories to a sandbox. Docker socket access defeats the container boundary.

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

Do not commit the live JSON, its backups, deploy keys, or workspace clones.
The same rule applies to the user gateway unit when it contains a host-specific
runtime path or environment.

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
