# Desktop Runtime Fixes

## Display Profiles

Without configuration, `hypr-display-layout` defaults to generic extended mode:
the internal connector first, then external displays sorted by identity. Explicit
`extend` selections survive restart. Enabled outputs must report positive width
and height before convergence succeeds or other outputs can be disabled.

Optional mapping selected only with `--hardware-profile ricardo` in
`install.sh` or `apply-config.sh` (never selected by `--module all`):

| Repository source | User destination | Mode |
| --- | --- | --- |
| `hardware/ricardo/display-profiles.json` | `~/.config/archcfg/display-profiles.json` | `0644` |

Install this file only for the existing Ricardo hardware setup, not as a generic
default. `HYPR_DISPLAY_PROFILES` can explicitly select another JSON file. Missing
default configuration means no hardware profiles; invalid configuration or a
missing explicitly selected file fails before any monitor operation.

Tablet-to-`eDP-1` mapping is included only in the personal profile's
`~/.config/archcfg/hardware.lua`. The canonical Lua configuration loads that
optional file; generic installations do not map tablets to a nonexistent output.
The legacy `hyprland.conf` remains a reference, not an installed configuration.

The version 1 JSON contains `profiles`, keyed by stable profile IDs, with `label`,
`description`, and `rows`. Rows are horizontally centered relative to the widest
row and stacked using logical dimensions. Selectors accept `connector:`, exact
`description:`, and unambiguous `description-prefix:`. The optional file retains
the shipped `dock-three-screen` and `desk-three-screen` layouts and prefix matching,
but duplicate matches are rejected instead of choosing the first output.

The saved-state path and version remain unchanged:
`${XDG_STATE_HOME:-~/.local/state}/archcfg/display-layout.json`. Legacy connector
and description selections remain readable. Saved profile IDs survive missing
configuration or hardware; reconciliation temporarily extends without overwriting
the saved selection. Restoring the optional file restores those profile choices.

## Window Logging

Window event logging is disabled by default. For temporary diagnosis, launch the
watcher with `HYPR_WINDOW_EVENT_LOG=1`. This explicitly permits titles in
`~/.local/state/archcfg/hypr-window-events.log`. Payloads are truncated to 1024
characters; the current log and one rotated `.log.1` file each hold at most 1 MiB
under the normal single-watcher session model. Files use mode `0600`. Existing
logs are not deleted automatically; disabling logging does not erase old titles.

## Hyprsunset

`hyprsunset-set` now uses Python 3 (already required by the desktop helpers).
It selects a live session from `hyprctl -j instances`, respecting any supplied
instance signature and Wayland display. No matching live session is an expected
timer no-op. Multiple matches fail without starting the service. Discovery errors
remain errors. Environment import and service startup happen only after selection.
IPC readiness has a five-second deadline; subprocess calls also have timeouts.
Day and night oneshot units have a 30-second startup limit.
The observed Hyprland 0.56 empty-instance response (`]`) is normalized to an
empty list; other malformed discovery responses remain errors.

## Verification

Run `bash tests/hypr-display-layout.sh` and `python3 -B tests/hypr-desktop.py`.
Tests mock IPC, process execution, session discovery, clocks, and socket checks;
state and diagnostic logs use temporary directories. No deployed configuration,
live monitors, credentials, or service state are modified.
