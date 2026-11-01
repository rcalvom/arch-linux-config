# Hardware Preflight

This is a read-only policy check, not a hardware certification or an installation
test. No drivers are selected or installed. It does not contact network endpoints,
mount filesystems (not even read-only), refresh mirrors, or write reports to disk.
Output omits UUIDs, serial numbers, IP addresses, device aliases and mount sources.

## Commands

Run from the repository, without installing dependencies on the host:

```bash
bash scripts/hardware-check.sh
bash scripts/hardware-check.sh --help
sudo bash scripts/hardware-check.sh --target /mnt
sudo bash scripts/hardware-check.sh --vm --disk /dev/sda --target /mnt
```

The first command inspects only the running platform and does not require root.
Reading Secure Boot may require root; unreadable firmware state is unknown,
not assumed disabled. Inventory-only reports return warnings (`2`), including for
out-of-scope architecture or firmware; they do not reject the running host.
The latter two commands inspect the proposed installation
layout as root but still perform no writes. `--disk` requires `--vm`; VM mode
requires an explicit disk. `--target` defaults to `/mnt` in VM mode. There is no
force flag, fixture input, automatic dependency installation or implicit disk.

Exit codes: `0` supported checks, `2` non-blocking warnings, `1` unsupported or
unverifiable safety requirements, `64` invalid checker arguments. The installer
accepts `0` and `2`, and stops with `1` on a blocking preflight. In this first stage
every platform report includes a graphics qualification warning, so successful
full reports currently return `2`, not hardware certification via `0`.

Dependencies are Bash, coreutils (`uname`, `od`, `readlink`, `stat`) and util-linux
(`findmnt`, `lsblk`, `mountpoint`), normally present on the official Arch ISO.
Missing tools block target checks; host inventory warns about unavailable probes
and does not require storage tools. PCI data is read directly from sysfs; neither
`lspci` nor a package-manager refresh is required.

## Initial Policy

| Area | Policy |
| --- | --- |
| Architecture | x86_64 only; other or unknown architecture blocks |
| Firmware | UEFI and an explicitly readable SecureBoot value of zero |
| BIOS / Secure Boot | BIOS, enabled Secure Boot, missing efivars, missing/malformed/unreadable variable block; signed boot is not implemented |
| Intel / AMD integrated graphics | Initial intended scope, not a claim of tested models; PCI vendor alone cannot distinguish integrated/discrete or prove usable outputs, so warn |
| NVIDIA / hybrid | Warn, do not block disk-safe base installation; driver selection, PRIME, Wayland and display routing are not handled |
| Other / virtual / absent GPU | Warn; no desktop compatibility claim, including VirtualBox graphics |
| Storage | SATA and NVMe, plain dedicated GPT partitions; USB, RAID, encryption, LVM and other mapped layouts are outside this stage |
| VM storage | Explicit whole unused disk; SATA/NVMe or virtio `/dev/vd*` with no reported transport; VM mode remains explicit disposable-disk consent, not proof of virtualization |

Graphics warnings are non-blocking because a vendor ID does not establish that
the base installation is unsafe. Firmware and storage uncertainty block because
continuing could produce an unbootable system or modify the running host.
CPU microcode and package policies remain unchanged; no new driver automation
is introduced by this check.

## Storage Safeguards

Safe mode requires an already mounted ext4 root, distinct from the running root
filesystem, and a distinct FAT32 GPT ESP mounted at `TARGET/boot`. Both must be
writable full-filesystem mounts on the same dedicated SATA/NVMe disk. It rejects
subdirectory binds, nested mounts other than the ESP, active mapped devices,
active swap, and any partition of that disk mounted elsewhere. Thus a host ESP
shared through another mount is rejected, even when target root is separate.
Existing EFI executables or a `loader` directory also block automatic bootloader
replacement. Non-bootloader files such as the safe E2E witnesses are preserved.
ESP symlinks and targets under protected host paths (`/etc`, `/usr`, `/home`,
`/run`, etc.) are rejected; use a dedicated path such as `/mnt`.
This deliberately limits reruns and dual boot: inspect existing boot files
manually rather than deleting them just to bypass the preflight.

VM mode requires an existing unmounted target directory and no mounted partitions, swap or mapped
holders on the explicitly selected disk. The previous automatic unmount helper
remains, but this policy refuses busy disks before reaching it. Host root device
ancestry is checked through `lsblk`, including device-mapper parents. For an Arch
ISO overlay root, the physical `/run/archiso/bootmnt` source is protected instead.
Unknown pseudo-filesystem roots or unresolved live-media ancestry fail closed.
The entire host-root/live-media disk is excluded, not only its root partition.
Query failures block even if stdout resembles a valid answer. ESP GUID comparison
is case-insensitive. A missing/unreadable SecureBoot variable still blocks a VM;
EFI enabled in VirtualBox settings alone is insufficient evidence for this policy.

The installer runs the complete preflight before password-file cleanup is armed,
internet access, mirror writes, unmounting, partitioning, formatting or target
writes. It rechecks storage after destructive confirmation or before safe-mode
installation. Preflight rejection leaves a supplied one-use password file alone.
No preflight mounts are created and no probe results are persisted.

These checks cannot identify an unmounted OS with no EFI executables, prove a
partition contains no valuable data, or prevent concurrent mount/device changes.
Use an isolated live environment, stop other storage activity, and explicitly
prepare dedicated targets. Safe mode still installs files and a bootloader after
preflight; it is not a dry-run installation. A passing check does not establish
successful boot, networking, audio, suspend, external displays or desktop login.

## Verification

```bash
bash tests/hardware-check.sh
bash tests/install-safety.sh
bash tests/install-password-file.sh
bash tests/source-snapshot.sh
bash tests/source-install.sh
bash tests/vbox-e2e-mocks.sh
```

Fixtures mock hardware and device queries and never wipe, format or mount a real
disk. They cover vendor categories, firmware rejection, storage isolation and
preflight ordering. Snapshot selection remains unchanged: new non-ignored files
are included in worktree snapshots, while HEAD snapshots only include committed
files. Existing source hashes and E2E witness protocols are not modified.
These fixtures are not a new VM boot test or physical-machine support evidence.
