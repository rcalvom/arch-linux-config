# Roadmap

Status reviewed November 1, 2026. Implementation status does not certify a fresh
installation; see [validation evidence](validation.md) for tested scope.

## Implemented

- Explicit UEFI VM installation with `--vm --disk`, target validation, base
  installation, user creation, GRUB, and network services.
- Safe installation on a validated, manually mounted target.
- `minimal`, `desktop`, `developer`, and `virtualbox` profiles, optional package
  sets, an opt-in personal recipe, and separate hardware profiles.
- Hyprland configuration, service setup, and manifest-based file deployment.
- Conservative `apply-config.sh` previews, backups, and conflict-aware rollback.
- Optional archiso builds and disposable VirtualBox build/install runners.
- Revision-pinned optional AUR recipes with explicit build dependencies.
- Headless Calcurse regression coverage and a fix for inherited session locks.
- A shared local check command and GitHub Actions workflows for regressions,
  error-level ShellCheck, and credential scanning. Remote execution remains to
  be verified.

## Validation and Release Work

- [x] Run the isolated local regression suite, including Calcurse.
- [x] Verify the official bootstrap ISO signature and VirtualBox preflight.
- [ ] Complete a fresh ISO build and installation/reboot checks in both VM and
  safe modes; retain source hashes and mode-specific evidence.
- [ ] Verify the published GitHub Actions runs and address lint failures.
- [x] Review all 17 AUR pins and source availability; repair Spotify's unavailable
  download after signature and checksum verification.
- [ ] Build automatic AUR selections in a disposable current Arch environment.
- [x] Document tools installed outside pacman and their reconstruction limits.
- [x] Index operational guides separately from personal selections and historical
  run records. New commands belong in guides; dated results belong in evidence.
- [ ] Establish provenance and redistribution terms for remaining wallpapers
  and GRUB icon masks; see [asset review](assets.md).
- [ ] Broaden hardware validation beyond the existing VM and host observations.

## Deferred Integrations and Maintenance

- Google Drive MCP remains deferred; external integrations remain disabled by
  default and require task-specific authorization.
- Design a project-local environment for `rzstyle` and review overlapping user
  Python packages before migration.
- Add the requested help bar inside Yazi. The optional portal file chooser is
  configured separately and is not part of the automatic recipe.
- Expand the live ISO's recovery tools after fresh installation checks pass.
- Recheck dated host findings in the [maintenance backlog](maintenance-backlog.md)
  before changing an existing machine.

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
