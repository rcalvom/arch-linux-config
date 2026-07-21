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

The `--theme` option does not accept the Alacritty hex palette directly. It maps UI roles to ANSI color names such as `blue`, `cyan`, `lightblue`, `lightcyan`, `white`, and `black`.

The current theme deliberately uses only blue, white, and black:

- `blue` (`#008ec4`): container borders, titles, and action keybindings.
- `white` (`#e0e0e0`): greeting, clock, prompts, typed input, base text, and action labels.
- `black` (`#000000`): container background.

`tuigreet` 0.9.1 draws the selected user or session with a hard-coded reverse-video modifier. It has no theme component for the selection background, so it cannot be changed to blue through `--theme` without a custom patched build of `tuigreet`.

The status-bar keybindings use the same hard-coded reverse-video modifier. `button=blue` therefore renders a blue fill behind the key label, while `action=white` renders its description. A blue key label with no fill also requires a patched `tuigreet`; the stock theme cannot express that combination.

To make those ANSI names match the Alacritty palette on the Linux virtual console, this repo installs `greetd/vtrgb` to `/etc/vtrgb` and a `greetd.service` drop-in that runs `setvtrgb /etc/vtrgb` before the greeter starts. The first ANSI color is kept at true black (`#000000`) so `container=black` renders as a deep black background.

`fbcon=nodefer` in `grub/grub` disables deferred framebuffer-console takeover. AMD KMS is already ready before `greetd` starts, but without this parameter `fbcon` can bind only when `tuigreet` first draws, causing a temporary-resolution redraw. The `greetd` drop-in no longer uses a fixed sleep.

## X11 Shutdown

When `poweroff` stops the X11 session, Xorg exits successfully and Qtile loses its X connection during teardown. Qtile can log `ConnectionException` messages at that point even though Xorg did not crash. `greetd/archcfg-xsession-wrapper` starts X11 sessions through `startx` and redirects their terminal output to `~/.local/state/arch-linux-config/xsession.log`, keeping expected teardown traces off the shutdown console.

To add the wrapper to an existing host without restarting the current session:

```bash
sudo ./scripts/apply-greeter-xsession-wrapper.sh
```

The wrapper applies on the next greeter start, such as after a reboot.

## Greeting

`--greeting 'Welcome to Arch Linux'` is the centered, one-line title of the main login screen. `tuigreet` does not provide a separate title widget for that screen.

## Clock

The clock format is `%A, %B %d - %I:%M %p`, which renders as `Wednesday, July 15 - 10:06 PM` with the configured `en_US.UTF-8` locale. `%A` and `%B` render the weekday and month names.

## Console font

`tuigreet` runs on a Linux virtual terminal, so it uses a bitmap console font rather than Alacritty's scalable `UbuntuMono Nerd Font` setting. The tracked `greetd/vconsole.conf` installs:

```ini
KEYMAP=la-latin1
FONT=ter-v22b
```

`ter-v22b` is the bold 22-pixel Terminus console font. It keeps the size of `ter-v22n` while using thicker glyphs. It replaces `sun12x22`, whose glyph style did not match the desired terminal appearance. `terminus-font` provides this font.

The desktop profile installs `kbd` for console tooling and `terminus-font`, which provides this font, then rebuilds the initramfs after installing `/etc/vconsole.conf`. The existing `sd-vconsole` mkinitcpio hook loads it during early userspace; `systemd-vconsole-setup` also applies it to available text virtual terminals after boot.

This configuration affects Linux TTYs, including the one used by `tuigreet`. It does not change Alacritty's font or palette.

To apply a font-only change to an existing host without restarting the current session:

```bash
sudo ./scripts/apply-greeter-font.sh
```

The script installs `/etc/vconsole.conf`, rebuilds initramfs, and requires a reboot before the greeter uses the new font.

Reference: <https://github.com/apognu/tuigreet>
