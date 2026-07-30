# AGENTS.md

## Project purpose

This repository implements an opinionated Arch Linux setup inspired by projects such as Omarchy, but the first milestone is not a full independent distribution. The immediate goal is to build a reproducible Arch-based installer that can apply a complete package set, system configuration, services, and dotfiles.

The project should start with two installation paths:

1. Safe install mode: the user manually partitions, formats, and mounts their target system at `/mnt`; the installer only installs and configures Arch on that mounted target.
2. VM install mode: the user passes an explicit flag such as `--vm`; the installer wipes a selected virtual disk, partitions it, formats it, mounts it, installs Arch, and applies the same configuration automatically.

The VM mode exists to make development fast: boot the official Arch ISO in VirtualBox, run one command, verify the result, revert the snapshot, and repeat.

## Product definition

The final user experience should be:

- A clean Arch Linux base.
- A selected profile of packages.
- System services enabled and configured.
- User account created.
- Dotfiles placed in the correct locations.
- A bootable system after reboot.
- Later, optional support for an ISO built with `archiso`.

Do not prematurely build a full distribution infrastructure. First make the installer reliable, reproducible, and safe.

## Expected repository structure

Prefer this structure unless there is a strong reason to change it:

```text
.
├── AGENTS.md
├── README.md
├── install.sh
├── postinstall.sh
├── apply-config.sh
├── packages/
│   ├── base.txt
│   ├── desktop.txt
│   ├── dev.txt
│   └── vm.txt
├── dotfiles/
│   ├── alacritty/
│   ├── nvim/
│   ├── zsh/
│   ├── git/
│   └── hypr/
├── lib/
│   ├── args.sh
│   ├── disk.sh
│   ├── install.sh
│   ├── log.sh
│   └── validate.sh
├── scripts/
│   ├── packages.sh
│   ├── users.sh
│   ├── services.sh
│   ├── dotfiles.sh
│   ├── desktop.sh
│   └── aur.sh
└── docs/
    ├── safe-install.md
    ├── vm-install.md
    └── roadmap.md
```

`install.sh` should orchestrate installation. It should not contain all implementation details inline. Put reusable logic in `lib/` and installation phases in `scripts/`.

## Installation modes

### Safe install mode

Safe install mode assumes the user has already prepared the disk.

Expected user flow:

```bash
# From the official Arch ISO
pacman -Sy git
git clone https://github.com/<user>/<repo>
cd <repo>
sudo ./install.sh --target /mnt --profile developer
```

The installer must validate that `/mnt` or the selected `--target` is mounted before doing anything destructive or expensive:

```bash
mountpoint -q "$TARGET" || {
  echo "Error: target is not mounted: $TARGET"
  exit 1
}
```

In safe mode, never partition, format, wipe, or overwrite disks. The user owns partitioning decisions, especially for dual boot, custom EFI layouts, encryption, swap, and existing Windows/Linux installations.

### VM install mode

VM mode should be explicit and destructive only when the user clearly opts in.

Expected user flow:

```bash
# From the official Arch ISO inside VirtualBox
pacman -Sy git
git clone https://github.com/<user>/<repo>
cd <repo>
sudo ./install.sh --vm --disk /dev/sda --profile developer
```

Optional non-interactive development flow:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile developer --yes
```

Rules for VM mode:

- Require `--vm` and `--disk` together.
- Default to refusing if `--disk` is missing.
- Print the selected disk using `lsblk` before wiping.
- Unless `--yes` is passed, require the user to type `ERASE` before continuing.
- Never infer that a disk should be wiped without an explicit disk argument.
- Treat VM mode as disposable-disk mode, not general hardware mode.

The warning should be direct:

```text
WARNING: VM mode will erase /dev/sda completely.
This mode is intended for VirtualBox, QEMU, VMware, or disposable disks.
Type ERASE to continue:
```

## Command-line interface

The initial CLI should support at least:

```text
--target <path>       Target mount point. Default: /mnt.
--profile <name>      Installation profile. Default: developer.
--vm                  Enable automatic VM/disk installation mode.
--disk <device>       Disk to wipe and install to in VM mode.
--yes                 Skip interactive confirmation. Only valid with --vm.
--hostname <name>     Optional hostname.
--username <name>     Optional initial user.
--timezone <zone>     Optional timezone.
--help                Print usage.
```

Recommended examples:

```bash
sudo ./install.sh --target /mnt --profile developer
sudo ./install.sh --vm --disk /dev/sda --profile developer
sudo ./install.sh --vm --disk /dev/sda --profile developer --yes
```

Reject unknown flags. Avoid silently ignoring user input. ## Installation flow `install.sh` should follow this high-level flow: ```text
parse arguments
validate root privileges
validate internet connection
validate selected profile
if --vm:
    validate disk
    show destructive warning
    partition disk
    format partitions
    mount target at /mnt
