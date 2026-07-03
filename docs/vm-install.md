# VM Install

Use this only on a disposable virtual disk. The selected disk is erased.

```bash
pacman -Sy git
git clone -b project https://github.com/rcalvom/arch-linux-config.git
cd arch-linux-config
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox
```

For repeated VM testing after you are sure the disk is disposable:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox --yes
```

The installer prints `lsblk` before destructive operations and requires typing `ERASE` unless `--yes` is passed.

## Retry After A Failed Run

If a package download fails, rerun the installer. VM mode now unmounts previous mounts from the selected disk before wiping it again.

With an older checkout, manually unmount first:

```bash
umount -R /mnt
```

If package downloads repeatedly fail, refresh the checkout and retry:

```bash
git pull
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox --yes
```

Current limitations:

- UEFI only.
- Simple layout: `/boot` EFI partition plus ext4 root.
- Official repository packages only. AUR packages are intentionally skipped.
- Hyprland/Wayland is installed; Qtile is not installed by this path.
