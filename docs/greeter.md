# Greeter

The installed greeter is `greetd` with `tuigreet`. Its tracked configuration is `greetd/config.toml`, installed to `/etc/greetd/config.toml` by `scripts/desktop.sh`.

`tuigreet` is configured through the `command` value in `/etc/greetd/config.toml`.
The most relevant options are:

- `--theme`: assigns ANSI color names to greeter UI roles.
- `--time` and `--time-format`: show and format the clock.
- `--greeting`: show custom text above the login prompt.
- `--width`, `--window-padding`, `--container-padding`, `--prompt-padding`: control layout spacing.
- `--greet-align`: aligns the greeting text.
- `--remember`, `--remember-session`, `--remember-user-session`: persist login/session choices.
- `--user-menu`, `--user-menu-min-uid`, `--user-menu-max-uid`: enable the user picker.
- `--sessions` and `--xsessions`: define session directories used by the session picker.
- `--power-shutdown` and `--power-reboot`: configure power actions.

In `tuigreet` 0.11.1, `--theme` uses Ratatui's color parser, which accepts names
and hex RGB values. Linux virtual consoles still reduce RGB escape sequences to
their 16-color palette. A real VM test with `border=#033e8c` rendered the old
ANSI blue (`#008ec4`), not the requested RGB. Therefore this configuration uses
named colors and explicitly manages the console palette.

The current theme echoes the GRUB terminal design:

- `blue` (`#033e8c`): container borders and action keybinding backgrounds, matching GRUB and the active Hyprland border.
- `lightcyan` (`#4fb8cc`): greeting and titles, matching the GRUB heading.
- `green` (`#10a778`): authentication prompts, not a custom selection arrow.
- `white` (`#f1f1f1`, bright-white slot 15): clock, typed input, base text, and action labels.
- `black` (`#000000`): container background.

The login panel is 60 columns wide, with two cells of container padding and one
row of prompt padding. With the 14x28 console font, its visible border spans
828 pixels at 1920x1200, compared with 739 pixels for the previous 68-column,
11x22 configuration. The greeting remains centered; placement otherwise follows
tuigreet's stock layout. Font sizes do not adapt automatically to resolution.

This is a text-console approximation, not the transparent GRUB panel. There is
no wallpaper or panel alpha in this theme, and it does not add a selection arrow.
The live ISO keeps its separate greeter configuration and
`live/airootfs/etc/vtrgb` unchanged; it does not deploy the installed profile's
`greetd/vconsole.conf`. Do not copy the installed session command or PAM setup
over the live profile merely to preview its appearance.

## Apply the Theme

Fresh desktop installations receive this configuration through `scripts/desktop.sh`.
On an existing installation, review differences first, especially session commands:

```bash
diff -u /etc/greetd/config.toml greetd/config.toml
```

From the repository root, use the single scoped helper after reviewing the session
settings. Host execution remains pending as of 2026-09-14:

```bash
sudo bash scripts/apply-greeter-theme.sh
```

The helper requires root and typed `APPLY` confirmation (`--help` does nothing).
It validates TOML without evaluating configuration as shell code, checks installed
tuigreet flags, the font, session launchers and mkinitcpio presets. It installs:

- `/etc/greetd/config.toml` (complete tracked session/theme configuration).
- `/etc/vtrgb` and `/etc/systemd/system/greetd.service.d/10-vtrgb.conf`.
- `/etc/vconsole.conf`, changing only `FONT` to `ter-v28b`, preserving KEYMAP and other settings.
- `/usr/local/libexec/archcfg-wayland-session-wrapper` and
  `/usr/local/libexec/archcfg-xsession-wrapper`, executable; the Wayland wrapper
  maps `Hyprland` to `/usr/bin/start-hyprland`.

All six originals (or absence markers) and original modes are backed up under a
unique `/var/lib/arch-linux-config/greeter-backups/` directory with mode 0700;
backup contents and diagnostics are private. Destination symlinks are rejected.
The helper runs `mkinitcpio -P` once, logging privately in that backup directory.
On failure it attempts to restore all six original files/modes, removing files
that were previously absent. Newly created empty parent directories may remain.
**Initramfs images are not backed up or restored**: generation can partially
update them before failing. Inspect `mkinitcpio.log`; do not reboot until
`sudo mkinitcpio -P` succeeds with the intended restored configuration.

