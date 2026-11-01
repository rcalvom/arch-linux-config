# AI Terminal Launchers

The OpenCode and Claude Code desktop entries appear in Rofi's `drun` mode and
other desktop application menus. Each entry starts a new Alacritty window:

- OpenCode: `alacritty --title OpenCode -e opencode`.
- Claude Code: `alacritty --title "Claude Code" -e claude`.

`Terminal=false` is intentional: the command starts Alacritty explicitly.
The working directory is inherited from the launcher. Each terminal normally
closes when its CLI exits. `TryExec` hides an entry when its CLI is not on the
desktop session's `PATH`; Alacritty must also be installed. These files do not
install the applications or configure authentication.

## Deployment

`files.conf` participates in the repository's existing package-manifest deployment:

- Desktop entries: `~/.local/share/applications/archcfg-*.desktop`.
- Icons: `~/.local/share/icons/hicolor/scalable/apps/archcfg-*.svg`.

The existing Claude Code URL-handler entry is separate and remains unchanged.
Rofi is configured with icons enabled and its desktop cache reloaded. Close and
reopen Rofi after deployment, then search for `OpenCode` or `Claude Code`.

Validate the entries from the repository root:

```sh
desktop-file-validate packages/ai-launchers/archcfg-opencode.desktop
desktop-file-validate packages/ai-launchers/archcfg-claude-code.desktop
git diff --check -- packages/ai-launchers
```

After deploying, refresh the desktop database with
`update-desktop-database ~/.local/share/applications`.

## Icons

The SVG paths come from [Simple Icons](https://github.com/simple-icons/simple-icons),
retrieved on 2026-10-05 from `icons/opencode.svg` and `icons/claude.svg`.
OpenCode uses a light fill (`#f1ecec`) for the dark launcher; Claude uses terracotta
(`#d97757`). The path geometry is unchanged. Simple Icons is distributed under
CC0 1.0; trademark rights remain with their owners. The upstream license is
included as `icons/LICENSE.simple-icons.md`.
