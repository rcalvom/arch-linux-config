# Wayland / Hyprland Notes

**Last updated:** 2026-07-17

This folder records the active Wayland/Hyprland setup used by the installer. Qtile remains only as a legacy reference outside this path.

## Current scope

- Hyprland session as the primary desktop target.
- Waybar as the status bar.
- Rofi as the app launcher.
- Calcurse as the terminal calendar.
- Wdisplays for one-off graphical output adjustments.
- Firefox and Thunderbird with square browser chrome.
- Yazi as terminal file manager.
- Ubuntu as the preferred UI font, with Noto fallback for missing glyphs.

## Installed packages

See `packages/desktop.txt`.

Important packages added/used:

- `hyprland`
- `hyprpaper`
- `hyprlock`
- `hyprsunset`
- `fprintd`
- `waybar`
- `mako`
- `wdisplays`
- `wl-clipboard`
- `rofi`
- `calcurse`
- `thunderbird`
- `yazi`
- `noto-fonts`
- `noto-fonts-cjk`
- `noto-fonts-emoji`
- `noto-fonts-extra`
- `ttf-ubuntu-font-family`
- `ttf-ubuntu-mono-nerd`
- `ttf-nerd-fonts-symbols`
- `grim` / `slurp`
- `python`
- `brightnessctl`
- `playerctl`
- `impala`
- `bluetui`
- `polkit-kde-agent`
- `network-manager-applet`
- `xdg-desktop-portal-hyprland`

## Hyprland

Hyprland 0.55+ uses the Lua configuration:

```text
wayland/hypr/hyprland.lua
```

Live locations:

```text
~/.config/hypr/hyprland.lua
```

Notes:

- `hyprland.lua` is the single deployed source of session behavior.
- `hyprland.conf` remains only as a legacy Hyprland 0.54-and-older reference.
- Program commands are centralized near the top of the Lua config.

Current important program variables:

```lua
local terminal    = "alacritty"
local fileManager = "alacritty -e yazi"
local menu        = "rofi -show drun"
local browser     = "$HOME/.local/bin/archcfg-firefox"
local displayMenu = "$HOME/.local/bin/hypr-display-menu"
local audioSelector = "$HOME/.local/bin/hypr-audio-selector"
```

Important bindings:

```text
SUPER + Return -> Alacritty
SUPER + M/D    -> Rofi launcher
SUPER + B      -> Firefox
SUPER + E      -> Alacritty running Yazi
SUPER + A      -> Rofi audio input/output selector
SUPER + P      -> Rofi display mode/profile selector
SUPER + Shift+P -> pseudo-tile active window
SUPER + C      -> Alacritty running Calcurse
SUPER + W/Q    -> close active window
SUPER + L      -> Hyprlock
CTRL + ALT + Delete -> Rofi session menu
SUPER + Tab / SUPER + Shift+Tab -> toggle Monocle / Master layout
ALT + Tab / ALT + Shift+Tab -> next / previous window in the current layout
CTRL + Tab / CTRL + Shift+Tab -> application tabs, including Firefox
SUPER + CTRL + Tab / SUPER + CTRL + Shift+Tab -> next / previous window in the current layout
SUPER + R      -> Hyprsunset 3500K
SUPER + Shift+R -> disable Hyprsunset manually
SUPER + Shift+Q -> exit Hyprland
SUPER + Escape -> Hyprlock
ALT + 1..9     -> bring the selected workspace to the focused monitor
ALT + Ctrl+1..9 -> move the active window without following it
```

Yazi is terminal-based, so the file manager command is:

```bash
alacritty -e yazi
```

## Application profiles

Firefox and Thunderbird use versioned profile templates under `packages/`. Their `archcfg-*` launchers first update an existing default profile, or create a deterministic profile for a new user. This keeps userChrome customizations independent from browser package updates.

Firefox starts through `archcfg-firefox` from the `SUPER + B` binding. Its browser chrome hides client window controls and the Tab List button, with square tabs, controls, and panels. Thunderbird applies the equivalent titlebar customization through `archcfg-thunderbird`.

Calcurse and VS Code settings are also versioned under `packages/`. VS Code remains an optional AUR application and is not included in the live ISO.

## Monitor layout