It never modifies `/etc/pam.d/greetd`, preserving the existing fingerprint/PAM
setup. It does not run `setvtrgb`, `setfont`, service reloads/restarts, or reboot.
An ordinary future reboot loads the new font, palette, drop-in and greeter config;
a logout alone may not reload the daemon configuration. Run this helper before
the separate GRUB command, and only continue if initramfs generation succeeds:

```bash
sudo bash scripts/apply-grub-profile.sh --profile graphical --size large
```

Non-root fixture checks: `python3 tests/greeter-theme-helper.py` and
`bash tests/greetd-config.sh`. These do not exercise installed-system initramfs
generation or a host login. Existing VM validation is described below.

`tuigreet` 0.11.1 draws the selected user or session with a hard-coded reverse-video modifier. It has no theme component for the selection background, so it cannot be changed to blue through `--theme` without a custom patched build of `tuigreet`. The session picker retains its default white inversion (`#e0e0e0` in the VM), rather than recoloring session labels to imitate a supported selection setting.

The status-bar keybindings use the same hard-coded reverse-video modifier. `button=blue` therefore renders a blue fill behind the key label, while `action=white` renders its description. A blue key label with no fill also requires a patched `tuigreet`; the stock theme cannot express that combination.

This repo installs `greetd/vtrgb` to `/etc/vtrgb` and a `greetd.service` drop-in
that runs `setvtrgb /etc/vtrgb` before the greeter starts. Only blue slot 4 changed
from the previous palette, from `#008ec4` to `#033e8c`; the other 15 slots are
unchanged. The first color is true black (`#000000`). This palette operation
affects Linux virtual consoles globally, including blue shell output on other
TTYs. It does not alter Alacritty or any graphical terminal's palette.

`fbcon=nodefer` in both tracked GRUB profiles disables deferred framebuffer-console takeover. AMD KMS is already ready before `greetd` starts, but without this parameter `fbcon` can bind only when `tuigreet` first draws, causing a temporary-resolution redraw. The `greetd` drop-in no longer uses a fixed sleep.

## Session Output

Session programs otherwise inherit the greeter's `tty1` output streams, so expected teardown messages can appear on the shutdown console. The tracked wrappers keep that output in the user's state directory instead:

- `greetd/archcfg-xsession-wrapper` starts X11 sessions through `startx` and writes to `~/.local/state/arch-linux-config/xsession.log`.
- `greetd/archcfg-wayland-session-wrapper` launches the default Hyprland session through `start-hyprland` and writes to `~/.local/state/arch-linux-config/wayland-session.log`.

`tuigreet` uses `--xsession-wrapper` for X11 sessions and `--session-wrapper` for Wayland sessions. The latter covers both the default `--cmd Hyprland` command and Wayland sessions selected from the session menu. Qtile can therefore log X connection teardown messages, while Hyprland or its session launcher can log Wayland teardown messages, without either writing directly to `tty1`.

To add both wrappers to an existing host without restarting the current session:

```bash
sudo ./scripts/apply-greeter-xsession-wrapper.sh
```

The wrappers apply on the next greeter start, such as after a reboot.

## Greeting

`--greeting 'Sign in to your session'` is the centered, one-line greeting of the main login screen. This theme uses the greeting rather than enabling an additional form title.

## Clock

The clock format is `%A, %B %d, %Y - %I:%M %p`, for example
`Monday, September 14, 2026 - 08:59 PM`. It restores full weekday/month names
and the 12-hour clock, and includes the year. Names follow the process locale
(configured as `en_US.UTF-8`). The clock is outside the blue panel and is not
limited by its 60-column width. English dates fit within 85 columns at 1280x800
with the 14x28 font and existing window padding.

## Selected Session

`SESS` is a status label, not a physical key: the text following it is the
currently selected desktop session. `CMD` instead identifies the command used
when no desktop session is selected, initially `Hyprland` from `--cmd`.
`F3` opens the session picker; confirming a different session updates `SESS`.
Both status labels reuse the blue reverse-video keycap styling.

