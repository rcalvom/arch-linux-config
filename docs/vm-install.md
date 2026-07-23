# VM Install

Use this only on a disposable virtual disk. The selected disk is erased.

Recommended VirtualBox settings:

- Enable EFI.
- Graphics Controller: VMSVGA.
- Video Memory: 128 MB.
- Disable 3D Acceleration for the Arch ISO test loop. On this host, VirtualBox reports 3D as enabled but disables it internally and the VM boots to a black screen.
- The `virtualbox` profile also allows software rendering because 3D is often unavailable in test VMs.

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

Optional AUR packages such as `opencode-bin` and `openclaw` are opt-in:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox --yes --aur
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

If the installed system boots to a black screen, boot the Arch ISO again and verify that the checkout includes the VirtualBox rendering fix:

```bash
cd arch-linux-config
git log --oneline -1
```

The commit should be `021a39f` or newer.

Current limitations:

- UEFI only.
- Simple layout: `/boot` EFI partition plus ext4 root.
- AUR packages are skipped unless `--aur` is explicitly passed. Each package revision and its official dependencies are declared in `packages/aur.txt` and `packages/aur-deps.txt`; the installer builds them without granting passwordless root access to the build user.
- VirtualBox normally has no Wi-Fi radio, so the default `--wifi-interface auto` leaves NetworkManager ownership unchanged.
- Hyprland/Wayland is installed with `greetd` + `tuigreet`; Qtile is not installed by this path.
- The `virtualbox` profile allows software rendering for Wayland because VirtualBox often boots without usable 3D/EGL acceleration.
