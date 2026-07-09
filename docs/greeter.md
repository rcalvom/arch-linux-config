# Greeter

The installed greeter is `greetd` with `tuigreet`.

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

To make those ANSI names match the Alacritty palette on the Linux virtual console, this repo installs `greetd/vtrgb` to `/etc/vtrgb` and a `greetd.service` drop-in that runs `setvtrgb /etc/vtrgb` before the greeter starts. The first ANSI color is kept at true black (`#000000`) so `container=black` renders as a deep black background.

The same drop-in waits briefly before launching `greetd`. This avoids an early `tuigreet` draw at the temporary boot console size before KMS finishes resizing the TTY.

Reference: <https://github.com/apognu/tuigreet>