`hypr-display-layout` reacts to Hyprland monitor add/remove and configuration-reload events. It matches the laptop panel and the two Dell displays by their physical descriptions, so dock connector names such as `DP-10` can change without breaking the layout. The selected mode/profile is stored in `~/.local/state/archcfg/display-layout.json` and reconciled after those events.

```text
[ Dell P2419H ][ Dell P2422H ]
     [ Lenovo laptop panel ]
```

The laptop panel is centered below the two external displays. With only the laptop connected, it is placed at `0x0`; with one Dell attached, that display is placed above it. The controller also extends unknown connected displays to the right of the known dock outputs.

`SUPER + P` opens a compact Rofi picker with two tabs:

```text
Modes    -> Single monitor, Extend displays, Mirror / Duplicate
Profiles -> Dock - 3 displays
```

Single monitor opens an output picker and disables the other connected outputs. Mirror / Duplicate first selects a source, then one target or all other connected outputs. The controller selects a common available mode before mirroring; if a saved profile or mirror source is unavailable later, it falls back to a safe extended layout. The `Dock - 3 displays` profile restores the layout shown above.

Manual changes through Wdisplays remain in effect until the next display-menu action, monitor hotplug event, configuration reload, or Hyprland session start.

Snapshot:

```text
wayland/bin/hypr-display-layout
wayland/bin/hypr-display-menu
```

Live location:

```text
~/.local/bin/hypr-display-layout
~/.local/bin/hypr-display-menu
```

## Autostart / session helpers

The Lua config starts these session helpers:

```text
waybar
mako
hyprpaper
hypr-display-layout
hypridle
polkit-kde-authentication-agent-1
nm-applet --indicator
```

The installer config starts `waybar` and also bootstraps the Hyprsunset schedule at session start.

## Hyprsunset / redshift equivalent

Wayland does not use classic `redshift` here. The current equivalent is **Hyprsunset**.

If Redshift was previously enabled for a legacy X11 session, disable its user service before using Hyprsunset:

```bash
systemctl --user disable --now redshift.service
```

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

`hyprsunset-set` waits for Hyprsunset's IPC socket before it sends a color request; it does not use a fixed service-start delay.

Manual controls:

```text
SUPER + R       -> warm filter, 3500K
SUPER + Shift + R -> identity / no filter
```

## Hyprpaper / wallpaper

Snapshot:

```text
wayland/hypr/hyprpaper.conf
wayland/wallpapers/wallpaper.png
```

The wallpaper is copied to `~/Pictures/wallpaper2.png` and loaded through Hyprpaper with `fit_mode = cover`.

## Hyprlock

Snapshot:

```text
wayland/hypr/hyprlock.conf
```

Hyprlock is a session-preserving lock, not a logout. It uses a solid black terminal-style layout with no blur or animations. The date uses Waybar's UbuntuMono Nerd Font and textual weekday/month format; the time uses the same vector font, includes seconds, and is above the password field. The clock/date group is separated from the `LOCKED` label and password field by a wide gap, with `LOCKED` directly above the field. Fingerprint authentication is enabled through `fprintd`, with the normal password/PAM fallback retained.

Bound in Hyprland as:

```text
SUPER + L / SUPER + Escape -> hyprlock
CTRL + ALT + Delete -> lock screen, suspend, log out, or power off
```

Hypridle turns displays off after five minutes of inactivity and requests a Hyprlock session lock after ten minutes. It honors D-Bus, systemd, and Wayland idle inhibitors, so supported video playback does not trigger either timeout. It does not suspend the system for ordinary idle time; it only delays system sleep until Hyprlock confirms the Wayland session is locked, covering the Suspend menu action and closing the laptop lid. The Suspend menu row uses a local moon icon so it remains visible without relying on the installed icon theme.

## Mako notifications

Snapshot:

```text
wayland/mako/config
```

Current styling:

```text
font=UbuntuMono Nerd Font 12
default-timeout=5000
output=eDP-1
border-size=2
border-color=#033e8c
background-color=#000000cc
text-color=#d6d6d6
progress-color=#20a5ba
```

## Calendar

Calcurse opens in Alacritty through the familiar binding:

