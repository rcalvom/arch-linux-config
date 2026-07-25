# VirtualBox ISO Automation

The VirtualBox automation builds the live ISO in a disposable local VM, then
installs that ISO into a separate disposable EFI VM. It runs as the regular
host user and never changes existing VirtualBox machines.

## Prerequisites

- A working VirtualBox host driver. `scripts/vbox-preflight.sh` requires both
  `vboxdrv` and a readable, writable `/dev/vboxdrvu`.
- On Arch, an administrator must install headers matching the running kernel,
  rebuild/load the DKMS module, and reboot when required. Do not rely on
  `/sbin/vboxconfig`: it is not provided on this host.
- A previously built Archcfg live ISO to use as the disposable builder
  environment. It must support the `live` user and VirtualBox Guest Control.
- NAT egress to Arch mirrors and `archlinux.org`.
- A clean, committed checkout. The builder transfers `git archive HEAD`, so
  uncommitted and untracked files are intentionally excluded.

The automation checks these conditions without attempting host repair:

```bash
scripts/vbox-preflight.sh
```

## Build And Test

Use an existing live ISO only as the builder environment. The ISO produced by
the build contains the current committed repository tree, not the repository
embedded in the bootstrap ISO.

```bash
scripts/vbox-build.sh \
  --bootstrap-iso /path/to/archcfg-live-previous.iso
```

The command creates an artifact manifest under:

```text
~/.local/state/arch-linux-config/e2e-vbox/artifacts/<run-id>/manifest
```

Run the end-to-end installation test with that manifest:

```bash
scripts/vbox-e2e.sh \
  --manifest ~/.local/state/arch-linux-config/e2e-vbox/artifacts/<run-id>/manifest
```

The baseline intentionally excludes `--aur` because AUR downloads and builds
are external, time-variable inputs. Existing parser coverage still runs as a
local test.

## What The Runner Does

1. Creates a builder VM with EFI, VMSVGA, 128 MiB video memory, disabled 3D,
   NAT, two vCPUs, 3 GiB RAM, and a 50 GiB dynamic VDI.
2. Uses Guest Control as `live` to install `archiso` inside that VM, build the
   committed source on its virtual disk, and copy out the ISO plus checksum
   manifest.
3. Creates a separate test VM with the same EFI/graphics settings, two vCPUs,
   2 GiB RAM, and a new 24 GiB dynamic VDI.
4. Generates a random one-use test password outside the repository, transfers
   it to a root-owned runtime file in the live guest, and invokes the installer
   with `--user-password-file`.
5. Powers the VM off, ejects the ISO, cold-boots the installed disk, then uses
   Guest Control as `archcfg-e2e` to run both configuration verifiers and boot
   service checks.

The password file is accepted only with `--vm --yes`, must be directly below a
root-owned mode-`0700` `/run/archcfg-e2e` directory, and must itself be
root-owned mode `0600`. It is consumed by the installer, never placed on the
command line, and removed from the host at the end of the run. It is an
automation input, not a normal interactive install option.

## Safety And Retention

- Only VMs named `archcfg-e2e-build-<run-id>` or
  `archcfg-e2e-test-<run-id>` are eligible for automated deletion.
- All managed VM files live below `~/VirtualBox VMs/archcfg-e2e-*`.
- Existing VMs, including `Testing` and `Testing Live Iso`, are never used or
  modified.
- Builder and test VMs are removed after success. On failure, the powered-off
  VM remains under `~/VirtualBox VMs/archcfg-e2e-*` and non-secret evidence is
  retained under `~/.local/state/arch-linux-config/e2e-vbox/failures/<run-id>/`.
- Use `--discard-on-failure` with either runner when diagnostics do not need to
  be retained.

The runner does not use shared folders, bridged networking, USB passthrough,
or SSH. It does not configure `vboxusers`; preflight reports any missing
VirtualBox device access.

## Coverage Limits

The E2E test proves ISO creation, live boot, automatic installation, target
cold boot, Guest Additions, configured services, system configuration, and
user dotfiles. It cannot prove real fingerprint hardware, battery charge
limits, Wi-Fi hardware, suspend/resume, or visual Hyprland rendering. Those
remain hardware or manual smoke-test concerns.
