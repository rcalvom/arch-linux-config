# Arch Linux Config

**An opinionated Arch Linux workstation, from installation to recovery.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch_Linux-1793D1?logo=archlinux&logoColor=white)](https://archlinux.org/)
[![Desktop: Hyprland](https://img.shields.io/badge/Desktop-Hyprland-58E1FF)](wayland/README.md)

A modular Bash installer and configuration collection for a UEFI Arch Linux
workstation. It brings package selection, a Hyprland desktop, development tools,
system policies, and recovery procedures into one version-controlled project.

Maintained by **Ricardo Calvo**. The project is under active development, with
disposable VirtualBox installations as its primary end-to-end validation path.
Support boundaries and historical evidence are documented explicitly.

[Get started](#quick-start) · [Documentation](#documentation) ·
[Development](#development-and-contributions) · [Roadmap](docs/roadmap.md) ·
[License](#license)

## Overview

| Capability | Implementation |
| --- | --- |
| **Install Arch** | Apply the same post-install configuration to a manually prepared target or an explicitly selected disposable VM disk. |
| **Build a workstation** | Choose a minimal, desktop, developer, or VirtualBox profile; extend it with optional package sets. |
| **Configure the desktop** | Hyprland, Waybar, Rofi, Mako, greetd/tuigreet, Alacritty, Neovim, and Yazi, with shared visual conventions. |
| **Manage existing configurations** | Preview changes, preserve differing files, and apply explicit replacements with backups and conflict-aware rollback. |
| **Reconstruct and recover** | Keep package manifests, configuration inventories, deployment evidence, and recovery instructions together. |
| **Validate installations** | Exercise shell logic locally and full installation paths in disposable VirtualBox guests; build an optional archiso environment. |

Generic profiles, Ricardo's personal package recipe, and hardware-specific
settings are separate choices. Credentials, account enrollment, model downloads,
and SDK license acceptance remain outside automatic provisioning.

## Quick Start

Run these commands from the repository root. Installation commands belong in an
Arch live environment; previews and configuration-only workflows can run on an
existing system.

### 1. Preview the package selection

```bash
bash install.sh --profile developer --dry-run
bash install.sh --help
```

The package preview requires no root privileges, network access, or target writes.

### 2. Choose an installation path

**Prepared target:** partition, format, and mount the target yourself, following
the [safe-install guide](docs/safe-install.md). The installer validates the mount
layout and does not partition or format disks in this mode.

```bash
sudo bash install.sh --target /mnt --profile developer
```

**Disposable virtual machine:** let the installer partition and format an
explicitly selected virtual disk. Review the [VM guide](docs/vm-install.md) first.

> **Destructive operation:** the following example erases `/dev/sda` completely.
> Verify the virtual disk name. The installer requires confirmation; `--yes`
> skips that confirmation and is intended only for disposable automated tests.

```bash
sudo bash install.sh --vm --disk /dev/sda --profile virtualbox
```

Use `--hostname`, `--username`, and `--timezone` to set installation-specific
values. Run `--help` to inspect defaults before installing.

### 3. Apply configurations to an existing account

```bash
# Preview all managed modules.
bash apply-config.sh --module all

# Apply one module; preserve differing files unless replacement is explicit.
bash apply-config.sh --module alacritty --apply
```

This workflow does not install packages or change services. Use `--replace` only
when you intend to back up and replace differing files. See the
[configuration and rollback guide](docs/apply-config.md).

## Profiles and Package Selection

| Profile | Purpose |
| --- | --- |
| `minimal` | Base system without the desktop package selection. |
| `desktop` | Hyprland/Wayland workstation and desktop applications. |
| `developer` | Desktop plus development tools; the default profile. |
| `virtualbox` | Developer environment with VirtualBox guest integration. |

Add optional sets with repeatable `--extra NAME`: `dev-extras`, `research`,
`multimedia`, `virtualization`, `amd`, or `fingerprint`. CPU microcode selection
uses `--microcode auto` by default and skips virtual machines.

The optional personal recipe has its own reviewed selection:

```bash
bash install.sh --recipe ricardo --dry-run
```

See [the personal recipe](docs/recipe-ricardo.md) for GPU policies and deferred
applications. It does not expand the live ISO package set or imply
`--hardware-profile ricardo`, which selects personal display/tablet settings.

**AUR is opt-in with `--aur`.** Manifests pin reviewed AUR repository revisions;
builds run unprivileged and package installation runs as root. Official build
dependencies are declared separately. A recipe pin does not freeze every
upstream dependency or establish trust in downloaded source.

Host inventories under `packages/pacman/` record explicitly installed packages.
They are separate from installer selections. See [package manifests](packages/README.md)
and [portable preferences](docs/perfiles-portables.md) for details.

## Supported Scope

The current installer targets **x86_64 UEFI systems with Secure Boot disabled**.
Both installation paths perform a read-only hardware/storage preflight before
network access or writes.

- Safe mode expects dedicated, same-disk GPT/ext4 root and FAT32 ESP partitions
  on SATA/NVMe storage. Shared ESPs, existing bootloaders, encryption, and dual
  boot are outside the current supported installation path.
- VM mode requires an explicit disk and refuses busy disks rather than
  automatically unmounting them.
- Hyprland/Wayland is the active desktop. Qtile/X11 files remain as legacy
  reference and are not installed by the current profiles.
- New installations use Docker through `sudo`. User setup preserves existing
  group membership and does not automatically add users to the `docker` group.
- Physical hardware support and proprietary application builds require their
  own validation; passing shell tests does not establish either.

Read [hardware support](docs/hardware-support.md) before preparing a target.
These commands provide read-only observations:

```bash
bash scripts/hardware-check.sh
bash scripts/verify-hardware.sh --profile developer
```

The inventory command does not approve a target for installation. See
[hardware verification](docs/hardware-verification.md),
[desktop hardware defaults](docs/desktop-hardware.md), and the
[maintenance backlog](docs/maintenance-backlog.md) for remaining checks.

## Architecture

```text
install.sh          Parse options, validate the target, and orchestrate installation
postinstall.sh      Configure the installed system inside arch-chroot
apply-config.sh     Preview, apply, back up, and roll back user configuration
lib/                Shared argument, validation, storage, and logging logic
scripts/            Installation phases, deployment helpers, and validation tools
packages/           Official/AUR selections, application configs, and file manifests
wayland/            Hyprland, Waybar, desktop services, and session configuration
greetd/ + grub/     Login and boot configuration, themes, and assets
hardware/           Explicitly selected machine-specific settings
network/ + power/   Networking and power-management configuration
live/               Optional archiso installation and recovery environment
server-bootstrap/  User-level terminal tooling for remote Linux servers
tests/              Local regression checks and VM validation support
docs/               Installation, operations, recovery, and design documentation
```

Package-level `files.conf` manifests describe where configuration files are
deployed. Optional services live in dedicated directories such as `openclaw/`
and `home-assistant/`; their private runtime state is not bundled.

## Documentation

| Area | Guides |
| --- | --- |
| Installation | [Safe mode](docs/safe-install.md) · [VM mode](docs/vm-install.md) · [Live ISO](docs/live-iso.md) |
| Packages and profiles | [Package layout](packages/README.md) · [Selection decisions](docs/package-selection.md) · [Personal recipe](docs/recipe-ricardo.md) · [Setup worksheet](docs/ricardo-setup.md) |
| Configuration | [Apply and rollback](docs/apply-config.md) · [Inventory and drift](docs/configuration-inventory.md) · [Portable preferences](docs/perfiles-portables.md) |
| Desktop and appearance | [Wayland](wayland/README.md) · [Greeter](docs/greeter.md) · [GRUB](docs/grub.md) · [Lock screen](docs/lock-screen.md) · [Yazi file chooser](docs/yazi-filechooser.md) |
| System operations | [System policies](docs/system-policies.md) · [Desktop runtime](docs/desktop-fixes.md) · [Networking](docs/networking.md) · [Charge limits](docs/charge-limits.md) · [Printing](docs/printing.md) |
| Optional services | [OpenCode](docs/opencode.md) · [Notifications](docs/opencode-notifier.md) · [OpenClaw](docs/openclaw-sandboxes.md) · [Home Assistant](docs/home-assistant.md) |
| Remote systems | [Server bootstrap](server-bootstrap/README.md) |
| Validation and recovery | [VirtualBox automation](docs/vbox-automation.md) · [Deployment evidence](docs/host-deployment.md) · [Recovery checklist](docs/recovery.md) |
| Project direction | [Roadmap](docs/roadmap.md) · [Maintenance backlog](docs/maintenance-backlog.md) |

## Development and Contributions

Read [AGENTS.md](AGENTS.md) for repository conventions. Keep installation logic
modular, package lists separate from configuration, and hardware-specific choices
explicit. Update the relevant guide when changing an operator-facing command.

Start with syntax checks and the package-selection regression tests:

```bash
bash -n install.sh postinstall.sh apply-config.sh
find lib scripts -name '*.sh' -print0 | xargs -0 -n 1 bash -n
bash tests/package-profiles.sh
bash tests/recipe.sh
bash tests/aur-parser.sh
git diff --check
```

Run ShellCheck when available, and run the tests relevant to your change. These
checks do not install the system. Exercise disk and boot changes only in a
disposable VM, then record the environment, source revision, commands, and results.

The [VirtualBox workflow](docs/vbox-automation.md) supports
`scripts/vbox-build.sh --snapshot-worktree --bootstrap-iso <official-iso>` to
capture uncommitted sources for testing. Use `--snapshot-worktree` with
`scripts/vbox-e2e.sh --manifest <manifest>` as well; `--safe` exercises the
manually mounted target path. Artifacts retain source and ISO checksums with
separate evidence for each installation mode.

For bug reports, include the profile, installation mode, expected behavior,
actual result, and a minimal reproduction. Remove credentials and private host
details from logs before sharing them.

## License

Original code and configuration are licensed under the **[MIT License](LICENSE)**.
You may use, modify, and redistribute them under its terms, including retention
of the copyright and permission notice.

Bundled fonts, icons, wallpapers, and other third-party assets retain their own
licenses. See **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)** and the license
files alongside those assets. Packages installed by this project retain their
respective upstream licenses.

This is an independent configuration project and is not an official Arch Linux
distribution or an Arch Linux-endorsed installer.
