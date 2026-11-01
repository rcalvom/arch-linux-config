# Safe Install

Safe mode assumes you have already partitioned, formatted, and mounted the target system.

Run from an isolated Arch ISO, not your working desktop. The initial hardware
policy is deliberately narrower than the original safe-mode design: dedicated
SATA/NVMe GPT disk, plain ext4 root and a separate FAT32 ESP on that same disk.
UEFI and a readable SecureBoot variable set to zero are required. See
[hardware support](hardware-support.md) for the full preflight contract.

Example:

```bash
mount /dev/<root-partition> /mnt
mkdir -p /mnt/boot
mount /dev/<efi-partition> /mnt/boot
sudo ./install.sh --target /mnt --profile developer
```

Safe mode never partitions, formats, wipes, or guesses a disk. It fails if the target mount point is not mounted.

Both mounts must be writable full filesystems. Shared ESPs, existing EFI
executables or `loader` directories, nested mounts other than `boot`, active
swap/mapped devices, and target disks mounted elsewhere are rejected before
network access or writes. Root/live-media disk ancestry is protected as well.
An unrelated non-bootloader witness file is preserved by this validation.

**Dual boot and reruns over an existing bootloader are not supported in this
stage.** Safe mode means no partitioning/formatting, not that arbitrary existing
OS layouts can be updated safely. Do not delete boot files to bypass a rejection;
review the layout manually. The installer still writes target files and installs
a bootloader after preflight succeeds.

The target must not be the running root (`/`), an alias of it, or a mount sharing
its filesystem device identity (including bind mounts of root subdirectories).
Filesystem identity checks must succeed; an unknown identity is not accepted.
Run from the Arch ISO with a separately mounted installation filesystem.

Current expectation:

- x86_64 UEFI with Secure Boot explicitly disabled; unknown firmware blocks.
- Dedicated GPT/ext4 root and FAT32 EFI System Partition mounted at `TARGET/boot`.
- Hyprland/Wayland desktop with `greetd` + `tuigreet` for `desktop`, `developer`, and `virtualbox` profiles.
