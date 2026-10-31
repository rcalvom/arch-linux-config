# OpenCode on Arch

## October 2026 Personal Setup Update

The personal recipe now installs only the official `opencode` package, not
`opencode-notifier`. The notifier package was removed from the host; notifications
use a separate custom plugin. The packaged-plugin commands below describe the
independent generic optional setup, not the current personal installation.
See [the personal recipe](recipe-ricardo.md) for its current package selection.

## Generic Package-Managed Setup

This document describes the package-managed OpenCode setup for the local Arch
workstation. It is separate from `server-bootstrap/`, whose portable server
setup intentionally uses npm instead of Arch packages.

## Packages

The developer and VirtualBox profiles install OpenCode from the official Arch
repository. Pass `--aur` to the installer to also build the pinned optional
notifier package. On an existing system, install both with:

```bash
yay -S --needed opencode opencode-notifier
```

`opencode` is supplied by `extra`; `opencode-notifier` is an AUR package. The
notifier package installs only plugin files: it does not edit OpenCode
configuration, create a notifier profile, or enable Telegram forwarding. Use
the following command for routine upgrades so both sources are updated:

```bash
yay -Syu
```

Do not use a standalone installer, `opencode-bin`, or
`opencode plugin --global` for this setup. Those paths bypass package ownership
and can leave an npm-managed binary or plugin cache behind.

Disable OpenCode self-updates in the global configuration. OpenCode V2 uses
the plural `plugins` key. The AUR package currently exports the legacy plugin
function directly, while V2 requires an object with an ID and `setup`; use the
reviewed compatibility copy until the package provides that wrapper:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "plugins": ["file:///home/ricardo/.config/opencode/vendor/opencode-notifier"]
}
```

The compatibility copy differs from the packaged `dist/index.js` only in its
default-export wrapper. Recheck that assumption after every notifier upgrade;
do not copy credentials or notifier runtime state into the vendor directory.

Verify package ownership when troubleshooting:

```bash
pacman -Qo /usr/bin/opencode \
  /usr/lib/opencode/plugins/opencode-notifier/dist/index.js
```

## Shared Service

OpenCode V2 manages a shared background service for terminal clients. Inspect
and restart it with the supported CLI:

```bash
opencode service status
opencode service restart
```

Keep the service bound to loopback unless remote access is an explicit and
reviewed requirement. The API can run tools with the user's permissions, so a
LAN or private-overlay listener needs authentication, firewall restrictions,
credential rotation, and periodic exposure review.

Useful checks:

```bash
opencode service status
opencode api get /api/status
opencode api get /api/plugin
```

The terminal client binds `Ctrl+Alt+A` to `permission.mode`, allowing the user
to toggle automatic permission approval without editing configuration:

```json
{
  "keybinds": {
    "permission.mode": "ctrl+alt+a"
  }
}
```

After changing `opencode.json` or a server plugin, restart the shared service
after saving active work:

```bash
opencode service restart
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
