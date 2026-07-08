# Live ISO

This repository includes an `archiso` profile under `live/`.

The ISO is an installer and desktop test environment, not a full custom distribution. It boots a live Arch system, includes this repository at `/opt/arch-linux-config`, starts a Hyprland live session on tty1, and provides `archcfg-install` as a shortcut to the installer.

## Build

Install the build dependency on an Arch system:

```bash
sudo pacman -S --needed archiso
```

Build the ISO:

```bash
sudo ./scripts/build-iso.sh --clean
```

For faster local iteration, use the fast build mode:

```bash
sudo ./scripts/build-iso.sh --clean --fast
```

Fast mode keeps the EROFS root filesystem but switches the temporary build profile to `zstd` compression and uses the detected CPU worker count. The ISO can be larger than the default build.

The output is written to `out/`.

The build script copies the committed Git tree into the ISO and applies the repository GRUB theme to the live boot menu. Commit changes before building if you want those changes included.

## Test In VirtualBox

Use a UEFI VM:

```text
Settings > System > Motherboard > Enable EFI
```

Boot the generated ISO. It should show a `tuigreet` login on tty1. Log in with user `live` and password `live`; the selected session starts Hyprland using the repository configs, including Alacritty, Neovim, Zsh, and the Ginger prompt under the live user's home.

Open a terminal with `SUPER + Return`, or use the terminal opened by the live session. To install from the live ISO, run:

```bash
archcfg-install --vm --disk /dev/sda --profile virtualbox
```

For repeated disposable VM tests:

```bash
archcfg-install --vm --disk /dev/sda --profile virtualbox --yes
```

The installer still prints `lsblk` before destructive operations. Without `--yes`, it requires typing `ERASE`.

To skip the automatic Wayland session for troubleshooting, add this kernel argument from the boot menu:

```text
archcfg_nowayland
```

## Current Scope

- UEFI installer target only.
- Live ISO includes Hyprland/Waybar/Mako/Wofi plus required installer disk/network tools.
- The installed system is still produced by `install.sh`.
- Optional AUR installation is available from the installer with `--aur`; no graphical installer or independent distribution layer yet.
