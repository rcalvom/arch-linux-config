# Qtile Fallback

Qtile is a temporary X11 fallback while Hyprland is being stabilized. It is not installed by the current desktop profile, but an existing host can still select it from tuigreet's X11 session list.

## Session Selection

Tuigreet uses `--remember-session`, so selecting Qtile once causes it to be launched again at the next login. Choose Hyprland from the session menu when it is ready to become the active desktop again.

## Stable Startup

The live `~/.xprofile` mirrors `qtile/xprofile` in this repository. It starts one Picom instance with `~/.config/picom/picom.conf`, which mirrors `qtile/picom.conf`. That file inherits `/etc/xdg/picom.conf` but sets `fading = false`, preserving the current shadows while making open, close, and opacity changes immediate. It also detects connected external displays dynamically. When a dock is attached, it arranges connected external displays to the right of the internal display with one RandR transaction.

Do not use a static list of connector names such as `DP-8` and `DP-9`, and do not invoke `qtile reload_config` from `.xprofile`. Both run after Qtile has started and cause redundant screen reconfiguration and visible flicker.

The temporary Qtile network widget must use the current interface name, `wlan0`. The historical `wlp2s0` value raises an exception on every widget poll.

## Workspace Order

The nine Qtile groups, in bar order, are Console, Agents, Firefox, Development, File Explorer, Mail, Messages, Entertainment, and Others.

## Verification

Log out and select Qtile once. On the laptop display, there should be no post-login RandR reconfiguration. With a dock connected, Qtile should redraw once as the detected external displays are arranged. Check `~/.local/share/qtile/qtile.log` if a widget or X11 error persists.
