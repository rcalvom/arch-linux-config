# Configuration Inventory

This repository is the canonical source for configuration required to rebuild the system. A file is not part of a reproducible reconstruction point until its intended change is committed to Git.

## Capture Rule

For every persistent configuration change:

1. Update the canonical source in this repository before or alongside the active host file.
2. Add the deployment mapping through `packages/*/files.conf` or `scripts/dotfiles.sh`.
3. Add required packages to the active package profiles and `live/packages.x86_64` when the live ISO needs the feature.
4. Document user-visible behavior in the relevant README or this document.
5. Validate the source and run the verifier before committing the intended change.

Do not commit credentials, browser profiles, application caches, shell history, generated desktop IDs, or machine-local service state. Store a sanitized template and documented provisioning steps instead.

Use the [personal setup recipe](ricardo-setup.md) for reconstruction decisions, the [deployment matrix](host-deployment.md) for dated implementation/ISO/host evidence and the [recovery inventory](recovery.md) for private state and first login. A frozen worktree snapshot can identify a historical test artifact without proving that later source changes were validated or deployed.

## Managed User Configuration

`packages/*/files.conf` deploys per-application files, including Alacritty, Calcurse, Firefox and Thunderbird launchers/templates, Neovim, Oh My Zsh, tmux, VS Code, and Yazi. The tmux manifest installs `~/.tmux.conf` with the Alacritty normal blue (`#008ec4`) status background and bright-white (`#f1f1f1`) text.

Both installed-system deployment in `scripts/dotfiles.sh` and live-session deployment in `live/airootfs/usr/local/bin/archcfg-live-session` consume these manifests. The live image carries and deploys the tmux configuration but deliberately does not add tmux to the lightweight live package set. The `ricardo` installation recipe installs tmux on the target system.

`scripts/dotfiles.sh` deploys the Wayland configuration:

- Hyprland, the portal configuration, Hyprlock, Hyprpaper, and Hyprtoolkit.
- Waybar, Rofi, Mako, Fontconfig, wallpaper, user systemd units, and their timer enablement links.
- All helpers in `wayland/bin/`.
- `wayland/mimeapps.list` as a baseline for a fresh account.

The active Hyprland source is `wayland/hypr/hyprland.lua`; `hyprland.conf` remains a legacy reference only.

`scripts/apply-printing.sh` generates `~/.cups/client.conf` from a private configuration supplied with `--config`. The tracked `printing/printing.conf` is empty and cannot configure a site or account until explicitly provisioned. Keep the local configuration and generated client file out of Git. See [Printing](printing.md) for provisioning and historical privacy limits.

### Firefox Internal Page Styling

See the [Firefox CSS customization guide](../packages/firefox/README.md) for the
palette, managed files, deployment, temporary disabling and update checks.

The Firefox template separates browser controls from internal page content:

- `packages/firefox/profile-template/chrome/userChrome.css` styles the browser
  toolbars and tabs with square controls and blue accents.
- `packages/firefox/profile-template/chrome/userContent.css` applies blue accents
  and square controls to session restoration and the built-in PDF viewer.
  Updating `userChrome.css` alone does not style these content documents.
- `packages/firefox/profile-template/user.js` enables
  `toolkit.legacyUserProfileCustomizations.stylesheets`.

The manifest deploys the template to `~/.local/share/archcfg/firefox-template`.
The `archcfg-firefox` launcher copies both stylesheets into the selected profile's
`chrome/` directory before starting Firefox. Fully exit Firefox and reopen it
after changing either stylesheet; reloading a tab is insufficient.

The content rules identify session restoration by its
`chrome://browser/skin/aboutSessionRestore.css` stylesheet and PDF.js by
`resource://pdf.js/web/viewer.css`. PDF.js keeps the opened document's URL, so
matching only a `resource://pdf.js/` document URL would miss ordinary PDF tabs.
Color overrides respect forced-colors mode. Ordinary websites are outside the
intended scope of these selectors.

On 2026-10-05, CSS parsing, launcher syntax, deployment-copy equality and
`git diff --check` passed. Ricardo confirmed that the visual fix worked after
restarting Firefox. If a Firefox update changes the internal stylesheet URLs or
design tokens, recheck these selectors against the installed browser resources.

## Verification

Run the read-only verifier against the active account:

```bash
./scripts/verify-dotfiles.sh --diff
```

Run the system verifier after an installation or a root-level configuration change:

```bash
sudo ./scripts/verify-system-config.sh --profile developer --diff
```

Use `--root /mnt` to inspect a mounted target and `--grub-profile graphical|classic` when automatic profile detection is not appropriate.

Both verifiers only compare files, links, modes, and enabled-unit state. They never install, copy, change services, reload Hyprland, or change any system state.

Exit status `1` means a managed file is missing or differs. Warnings identify expected local state, extra files, or a dirty Git tree. Review intended changes with Git and commit them before using a revision as a reconstruction point.

Useful source checks:

```bash
bash -n scripts/dotfiles.sh scripts/verify-dotfiles.sh
Hyprland --verify-config --config wayland/hypr/hyprland.lua
git diff --check
```

## Intentional Local State

These locations are deliberately not copied wholesale into the repository:

- Firefox and Thunderbird profiles, cookies, tokens, and runtime data. The repository stores profile templates and `archcfg-*` launchers instead.
- Application-generated entries in `~/.config/mimeapps.list`, such as `userapp-*` desktop IDs and optional host applications.
- `~/.config/yazi/flavors/modus-vivendi.yazi/`, which is an unused legacy flavor; the managed `theme.toml` now defines the active Yazi palette.
- OpenClaw state, credentials, and host-specific service overrides. The portable gateway unit is versioned under `openclaw/systemd/user/`; see [OpenClaw Sandboxes](openclaw-sandboxes.md) for the sanitized security model and recovery procedure.
- Neovim backups, caches, plugin downloads, and lock updates that have not been deliberately reviewed.

System-wide Greetd, GRUB, networking, and power configuration are source-backed separately under their respective repository directories and checked by `scripts/verify-system-config.sh`. Generated runtime state such as `grub.cfg`, initramfs images, `fstab`, and hardware charge values must not be copied back blindly.

The optional personal Home Assistant deployment is source-backed under `home-assistant/`. Its Compose definition and loopback-only nftables policy are tracked, while its runtime `config/` volume is intentionally excluded because it can contain credentials, integration state, device identifiers, and databases. See [Home Assistant](home-assistant.md).

Printing is source-backed under `printing/` but is **not** covered by `scripts/verify-system-config.sh` yet. The `/etc/nsswitch.conf` edit, the enabled CUPS and Avahi units, and the PaperCut queues are applied by `scripts/apply-printing.sh` and must be reviewed manually with `lpstat -a` and `lpstat -p`.
