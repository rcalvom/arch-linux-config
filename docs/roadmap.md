# Roadmap

## v0.1

- Bootable UEFI VM install.
- Explicit destructive mode with `--vm --disk`.
- Minimal base system, user creation, GRUB, IWD, systemd-networkd, and systemd-resolved.

## v0.2

- Safe install mode using a mounted target.
- No disk operations outside VM mode.

## v0.3

- Package profiles: `minimal`, `desktop`, `developer`, `virtualbox`.
- Wayland/Hyprland as the desktop target.

## Later

- Broader hardware support.
- Conservative `apply-config.sh` for existing Arch installs.
- Expand optional AUR support after the core flow is reliable.
- Expand the current live ISO into a more complete test/recovery environment after VM installs are stable.

## Deferred Complex Work

The items below are deliberate limitations rather than missing one-line settings. Each needs a recovery plan, a tested migration path, or upstream changes before it becomes part of the generic installer.

### Existing-Host GRUB And Boot Paths

The tracked graphical and classic profiles can be switched through the documented GRUB helper, but broad live-host bootloader management is intentionally out of scope. EFI entries, kernel command lines, multi-boot installations, encrypted roots, swap-resume parameters, firmware behavior, and bootable recovery media all need hardware or VM validation. A generic apply step must not overwrite an existing boot path merely because a repository profile differs. See [GRUB profiles](grub.md).

### Hyprlock Fingerprint Status

Hyprlock 0.9.6 can leave `$FPRINTPROMPT` at its last scan message after its native fprintd verifier stops retrying. The lock screen keeps the live prompt by choice, while `$FAIL` shows the actual password or fingerprint failure in red for four seconds. Hyprlock has no declarative condition that can hide the prompt only when fingerprint authentication is unavailable; correcting that behavior requires an upstream fix or a maintained local Hyprlock patch.

### Rofi Icon Cache Invalidation

Rofi reloads desktop entries through `drun-reload-desktop-cache`, but application icons also depend on the selected icon theme, GTK icon-cache state, and Rofi's per-process lookups. The share picker uses local SVG paths for its fixed icons because Adwaita symbolic assets have unsuitable hard-coded fills. A general cache reset is not automated: it could hide or overwrite third-party theme and desktop-entry state. A future solution needs a targeted, testable invalidation path for changed application or icon-theme assets.

### Storage Encryption, Hibernation, And Backups

The current installer targets a simple unencrypted ext4 root and EFI layout. Converting an existing host to LUKS2, or adding encrypted swap, requires a disk migration, initramfs and bootloader changes, an updated `resume=` kernel parameter, and tested restoration before Hibernate can be enabled safely. A full backup and bare-metal restore policy also remains undecided because it needs an encrypted destination, retention rules, credentials handling, and regular restore tests.

### Hyprsunset Session Teardown

Hyprsunset is a user service that can outlive a directly launched Hyprland session briefly. If the compositor disappears first, Hyprsunset may abort and retry before systemd stops the graphical session target. The visible session output is redirected away from `tty1`, but a clean teardown needs either upstream handling of compositor disconnects or a different session lifecycle model. Do not hide the failure by disabling recovery for unrelated service errors.