else:
    validate target mount point
install base system with pacstrap
generate fstab
copy repository into the target system
enter arch-chroot
run postinstall.sh
unmount target if it was mounted by VM mode
print reboot instructions
```

`postinstall.sh` should run inside the installed system with `arch-chroot`. It should handle:

```text
timezone
locale
hostname
user creation
sudo configuration
bootloader installation
package installation by profile
service enablement
dotfile installation
optional desktop configuration
```

## Disk and bootloader rules

Support UEFI first. Detect UEFI from the live environment with:

```bash
[[ -d /sys/firmware/efi/efivars ]]
```

For VM mode, a simple UEFI layout is acceptable:

```text
/dev/sda1    EFI System Partition    FAT32    512 MiB    mounted at /mnt/boot
/dev/sda2    root                    ext4     rest       mounted at /mnt
```

For BIOS mode, either support it deliberately or fail clearly with a message. Do not pretend BIOS support exists if it has not been tested.

Use one bootloader consistently at first. Prefer the simplest tested path. Do not support GRUB, systemd-boot, BIOS, UEFI, encryption, and dual boot all at once in the first version.

Safe mode must not format the user's EFI partition. It may install bootloader files only after the user has mounted the boot/EFI partition in the expected location.

## Package handling

Keep packages in plain text files under `packages/`.

Example:

```text
packages/base.txt
packages/desktop.txt
packages/dev.txt
packages/vm.txt
```

Rules:

- One package per line.
- Allow blank lines and comments beginning with `#`.
- Use `pacman --needed` to avoid reinstalling already-present packages.
- Keep AUR packages separate from official repo packages.
- Do not install AUR packages in the first milestone unless the core flow already boots reliably.

Prefer helper functions that strip comments and blank lines before passing packages to `pacman` or `pacstrap`.

## Dotfile handling

The project already has package and configuration choices. The installer should place those files reliably.

Rules:

- Do not inline large dotfiles inside shell heredocs.
- Keep dotfiles under `dotfiles/`.
- Use `install -Dm644` for files.
- Use `install -dm755` for directories.
- Set ownership correctly for user files.
- Do not overwrite user-modified files in `apply-config.sh` without a backup or explicit confirmation.

For the fresh install path, overwriting target dotfiles is acceptable because the system is new. For `apply-config.sh`, be more conservative.

## Idempotency rules

Scripts should be safe to rerun whenever possible.

Avoid this:

```bash
echo "alias ll='ls -la'" >> ~/.bashrc
```

Prefer this:

```bash
grep -qxF "alias ll='ls -la'" ~/.bashrc || echo "alias ll='ls -la'" >> ~/.bashrc
```

Before creating users, groups, symlinks, files, directories, or services, check whether they already exist.

Use functions such as:

```bash
ensure_dir()
ensure_line()
ensure_user()
enable_service()
install_dotfile()
```

## Safety rules

These rules are mandatory:

- Never wipe, partition, or format a disk unless `--vm` and `--disk` are both present.
- Never use `/dev/sda` as an implicit default for destructive operations.
- Print `lsblk` before destructive VM operations.
- Require typed confirmation unless `--yes` is provided.
- `--yes` must only be valid together with `--vm`.
- In safe mode, fail if the target mount point is missing.
- Use `set -euo pipefail` in shell scripts.
- Quote variables unless there is a deliberate reason not to.
- Avoid `curl | bash` in the primary documentation. It can be documented later as an advanced shortcut.
- Do not hide errors with broad `|| true` unless the reason is documented.

