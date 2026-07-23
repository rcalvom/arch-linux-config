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

## Managed User Configuration

`packages/*/files.conf` deploys per-application files, including Alacritty, Calcurse, Firefox and Thunderbird launchers/templates, Neovim, Oh My Zsh, VS Code, and Yazi.

`scripts/dotfiles.sh` deploys the Wayland configuration:

- Hyprland, the portal configuration, Hyprlock, Hyprpaper, and Hyprtoolkit.
- Waybar, Rofi, Mako, Fontconfig, wallpaper, user systemd units, and their timer enablement links.
- All helpers in `wayland/bin/`.
- `wayland/mimeapps.list` as a baseline for a fresh account.

The active Hyprland source is `wayland/hypr/hyprland.lua`; `hyprland.conf` remains a legacy reference only.

## Verification

Run the read-only verifier against the active account:

```bash
./scripts/verify-dotfiles.sh --diff
```

Run the system verifier after an installation or a root-level configuration change:

```bash
sudo ./scripts/verify-system-config.sh --profile developer --diff
```

Use `--root /mnt` to inspect a mounted target, `--wifi-interface <name>` when its Wi-Fi adapter is not visible to the current host, and `--grub-profile graphical|classic` when automatic profile detection is not appropriate.

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
- OpenClaw state and `openclaw-gateway.service`, which can contain credentials or host-specific state. Only portable shell completion loading is managed.
- Neovim backups, caches, plugin downloads, and lock updates that have not been deliberately reviewed.

System-wide Greetd, GRUB, networking, and power configuration are source-backed separately under their respective repository directories and checked by `scripts/verify-system-config.sh`. Generated runtime state such as `grub.cfg`, initramfs images, `fstab`, and hardware charge values must not be copied back blindly.
