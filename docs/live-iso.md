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
Use `--fast --jobs 1` on memory-constrained builders to limit compression to one worker.

The output is written to `out/`.

The build script copies the committed Git tree into the ISO and applies the classic repository GRUB theme, matching the host boot menu, to the live boot menu. Commit changes before building if you want those changes included.

All live boot entries include `fbcon=nodefer` so the framebuffer console is bound before the TUI greeter draws.

For a disposable regular-user VirtualBox build and installation loop, see
[VirtualBox ISO Automation](vbox-automation.md). It builds from committed
`HEAD` inside a builder VM instead of using the root-owned local `out/` and
`work/` directories.

## Test In VirtualBox

Use a UEFI VM:

```text
Settings > System > Motherboard > Enable EFI
```

Boot the generated ISO. It should show a `tuigreet` login on tty1. Log in with user `live` and password `live`; the selected session starts Hyprland using the repository configs, including Alacritty, Neovim, Zsh, and the Ginger prompt under the live user's home. The account is created during the ISO build so no password hash is versioned in the repository.

Open a terminal with `SUPER + Return`, or use the terminal opened by the live session. To install from the live ISO, run:

```bash
archcfg-install --vm --disk /dev/sda --profile virtualbox
```

For repeated disposable VM tests:

```bash
archcfg-install --vm --disk /dev/sda --profile virtualbox --yes
```

The installer still prints `lsblk` before destructive operations. Without `--yes`, it requires typing `ERASE`.

`--user-password-file` is reserved for the VirtualBox automation runner. It
requires `--vm --yes` and a root-owned one-use file under `/run/archcfg-e2e`.

To skip the automatic Wayland session for troubleshooting, add this kernel argument from the boot menu:

```text
archcfg_nowayland
```

## Current Scope

- UEFI installer target only.
- Live ISO includes Hyprland, Waybar, Mako, Rofi, Firefox, Thunderbird, and required installer disk/network tools.
- The live session initializes the versioned Firefox and Thunderbird userChrome profiles before Hyprland starts.
- VS Code settings are versioned for installed systems, but VS Code itself remains outside the live ISO because it is an optional AUR package.
- The installed system is still produced by `install.sh`.
- Optional AUR installation is available from the installer with `--aur`; pinned package revisions build without passwordless root access for the build user.
