# Wayland / Hyprland Notes

**Last updated:** 2026-05-15

This folder records the active Wayland/Hyprland setup used by the installer. Qtile remains only as a legacy reference outside this path.

## Current scope

- Hyprland session as the primary desktop target.
- Waybar as the status bar.
- Wofi as the app launcher for the reproducible installer path.
- Yazi as terminal file manager.
- Ubuntu as the preferred UI font, with Noto fallback for missing glyphs.

## Installed packages

See:

```text
wayland/packages/wayland-packages.txt
```

Important packages added/used:

- `hyprland`
- `hyprpaper`
- `hyprlock`
- `hyprsunset`
- `waybar`
- `mako`
- `wl-clipboard`
- `cliphist`
- `wofi`
- `yazi`
- `noto-fonts`
- `noto-fonts-cjk`
- `noto-fonts-emoji`
- `noto-fonts-extra`
- `ttf-nerd-fonts-symbols`
- `grim` / `slurp`
- `brightnessctl`
- `playerctl`
- `polkit-kde-agent`
- `network-manager-applet`
- `xdg-desktop-portal-hyprland`

## Hyprland

Config snapshots:

```text
wayland/hypr/hyprland.conf
wayland/hypr/hyprland.lua
```

Live locations:

```text
~/.config/hypr/hyprland.conf
~/.config/hypr/hyprland.lua
```

Notes:

- The installer uses the standard `hyprland.conf` config so a fresh official Hyprland package can load it without extra tooling.
- The Lua-style config is kept as a personal snapshot and reference.
- Program commands are centralized near the top of both configs.

Current important program variables:

```lua
local terminal    = "alacritty"
local fileManager = "alacritty -e yazi"
local menu        = "wofi --show drun"
local browser     = "firefox"
```

Important bindings:

```text
SUPER + Return -> Alacritty
SUPER + D      -> Wofi launcher
SUPER + R      -> Wofi launcher
SUPER + B      -> Firefox
SUPER + E      -> Alacritty running Yazi
SUPER + Q      -> close active window
SUPER + Shift+Q -> exit Hyprland
SUPER + Escape -> hyprlock
```

Yazi is terminal-based, so the file manager command is:

```bash
alacritty -e yazi
```

## Autostart / session helpers

The `hyprland.conf` config includes these session helpers:

```text
exec-once = waybar
exec-once = mako
exec-once = hyprpaper
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = nm-applet --indicator
```

The installer config starts `waybar` and also bootstraps the Hyprsunset schedule at session start.

## Hyprsunset / redshift equivalent

Wayland does not use classic `redshift` here. The current equivalent is **Hyprsunset**.

Config/script snapshots:

```text
wayland/bin/hyprsunset-set
wayland/bin/hyprsunset-apply-current
wayland/systemd/user/hyprsunset-day.service
wayland/systemd/user/hyprsunset-day.timer
wayland/systemd/user/hyprsunset-night.service
wayland/systemd/user/hyprsunset-night.timer
```

Live locations:

```text
~/.local/bin/hyprsunset-set
~/.local/bin/hyprsunset-apply-current
~/.config/systemd/user/hyprsunset-day.service
~/.config/systemd/user/hyprsunset-day.timer
~/.config/systemd/user/hyprsunset-night.service
~/.config/systemd/user/hyprsunset-night.timer
```

Schedule configured:

```text
18:30-07:30 -> warm filter, 3500K
07:30-18:30 -> identity / no filter
```

Enabled user timers:

```text
hyprsunset-day.timer
hyprsunset-night.timer
```

The Lua config also runs this at Hyprland start:

```lua
systemctl --user start hyprsunset.service
~/.local/bin/hyprsunset-apply-current
```

## Hyprpaper / wallpaper

Snapshot:

```text
wayland/hypr/hyprpaper.conf
```

Current config is minimal/default-like. Wallpaper lines are commented and `splash = false`.

