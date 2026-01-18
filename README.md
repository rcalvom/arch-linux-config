# Arch Linux Configuration Repository

**Author:** Ricardo Andres Calvo Mendez  
**Last Updated:** 2026-01-16

---

## Overview

This repository contains a curated and reproducible set of configurations for an Arch Linux system.  
Its purpose is to document, version, and automate system setup across installations, enabling fast recovery, consistency, and incremental improvements over time.

The repository is organized by functional domains (packages, bootloader, desktop environment, etc.), with each directory responsible for a well-defined part of the system configuration.

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
Contains resources for building and maintaining a custom Arch Linux live environment.

This includes:
- Scripts and configuration files for generating a live ISO
- Preconfigured defaults for installation or recovery workflows
- Documentation describing the live environment build process

This directory is intended for system bootstrap, recovery, and testing.

---

### `greeter/`
Contains configuration for a custom **LightDM greeter**.

This includes:
- Theme configuration
- Branding, layout, and visual customization
- Behavior and authentication presentation settings

The objective is to provide a consistent and minimal login experience aligned with the overall system theme.

---

### `desktop-environment/`
Contains desktop environment and window manager configuration.

Currently supported:
- **Qtile**

This directory includes:
- Window manager configuration files
- Keybindings, layouts, and startup hooks
- Environment-specific scripts and theming adjustments

Support for additional desktop environments may be added in the future.

---

### `grub/`
Contains custom **GRUB bootloader** configuration.

This includes:
- Custom GRUB themes
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

## Notes

This repository reflects a personal workflow and hardware setup.  
Adjustments may be required when applying it to different machines or use cases.

---

## License

Specify a license here (e.g., MIT, GPL, or private use).
