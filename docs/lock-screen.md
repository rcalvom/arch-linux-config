# Lock Screen

## Review status

The visual design from `wayland/hypr/hyprlock.conf` was deployed only to
`~/.config/hypr/hyprlock.conf` on 2026-09-14 at 19:21 -04:00 (host clock).
The personal candidate preserves the complete original `general`, `auth`, and
`animations` blocks, including fingerprint enabled and default PAM, and the exact
`password or fingerprint` placeholder. The generic repository template is unchanged.
The deployed file matches the personal candidate byte for byte, mode 0644, owner
1000:1000; the original was a regular file, not a symlink.

Private local backup (directory 0700, original and candidate 0600):
`/home/ricardo/.local/state/hyprlock-theme-20260914.bthAsznj/`.
`hyprlock.conf` is the original; `candidate.conf` is the deployed version.
The readable existing wallpaper matches the repository asset and was not replaced.
PAM, Hypridle, host services, GRUB, greeter and other desktop files were not changed.
No host Hyprlock invocation, logout or service restart was performed. The next
ordinary lock reads this design; host password/fingerprint runtime checks remain pending.

## Design

- Native Hyprlock widgets over `$HOME/Pictures/wallpaper2.png`, without blur,
  animations, or dimming outside the panel. The managed wallpaper is
  `wayland/wallpapers/wallpaper.png`.
- A centered 94% x 94% black panel at 80% opacity approximates GRUB's frame
  proportions. Hyprlock 0.9.6 adds the 2 px `#033e8c` border outside that size,
  so the outer margins are 3% minus 2 logical pixels, before raster rounding.
  Corners are square.
- UbuntuMono Nerd Font: cyan bold `Session locked` at size 36, white 12-hour
  clock with seconds at 48, and a separate full English date at 22. Centers are
  offset by +175, +75, and -5 logical pixels; the captured clock/date glyphs
  have more than 32 px of clear separation. Both date commands use `LC_TIME=C`
  and inherit the session timezone.
- A centered 460 x 48 password field at -85, with a green idle outline, cyan
  checking state, and native red `$FAIL` feedback for four seconds. The heading
  stays visible during errors. No user names or desktop contents are exposed.
- No keyboard-layout labels, Caps Lock hints, or Caps-specific color overrides.
- All widgets repeat on each output. The supported minimum is 640 x 480 logical
  pixels; fractional scaling reduces available logical space.

## Margin investigation

A read-only host check on 2026-09-14 selected the sole Hyprland instance via
`HYPRLAND_INSTANCE_SIGNATURE` and queried `hyprctl monitors all -j`, retaining
only output names, dimensions, scales, and transforms. It returned only `eDP-1`,
1920 x 1200, scale 1, transform 0. The installed panel still uses `94%, 94%`,
border size 2, zero position, and centered alignment; fingerprint remains enabled.

