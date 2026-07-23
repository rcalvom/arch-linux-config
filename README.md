# Arch Linux Configuration Repository

**Author:** Ricardo Andres Calvo Mendez  
**Last Updated:** 2026-07-17

---

## Overview

This repository contains a curated and reproducible set of configurations for an Arch Linux system.  
Its purpose is to document, version, and automate system setup across installations, enabling fast recovery, consistency, and incremental improvements over time.

The active installer target is a UEFI Arch Linux system with a Hyprland/Wayland desktop. Qtile files are kept only as legacy reference and are not installed by the new installer path.

The installed display manager is `greetd` with `tuigreet`. It starts Hyprland by default and exposes the system session menu from `/usr/share/wayland-sessions` and `/usr/share/xsessions`, so an existing Qtile session remains selectable when Qtile is installed separately.
Greeter theming notes live in `docs/greeter.md`.

---

## Quick Start

Safe install mode assumes the target system is already partitioned, formatted, and mounted:

```bash
sudo ./install.sh --target /mnt --profile developer
```

VM mode is destructive and requires an explicit disk:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox
```

For repeated disposable VM testing:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox --yes
```

Available profiles: `minimal`, `desktop`, `developer`, `virtualbox`.

Optional AUR packages for developer-style profiles are opt-in:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox --yes --aur
```

`packages/aur.txt` pins each reviewed AUR repository revision. The installer builds those revisions as the regular user without granting temporary passwordless root access, then installs only the resulting local packages as root. Their reviewed official dependencies are declared in `packages/aur-deps.txt`; adding or updating an AUR package requires reviewing its PKGBUILD and `.SRCINFO`, then updating both files. Pinning improves reproducibility but does not make AUR source trusted.

The repository is organized by functional domains (packages, bootloader, desktop environment, etc.), with each directory responsible for a well-defined part of the system configuration.

Configuration capture and read-only drift verification are documented in [docs/configuration-inventory.md](docs/configuration-inventory.md).

---

## Repository Structure

### `packages/`
Contains package-related configuration and metadata.

This directory stores:
- Lists of explicitly installed packages
- Per-package configuration folders
- Installation notes and dependency considerations

The goal is to enable reproducible package installation and minimize manual intervention after a fresh system setup.

---

### `live/`
Contains the minimal `archiso` profile for building a custom live installer environment.

This includes:
- Scripts and configuration files for generating a live ISO
- Preconfigured defaults for installation or recovery workflows
- Documentation describing the live environment build process

This directory is intended for system bootstrap, recovery, and testing.

Build documentation: `docs/live-iso.md`.

---

### `wayland/`
Contains the active Hyprland/Wayland desktop configuration.

This directory includes:
- Window manager configuration files
- Keybindings, layouts, and startup hooks
- Environment-specific scripts and theming adjustments
- Hyprland configuration snapshots
- Waybar configuration
- Fontconfig fallback for Ubuntu + Noto
- Package notes for Wayland-related tools

### `packages/alacritty/` and `packages/nvim/`
Contain the active terminal, editor, and shell configuration. Package folders can include `files.conf` manifests so the installer and live session copy configs into the correct home-directory locations automatically.

### `server-bootstrap/`
Contains a portable, user-level Bash bootstrap for remote Linux servers. It installs terminal development tools when possible and deploys the Ginger Zsh, Neovim, OpenCode, and tmux configuration without touching system or hardware-specific settings. See [server-bootstrap/README.md](server-bootstrap/README.md).

### `qtile/`
Contains the previous Qtile setup as a legacy reference. It is not part of the installer profiles.

Automatic Redshift and GeoClue setup for the legacy Qtile/X11 session is documented in [docs/redshift.md](docs/redshift.md).

Dock-aware battery charge limits are documented in [docs/charge-limits.md](docs/charge-limits.md).

---


### `grub/`
Contains custom **GRUB bootloader** configuration.

This includes:
- Custom GRUB themes
- Theme installer script
- Boot menu appearance settings
- Configuration overrides and generation notes

The goal is to provide a visually consistent and predictable boot experience.

---

## Goals

- Fully reproducible Arch Linux installations
- Clear separation of system concerns
- Version-controlled configuration
- Minimal reliance on ad-hoc manual steps

---

## Pending Hardware Maintenance

The AMD laptop should eventually add `amd-ucode` to the package profile and `fwupd` for firmware update checks. This is intentionally documented but not installed or configured yet; review and apply those changes in a dedicated maintenance window.

---

## Notes

This repository reflects a personal workflow and hardware setup.  
Adjustments may be required when applying it to different machines or use cases.

---

## License

Specify a license here (e.g., MIT, GPL, or private use).
