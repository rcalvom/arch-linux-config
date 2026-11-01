# VM Install

Use this only on a disposable virtual disk. The selected disk is erased.

Recommended VirtualBox settings:

- Enable EFI and disable Secure Boot. The live guest must expose efivars and a
  readable SecureBoot variable containing zero; missing variables are not assumed
  disabled, including on older VirtualBox firmware.
- Attach the disposable disk through SATA (NVMe is also in policy scope).
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

The developer and VirtualBox profiles install OpenCode from the official Arch
repository. Optional pinned AUR packages such as `opencode-notifier` and
`openclaw` remain opt-in:

```bash
sudo ./install.sh --vm --disk /dev/sda --profile virtualbox --yes --aur
```

The installer prints `lsblk` before destructive operations and requires typing `ERASE` unless `--yes` is passed.

The read-only preflight runs first, before network access or writes, and storage
is checked again after confirmation. Use an existing, unmounted target directory
(normally `/mnt`) and an unused disk with no mounted partitions, active swap or
mapped holders. Host root and live-media disks are protected by ancestry checks.
See [hardware support](hardware-support.md). Virtual GPU warnings do not block
installation; passing mocks is not new VirtualBox boot evidence.

`--disk` must resolve to a whole disk reported as `disk` by `lsblk`. Partitions,
device-mapper volumes, loop devices, and unresolved paths are rejected before
unmounting or erasing. Whole-disk `/dev/disk/by-id/` aliases are supported:
each disk phase resolves and validates the real device path before operating,
so partition names use `/dev/sda1` or `/dev/nvme0n1p1`, not an alias suffix.
Do not change device aliases or attach/detach disks during installation.

For a fully automated disposable ISO build, install, reboot, and configuration
verification loop, use [VirtualBox ISO Automation](vbox-automation.md). The
runner creates its own VMs and never modifies an existing VM.

## Retry After A Failed Run

If a package download fails, inspect mounts in the disposable guest first. The
hardware preflight now rejects busy disks, so the old automatic-unmount helper
is not a retry guarantee. Only after confirming `/mnt` belongs to that disposable
installation, unmount it in the guest before rerunning:

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

- x86_64 UEFI, readable Secure Boot disabled. Firmware uncertainty blocks.
- Simple layout: `/boot` EFI partition plus ext4 root.
- AUR packages are skipped unless `--aur` is explicitly passed. Each package revision and its official dependencies are declared in `packages/aur.txt` and `packages/aur-deps.txt`; the installer builds them without granting passwordless root access to the build user.
- VirtualBox normally has no Wi-Fi radio; IWD remains idle while systemd-networkd configures its NAT Ethernet adapter.
- Hyprland/Wayland is installed with `greetd` + `tuigreet`; Qtile is not installed by this path.
- The `virtualbox` profile allows software rendering for Wayland because VirtualBox often boots without usable 3D/EGL acceleration.