Upstream v0.9.6 [`Shape.cpp`](https://github.com/hyprwm/hyprlock/blob/v0.9.6/src/renderer/widgets/Shape.cpp)
centers `size + 2 * border`. Its layout values are percentages of each output's
viewport, not the combined desktop. At the inspected scale, the theoretical outer
margins are 55.6 px horizontally and 34 px vertically, rather than 57.6 and 36.
These are source-derived values, not new screenshot measurements.

The v0.9.6 [`ConfigManager.cpp`](https://github.com/hyprwm/hyprlock/blob/v0.9.6/src/config/ConfigManager.cpp)
registers no shape `border_position` option and its layout parser does not evaluate
`calc()` expressions. Neither is a supported inset-border fix. The installed
CLI also exposes no parse-only validation option. The static test passes, but
does not establish the cause of a larger visual discrepancy. A user-provided
lock-screen image is needed before changing the geometry. No host lock, capture,
configuration edit, or restart was performed during this investigation.

## Fingerprint opt-in

The generic template sets `auth.fingerprint.enabled = false`; PAM remains enabled
by Hyprlock's default. There is no new include file or hardware-profile deployment
to accidentally change authentication. On an already configured fingerprint host,
the reviewed personal candidate must retain `enabled = true` in that block.

The active `~/.config/hypr/hyprlock.conf` inspected on 2026-09-14 already has:

```ini
auth {
    fingerprint {
        enabled = true
        ready_message = Scan fingerprint to unlock
        present_message = Scanning fingerprint...
        retry_delay = 250
    }
}
```

It also has `hide_cursor = true`, `fail_timeout = 4000`, a fingerprint-aware
password placeholder, and `$FPRINTPROMPT`. Preserve these authentication/general
settings when adopting the visual design, rather than copying the generic
disabled default over the working host configuration.

The candidate displays native `$FPRINTPROMPT` at size 16 below the password field
and `$FPRINTFAIL` at size 13 on a separate line below it. The prompt tells the user
to scan only when the backend provides that message; the field remains `Password`
so it does not promise an available reader. A personal placeholder may retain
`Password or fingerprint`, but that text is static, not device detection.

Checked against upstream Hyprlock v0.9.6
[`IWidget.cpp`](https://github.com/hyprwm/hyprlock/blob/v0.9.6/src/renderer/widgets/IWidget.cpp)
and [`Fingerprint.cpp`](https://github.com/hyprwm/hyprlock/blob/v0.9.6/src/auth/Fingerprint.cpp):

- Both fingerprint tokens are native, force-updated values, empty without backend
  text. With fingerprint disabled, both lines are blank.
- The ready prompt is set after verification starts successfully. Missing service,
  missing device, or claim failures may only be logged, leaving no visible prompt.
  A blank line is not proof that a reader is ready.
- `$FPRINTFAIL` is the backend's last failure, not a conditional availability
  indicator; it can persist alongside a retry prompt. Some terminal failure paths
  can also leave the previous prompt visible. Native text is not rewritten to
  claim success or current reader availability.

No fake reader, enrollment, PAM edits, grace period, or authentication bypass is
included. Fixed UI text is English; backend diagnostics may follow its locale.

## Isolated validation

On 2026-09-14 a new disposable VirtualBox VM used the existing
`recipe-20260914-c` ISO, 2 CPUs, 3072 MiB RAM, software rendering, and a synthetic
`preview` account. Hyprlock 0.9.6 ran on Hyprland with UbuntuMono Nerd Font. The
exact generic candidate and wallpaper were copied to the guest. Guest
`/etc/pam.d/hyprlock` matched the immutable ISO file with `cmp`.

Actual locked captures were reviewed at 1920 x 1200, 1280 x 800, and 640 x 480.
The frame fits and the title, clock, date, and input do not overlap. Wrong
passwords were rejected; correct passwords returned exit status 0, removed
Hyprlock, and preserved Hyprland PID 1573. A guest keyboard shortcut worked after
unlocking. No Hyprlock configuration errors were observed.

One runtime limitation was observed: after live output resizing, the red error
outline appeared but its text was blank despite the log reporting the native
failure string. A fresh lock at 1920 x 1200 displayed `Authentication failed`
correctly. Authentication still rejected wrong passwords and accepted the correct
one after resizing. Do not treat this test as full hotplug/error-rendering coverage.

Evidence is outside Git:

```text
/tmp/opencode/hyprlock-frame-20260914/
  locked-1920x1200.png
  locked-1280x800.png
  locked-640x480.png
  wrong-password-1920x1200.png
  fingerprint-visual-only-1920x1200.png
  hyprlock-1920x1200.log
  hyprlock-resize.log
  hyprlock-fresh.log
  hyprlock-final.log
  hyprlock-final-resize.log
  tested-hyprlock.conf
  fingerprint-visual.conf
  validation.md
```

The fingerprint visual-only capture uses a guest-only static label with the host's
ready-message wording and the candidate's typography/position. It is an actual
Hyprlock capture, but **not a native fingerprint prompt or a hardware test**. The
generic captures contain no simulated fingerprint text. No screenshot was
retouched. Old captures under `hyprlock-20260914` show the superseded small card.

Physical fingerprint hardware, GPU behavior, fractional scaling, and multiple
outputs remain untested. The disposable VM and one-use credentials are removed
after evidence collection; the three pre-existing VMs are left alone.

Run the non-locking regression checks from the repository root:

```bash
python3 tests/hyprlock-config.py
python3 tests/preferences-portable.py
```

The static test checks design/security invariants and date formatting, not the
Hyprlang parser or authentication.

## Manual adoption

Review the captures first. Do not use a broad `desktop --replace` deployment for
this change. `wayland/files.conf` already maps the candidate to
`~/.config/hypr/hyprlock.conf`; existing shortcuts and Hypridle need no changes.

Compare the candidate with the local configuration:

```bash
diff -u "$HOME/.config/hypr/hyprlock.conf" wayland/hypr/hyprlock.conf
```

Prepare a separate personal candidate preserving the current `general`, `auth`,
and any other security-related options. For the inspected host, retain fingerprint
enabled with its existing messages and retry delay directly in the `auth` block. Do not
edit PAM or change Hypridle to adopt this appearance.

Only after that separate file is approved, the scoped copy procedure is:

```bash
candidate=/absolute/path/to/reviewed-hyprlock.conf
target="$HOME/.config/hypr/hyprlock.conf"
test -f "$candidate" && test -f "$target" && test ! -L "$target" || exit 1
test "$(stat -c %u "$target")" = "$(id -u)" || exit 1
backup=$(mktemp -d "$HOME/.local/state/hyprlock-theme.XXXXXXXX") || exit 1
chmod 700 "$backup" && install -m600 -- "$target" "$backup/hyprlock.conf" &&
install -m644 -- "$candidate" "$target"
```

The scoped deployment above was executed with a separately validated personal
candidate. It did not lock the host, restart the compositor, or replace the
wallpaper. Test password and the locally enabled fingerprint path
at a convenient time before relying on the new screen for unattended locking.