## Logging and output style

The installer should be readable while it runs.

Use concise status messages:

```text
[INFO] Checking internet connection
[INFO] Installing base system
[INFO] Generating fstab
[INFO] Entering chroot
[ERROR] Target /mnt is not mounted
```

Prefer small logging helpers over repeated raw `echo` calls.

## Development workflow

The primary test loop is VirtualBox:

```text
1. Create or revert to a clean Arch ISO VM snapshot.
2. Boot the official Arch ISO.
3. Install git if needed.
4. Clone this repository.
5. Run: sudo ./install.sh --vm --disk /dev/sda --profile developer
6. Reboot.
7. Confirm the system boots and the configured user can log in.
8. Fix bugs and repeat.
```

The goal of VM mode is one-command reproducibility during development.

## Roadmap

### v0.1

Implement VM mode that can install a bootable Arch system in VirtualBox:

- Parse CLI flags.
- Wipe and partition disk only with `--vm --disk`.
- Format and mount partitions.
- Run `pacstrap`.
- Generate `fstab`.
- Configure timezone, locale, hostname, user, sudo, NetworkManager, and bootloader.
- Reboot successfully.

### v0.2

Implement safe install mode:

- Require `/mnt` or `--target` to be mounted.
- Do not touch partitions.
- Install base system into the target.
- Reuse the same postinstall logic from VM mode.

### v0.3

Add package profiles:

- `minimal`
- `desktop`
- `developer`
- `virtualbox`

### v0.4

Add dotfile installation:

- Alacritty
- shell config
- Git config
- editor config
- desktop/window-manager config if applicable

### v0.5

Add service configuration:

- NetworkManager
- PipeWire
- Bluetooth
- Docker if included
- VirtualBox guest service for VM profile

### v0.6

Add `apply-config.sh` for users who already have Arch installed and only want the package/configuration layer.

### v0.7

Add optional `archiso` support after the installer is reliable.

## Testing expectations

When modifying shell scripts:

- Run `shellcheck` when available.
- Run `bash -n` on modified shell files.
- Test argument parsing with harmless commands.
- Do not test destructive disk logic on the host system.
- Prefer VirtualBox snapshots for full installation tests.

Suggested local checks:

```bash
bash -n install.sh postinstall.sh
find lib scripts -name '*.sh' -print0 | xargs -0 bash -n
shellcheck install.sh postinstall.sh lib/*.sh scripts/*.sh
```

If `shellcheck` is not installed, report that it was skipped.

## Coding style

Shell scripts should use:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Prefer:

- Small functions.
- Clear names.
- Explicit arguments.
- Local variables inside functions.
- Early validation.
- Clear failure messages.

Avoid:

- Large monolithic scripts.
- Hidden global state.
- Silent fallbacks.
- Unquoted variables.
- Implicit destructive defaults.
- Combining unrelated responsibilities in one file.

## Agent behavior

When working in this repository:

1. Read this file first.
2. Preserve the two-mode design: safe mode and VM mode.
3. Treat destructive disk operations as high risk.
4. Keep the first milestone small: bootable VM install before adding polish.
5. Prefer simple Bash over adding dependencies.
6. Update documentation when changing user-facing commands.
7. Do not introduce an AUR helper, ISO builder, graphical installer, or complex profile system until the core installer is stable.
8. If a change affects installation flow, update `README.md` and relevant docs.
9. If assumptions are unclear, encode them as validations or documented limitations rather than silently guessing.

## First task recommendation

If starting from an empty repository, implement this first:

```text
Create install.sh, postinstall.sh, lib/log.sh, lib/args.sh, lib/validate.sh, lib/disk.sh, and packages/base.txt.

Support:
- --vm
- --disk
- --target
- --profile
- --yes
- --help

Make --vm --disk /dev/sda install a minimal bootable Arch system in VirtualBox.
Do not implement dotfiles, AUR, Hyprland, or ISO generation yet.
```
