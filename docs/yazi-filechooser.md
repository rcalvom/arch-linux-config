# Optional Yazi File Chooser

## Status

On October 30, 2026, the host was configured to open Yazi in Alacritty for the
FileChooser portal. Ricardo confirmed that the Firefox interaction was useful.
The portal service started successfully; save dialogs, directory selection and
every other application have not been exhaustively tested. The proposed help
bar inside the TUI is still pending.

This is an optional host integration, not a package/configuration deployed by
the installer. It affects applications using the FileChooser portal, potentially
including VS Code, rather than Firefox alone. No Firefox profile changes were
needed for the host trial.

## Package and Source Review

```bash
yay -S --needed xdg-desktop-portal-termfilechooser-hunkyburrito-git
```

The installed AUR checkout was reviewed at revision
`0d886647371e594fa1b78db9c54739cb4a7e5287`. Its PKGBUILD declares
`xdg-desktop-portal` and `libinih` dependencies, with `meson`, `scdoc` and `git`
for building. It builds with Meson/Ninja and ships the Yazi wrapper and a user
service. The source is a moving upstream Git branch with `sha512sums=('SKIP')`:
pinning this AUR revision alone would not reproduce the same source. Keep it out
of the automatic recipe until upstream source pinning is implemented and tested.

References:
- [Yazi documentation](https://yazi-rs.github.io/docs/tips/#system-chooser)
- [Portal backend](https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser)

## Reproduce the Host Trial

The original host had neither of these personal configuration directories. Its
system configuration in `/usr/share/xdg-desktop-portal/hyprland-portals.conf` was:

```ini
[preferred]
default=hyprland;gtk
```

On another machine, inspect and back up existing personal portal configuration
first. The following example refuses to replace either configuration file.
Run it as the desktop user after installing the backend, Alacritty and Yazi.
The repository's `~/.local/bin/yazi` launcher remains first in PATH so its Chafa
preview behavior is preserved.

```bash
(
  set -euo pipefail
  portal_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
  chooser_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal-termfilechooser"
  test ! -e "$portal_dir/portals.conf"
  test ! -e "$chooser_dir/config"
  mkdir -p "$portal_dir" "$chooser_dir"
  set -o noclobber
  printf '%s\n' \
    '[preferred]' \
    'default=hyprland;gtk' \
    'org.freedesktop.impl.portal.FileChooser=termfilechooser' \
    > "$portal_dir/portals.conf"
  printf '%s\n' \
    '[filechooser]' \
    'cmd=/usr/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh' \
    "default_dir=$HOME" \
    'create_help_file=0' \
    'env=TERMCMD=/usr/bin/alacritty --title Yazi-FileChooser -e' \
    "env=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    'open_mode=suggested' \
    'save_mode=suggested' \
    > "$chooser_dir/config"
)
```

Once ready to interrupt any active portal dialogs or screen-sharing sessions:

```bash
systemctl --user restart xdg-desktop-portal.service
systemctl --user is-active xdg-desktop-portal.service xdg-desktop-portal-termfilechooser.service
```

Open Firefox's Ctrl+O dialog. Space marks files, Enter confirms, and Shift+Q
aborts the chooser. Multiple selection depends on the requesting application.
In normal Yazi usage, `a` creates an entry: end its name with `/` for a directory.
The title above is a terminal window title, not an in-TUI help bar.

## Restore the Original Host Behavior

For the trial described here, only the following files were added:

- `~/.config/xdg-desktop-portal/portals.conf`
- `~/.config/xdg-desktop-portal-termfilechooser/config`

Move those two files out of their configuration directories, preserving them
for possible reuse. With no personal override, Hyprland again uses the system
`default=hyprland;gtk` configuration. If reverting a different machine, restore
its own prior configuration instead.

```bash
(
  set -euo pipefail
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  backup=$(mktemp -d "$HOME/yazi-filechooser-disabled.XXXXXX")
  mv -- "$config_home/xdg-desktop-portal/portals.conf" "$backup/portals.conf"
  mv -- "$config_home/xdg-desktop-portal-termfilechooser/config" "$backup/chooser-config"
  systemctl --user restart xdg-desktop-portal.service
  systemctl --user stop xdg-desktop-portal-termfilechooser.service
  printf 'Disabled chooser configuration saved to %s\n' "$backup"
)
```

Retest Firefox's Ctrl+O dialog. GTK and Hyprland portal packages were preserved.
Optionally remove just the backend after reverting the configuration:

```bash
sudo pacman -R xdg-desktop-portal-termfilechooser-hunkyburrito-git
```

These steps do not remove Yazi's theme, keymap, previews, launcher or user files.