```text
SUPER + C -> alacritty -e calcurse
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

## Screen sharing

`xdg-desktop-portal-hyprland` remains the ScreenCast backend. Its default Qt picker is replaced with `hypr-share-picker`, a Rofi-based custom picker that preserves screen, window, and region selection while using the desktop launcher theme.

Snapshots:

```text
wayland/hypr/xdph.conf
wayland/bin/hypr-share-picker
wayland/rofi/share-picker.rasi
wayland/rofi/share-picker-icons/
wayland/systemd/user/xdg-desktop-portal-hyprland.service.d/share-picker.conf
```

The service drop-in adds `~/.local/bin` to the portal backend's PATH so the picker is resolved without hard-coding a username.
`share-picker.rasi` imports the normal Rofi theme, but makes only the share picker compact. Its rows use white SVG icons for screens and regions. Window rows resolve their application icon from desktop-entry metadata and fall back to the white window icon when no match exists.

## Waybar

Config snapshots:

```text
wayland/waybar/config.jsonc
wayland/waybar/style.css
wayland/bin/hypr-waybar-start
```

Live locations:

```text
~/.config/waybar/config.jsonc
~/.config/waybar/style.css
~/.local/bin/hypr-waybar-start
```

Current Waybar settings:

```jsonc
"height": 28
```

```css
font-size: 14px;
```

Current modules:

- left: nine Qtile-style workspaces and the active window for that output
- right: volume, backlight, network SSID, battery, clock, tray

`hypr-waybar-start` waits for the Wayland socket and a non-empty Hyprland monitor list before it starts Waybar. This avoids an output-readiness race without relying on a fixed delay.

The nine workspaces are visible on every output. Their custom Waybar buttons use Hyprland's Lua dispatcher, because the native Waybar module emits incompatible legacy dispatcher syntax for this session. A single event watcher updates cached workspace state before signaling the buttons, so a refresh needs two Hyprland queries rather than eighteen. Clicking one or pressing Alt/Super+1..9 brings it to the focused monitor and swaps visible workspaces when needed. Their order is Console, Agents, Firefox, Development, File Explorer, Mail, Messages, Entertainment, and Others. The focused workspace is blue, visible workspaces use the secondary background, and occupied workspaces use the active text color.

The clock shows the localized textual date (`%A, %d %B %Y`) and refreshes every second so its seconds stay current.

The `BAT0` module checks battery state every 15 seconds. While discharging, it turns yellow at 20% or below and red at 10% or below. Waybar sends a normal `Battery low` notification at 20% and a critical `Battery critical` notification at 10%; both expire after five seconds. The events re-arm after charging or plugging in, while restarting Waybar below a threshold can send that threshold's notification again. `libnotify` provides `notify-send` and Mako displays the notifications.

To reload Waybar manually:

```bash
pkill waybar && waybar &
```

## Rofi

Rofi is the application launcher and preserves the Qtile `SUPER + M` workflow:

```bash
rofi -show drun
```

`SUPER + A` opens `hypr-audio-selector` with the same compact Rofi theme as the screen-share picker. Its bottom mode switcher exposes Output and Input in one picker, so switching categories does not open a second dialog. It queries `pactl` when opened, so a TV or HDMI output appears as soon as WirePlumber exposes it, while unavailable analog jacks stay hidden. Selecting an item changes only the corresponding default device; active application streams are not moved.

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

Config snapshot:

```text
packages/yazi/
```

Live location:

```text
~/.config/yazi/
```

Yazi uses a three-pane layout, natural sorting with directories first, and the desktop's black/blue color palette. Text files open in Neovim; PDFs and media open in Evince and mpv. Image previews are disabled while browsing; press Enter on an image to render it with Chafa in the current terminal, then press any key to return to Yazi. Its built-in previewers use `ffmpeg`, `7zip`, `jq`, `poppler`, `resvg`, ImageMagick, and Ueberzug++ to show video, archive, JSON, PDF, SVG, and font previews in Alacritty under Hyprland.

Useful bindings:

```text
g h          -> Home
g d / g D    -> Documents / Downloads
g p / g m    -> Pictures / Music
g v          -> Videos
g c          -> ~/.config
g r / g a    -> repositories / this Arch configuration repository
g t          -> /tmp
g f          -> find files, including hidden files except .git
g /          -> search file contents with ripgrep
```

The `y` Zsh function starts Yazi and changes the parent shell into the directory selected on exit. Use `yazi` directly when that directory change is not needed.

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
