# Roadmap

## v0.1

- Bootable UEFI VM install.
- Explicit destructive mode with `--vm --disk`.
- Minimal base system, user creation, GRUB, NetworkManager.

## v0.2

- Safe install mode using a mounted target.
- No disk operations outside VM mode.

## v0.3

- Package profiles: `minimal`, `desktop`, `developer`, `virtualbox`.
- Wayland/Hyprland as the desktop target.

## Later

- Broader hardware support.
- Conservative `apply-config.sh` for existing Arch installs.
- Optional AUR support after the core flow is reliable.
- Expand the current live ISO into a more complete test/recovery environment after VM installs are stable.