## Hyprlock

Snapshot:

```text
wayland/hypr/hyprlock.conf
```

Bound in Hyprland as:

```text
SUPER + Escape -> hyprlock
```

## Mako notifications

Snapshot:

```text
wayland/mako/config
```

Current styling:

```text
default-timeout=5000
border-size=2
border-color=#89b4fa
background-color=#1e1e2eee
text-color=#cdd6f4
```

## Clipboard history

Uses `wl-clipboard` + `cliphist`.

Startup watchers in `hyprland.conf` snapshot:

```text
wl-paste --type text --watch cliphist store
wl-paste --type image --watch cliphist store
```

Binding in Lua config:

```text
SUPER + C -> cliphist list | wofi --dmenu | cliphist decode | wl-copy
```

## Screenshots

Uses `grim`, `slurp`, and `wl-copy`.

Bindings in Lua config:

```text
Print                -> save full screenshot to ~/Pictures/screenshots
Ctrl + Print         -> copy full screenshot to clipboard
Shift + Print        -> select area and save to ~/Pictures/screenshots
Ctrl + Shift + Print -> select area and copy to clipboard
```

## Waybar

Config snapshots:

```text
wayland/waybar/config.jsonc
wayland/waybar/style.css
```

Live locations:

```text
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
```

Current Waybar settings:

```jsonc
"height": 28
```

```css
font-size: 12px;
```

Current modules:

- left: Hyprland workspaces
- center: active Hyprland window
- right: pulseaudio, network, battery, clock, tray

To reload Waybar manually:

```bash
pkill waybar && waybar &
```

## Wofi

Installed from the official Arch repository:

```bash
sudo pacman -S --needed wofi
```

Run manually:

```bash
wofi --show drun
```

The current Hyprland config uses `wofi --show drun` as the menu command.

Clipboard history uses Wofi as a dmenu-compatible picker:

```bash
cliphist list | wofi --dmenu | cliphist decode | wl-copy
```

## Yazi

Installed package:

```text
yazi
```

Binary locations:

```text
/usr/bin/yazi
/usr/bin/ya
```

User config location, if customized later:

```text
~/.config/yazi/
```

At the time of this note, no custom Yazi config was created; it is using its defaults.

## Font fallback

Config snapshot:

```text
wayland/fontconfig/conf.d/99-ubuntu-fallback.conf
```

Live location:

```text
~/.config/fontconfig/conf.d/99-ubuntu-fallback.conf
```

Goal:

- Keep `Ubuntu` as the preferred UI font.
- Use Noto only when Ubuntu lacks glyphs.

Fallback order configured for `Ubuntu` and `sans-serif`:

1. Ubuntu
2. Noto Sans Symbols 2
3. Noto Sans Symbols
4. Noto Sans CJK SC
5. Noto Sans CJK TC
6. Noto Sans CJK JP
7. Noto Sans CJK KR
8. Noto Color Emoji
9. Noto Sans

Validation after setup:

```text
Ubuntu normal -> Ubuntu-R.ttf: "Ubuntu" "Regular"
Symbol ⮜     -> NotoSansSymbols2-Regular.ttf: "Noto Sans Symbols 2" "Regular"
Chinese 你   -> NotoSansCJK-Regular.ttc: "Noto Sans CJK SC" "Regular"
Emoji 😀     -> NotoColorEmoji.ttf: "Noto Color Emoji" "Regular"
```

To refresh fontconfig cache:

```bash
fc-cache -f
```

Restart affected apps after font changes: terminal, Waybar, browser, launchers, etc.

## Design preference / maintenance note

Keep configs close to upstream/default structure when possible.

In particular:

- Prefer changing centralized variables such as `terminal`, `fileManager`, `menu`, and `browser`.
- Avoid adding duplicate override variables such as separate `gingerFileManager` values unless there is a clear reason.
- Avoid duplicate binds for the same key, especially `SUPER + E`.