In 0.11.1, neither `--session-info` nor `--no-session-info` exists. The native
tuigreet configuration supports `layout.widgets.status_bar.show_session_status`
to hide the indicator, and `layout.widgets.status_position` to position the
whole bar at the top or bottom (or hide it). None places the selected session
inside the login panel. `--greeting` and `--custom-title` are literal text, not
live session templates. The current profile preserves the real status indicator
and F3 rather than hiding selection or hard-coding a potentially wrong name.
Moving that live value inside the blue panel requires an explicit custom-build
change; no patched executable is installed by this theme.

Source: [0.11.1 UI rendering](https://github.com/apognu/tuigreet/blob/0.11.1/crates/tuigreet/src/ui/mod.rs)
and [configuration schema](https://github.com/apognu/tuigreet/blob/0.11.1/crates/tuigreet-config/src/schema.rs).

## Console font

`tuigreet` runs on a Linux virtual terminal, so it uses a bitmap console font rather than Alacritty's scalable `UbuntuMono Nerd Font` setting. The tracked `greetd/vconsole.conf` installs:

```ini
KEYMAP=la-latin1
FONT=ter-v28b
```

`ter-v28b` is Terminus Bold with 14x28-pixel cells, replacing the previous
11x22-pixel `ter-v22b`. Arch's existing `terminus-font` dependency provides
`/usr/share/kbd/consolefonts/ter-v28b.psf.gz` (PSF2, 512 glyphs). No font generator,
bundled TTF, additional package or new font license is needed for this change.

The desktop profile installs `kbd` for console tooling and `terminus-font`, which provides this font, then rebuilds the initramfs after installing `/etc/vconsole.conf`. The existing `sd-vconsole` mkinitcpio hook loads it during early userspace; `systemd-vconsole-setup` also applies it to available text virtual terminals after boot.

This configuration affects Linux TTYs, including the one used by `tuigreet`. It does not change Alacritty's font or palette.

To apply a font-only change to an existing host without restarting the current session:

```bash
sudo ./scripts/apply-greeter-font.sh
```

The script reads the tracked `greetd/vconsole.conf`, installs it as
`/etc/vconsole.conf`, and rebuilds initramfs. It does not generate a PSF or load
the font into the running console. Review/back up `/etc/vconsole.conf` first:
the helper replaces that file, including its `KEYMAP=la-latin1` setting. The new
font takes effect on a future reboot and affects all configured Linux TTYs, not
just the greeter. No host deployment was performed during development.

## Runtime Validation

On 2026-09-14, the exact installed configuration, palette and font were tested on
a real VirtualBox VT at 1920x1200 and 1280x800 using an existing live ISO overlay,
not a rebuilt ISO or full installed-system cold boot. The package was
`greetd-tuigreet 0.11.1-2`; its binary reports `tuigreet 0.11.0`. The active font
was queried through the kernel console-font ioctl and confirmed as 14x28.
Original VirtualBox screenshots confirm border RGB `(3, 62, 140)`, cyan greeting,
green prompts, white input, and the stock session-selection inversion.

At 1280x800 the form and session picker fit, but the stock footer truncates the
trailing session name at this font size. Its visible actions still work. This is
a 1920x1200-oriented size, not automatic responsive typography; smaller modes
have not been validated. A smaller console font is a global TTY tradeoff, not
an independent footer setting. No session labels were shortened to hide this.

Real PAM authentication, Hyprland startup and return to the remembered greeter
were checked. Alternative UWSM/X11 session startup and initramfs font loading on
an installed-system reboot are outside this visual test.

The full-date revision was tested again in a new disposable VM (2 CPUs, 3072 MiB).
Fresh, unmodified screenshots and kernel-font verification logs are retained at
`/tmp/opencode/greeter-full-date-20260914/`. The full clock fits at both tested
resolutions. F3 selection of UWSM updates the real footer at 1920x1200; at
1280x800 the session name is clipped, although the picker still shows it in full.
Hyprland authentication and return to the remembered greeter passed at 1920x1200.
The live overlay reported a `systemd-networkd-wait-online` timeout, but SSH and
the greeter worked. No installed-system boot or UWSM startup was tested in this
revision. The disposable VM and its temporary credentials were removed afterward.

Reference: <https://github.com/apognu/tuigreet>
