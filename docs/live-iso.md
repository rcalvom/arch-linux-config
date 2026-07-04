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

The output is written to `out/`.

The build script copies the committed Git tree into the ISO. Commit changes before building if you want those changes included.

## Test In VirtualBox

Use a UEFI VM:

```text
Settings > System > Motherboard > Enable EFI
```

Boot the generated ISO. It should log in as root and start Hyprland automatically using the repository configs.

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
- No AUR helper, graphical installer, or independent distribution layer yet.
