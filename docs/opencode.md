# OpenCode on Arch

This document describes the package-managed OpenCode setup for the local Arch
workstation. It is separate from `server-bootstrap/`, whose portable server
setup intentionally uses npm instead of Arch packages.

## Packages

Install OpenCode from the official repository and the optional notifier from
the AUR:

```bash
yay -S --needed opencode opencode-notifier
```

`opencode` is supplied by `extra`; `opencode-notifier` is an AUR package. Use
the following command for routine upgrades so both sources are updated:

```bash
yay -Syu
```

Do not use a standalone installer, `opencode-bin`, or
`opencode plugin --global` for this setup. Those paths bypass package ownership
and can leave an npm-managed binary or plugin cache behind.

The global configuration disables OpenCode self-updates and loads the packaged
plugin directly:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "plugin": ["file:///usr/lib/opencode/plugins/opencode-notifier/dist/index.js"]
}
```

Verify package ownership when troubleshooting:

```bash
pacman -Qo /usr/bin/opencode \
  /usr/lib/opencode/plugins/opencode-notifier/dist/index.js
```

## Shared Daemon

`opencode-server.service` is a user-level systemd service that runs the server
without invoking `opencode web` or opening a browser:

```text
/usr/bin/opencode serve --hostname 127.0.0.1 --port 4096
```

It is enabled under `default.target` and restarts on failure. Keep it bound to
loopback. The API can run shell tools with the user's permissions, so it must
not be exposed directly to a LAN or the Internet. Use an SSH tunnel or a
private network with additional authentication for remote access.

In OpenCode 1.18.11, `serve` still delivers the bundled Web UI at `/`. It does
not create a separate browser process or open a browser automatically, and
there is no documented CLI or configuration switch to remove that route. An
API-only HTTP surface would require a separate proxy that filters UI routes;
that adds complexity without meaningful resource savings.

The local `opencode` wrapper starts the service if needed, then attaches the
TUI to `http://127.0.0.1:4096`. It also adds `--attach` for `opencode run`.
The wrapper must invoke `/usr/bin/opencode`; it must not reference a standalone
path such as `~/.opencode/bin/opencode`.

Useful checks:

```bash
systemctl --user status opencode-server.service
curl --fail http://127.0.0.1:4096/global/health
opencode attach http://127.0.0.1:4096
```

After changing `opencode.json`, a plugin, or the service unit, restart the
daemon so it reloads configuration:

```bash
systemctl --user daemon-reload
systemctl --user restart opencode-server.service
```

## State and Cleanup

The following paths contain user state and must survive package changes:

- `~/.local/share/opencode/` contains sessions, credentials, snapshots, and
  tool output.
- `~/.config/opencode/` contains global configuration, notifier settings,
  commands, skills, and secrets.

Before replacing an older installation, take a SQLite-consistent backup of
`~/.local/share/opencode/opencode.db` and preserve the full state directory.
Do not copy only the main database while its `-wal` file is active.

After confirming that no process maps the legacy binary, it is safe to remove
the old standalone installation and npm caches. Keep `models.json` under
`~/.cache/opencode/`; it is a regular model cache, not an executable install.

## Skills

`customize-opencode` is an OpenCode built-in skill. Its location is reported as
`<built-in>` and it is supplied by OpenCode itself, not by this repository or
the user's `~/.config/opencode/skills/` directory. It documents safe handling
of OpenCode configuration, plugins, agents, and services.

This is distinct from local skills such as `loop-invariants`, which live under
`~/.config/opencode/skills/` and are user-managed. Do not create a duplicate
`customize-opencode` file merely to use the built-in guidance.

See [OpenCode Notifier](opencode-notifier.md) for notification and Telegram
configuration.
