# Safe Install

Safe mode assumes you have already partitioned, formatted, and mounted the target system.

Example:

```bash
mount /dev/<root-partition> /mnt
mkdir -p /mnt/boot
mount /dev/<efi-partition> /mnt/boot
sudo ./install.sh --target /mnt --profile developer
```

Safe mode never partitions, formats, wipes, or guesses a disk. It fails if the target mount point is not mounted.

Current expectation:

- UEFI only.
- EFI System Partition mounted at `/mnt/boot`.
- Hyprland/Wayland desktop with `greetd` + ReGreet for `desktop`, `developer`, and `virtualbox` profiles.
