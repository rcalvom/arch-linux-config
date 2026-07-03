# Live ISO

This repository includes a minimal `archiso` profile under `live/`.

The ISO is an installer environment, not a full custom distribution. It boots a live Arch system, includes this repository at `/opt/arch-linux-config`, and provides `archcfg-install` as a shortcut to the installer.

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

Boot the generated ISO and run:

```bash
archcfg-install --vm --disk /dev/sda --profile virtualbox
```

For repeated disposable VM tests:

```bash
archcfg-install --vm --disk /dev/sda --profile virtualbox --yes
```

The installer still prints `lsblk` before destructive operations. Without `--yes`, it requires typing `ERASE`.

## Current Scope

- UEFI installer target only.
- Live ISO includes the installer and required disk/network tools.
- The installed system is still produced by `install.sh`.
- No AUR helper, graphical installer, or independent distribution layer yet.
