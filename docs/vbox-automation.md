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
- An official Arch ISO to use as the disposable builder environment. The runner
  bootstraps key-only SSH over a localhost NAT forward with the ISO's automatic
  root console login; it does not require Guest Additions.
- NAT egress to Arch mirrors and `archlinux.org`.
- Installer mirror refresh preserves Reflector's measured order, with the Arch
  geo endpoint appended as a fallback. Failed downloads/signatures still abort;
  mirror failures never authorize disabling package verification.
- Host `ssh`, `scp`, `ssh-keygen`, and `ss` commands.
- A clean checkout by default, or explicit `--snapshot-worktree` to freeze
  tracked modifications and non-ignored untracked files without making commits.

The automation checks these conditions without attempting host repair:

```bash
scripts/vbox-preflight.sh
```

## Build And Test

For current uncommitted work, use:

```bash
scripts/vbox-preflight.sh --snapshot-worktree
scripts/vbox-build.sh --snapshot-worktree --bootstrap-iso /path/to/archlinux-current.iso
scripts/vbox-e2e.sh --snapshot-worktree --manifest /path/to/artifacts/<run-id>/manifest
scripts/vbox-e2e.sh --snapshot-worktree --safe --manifest /path/to/artifacts/<run-id>/manifest
```

The snapshot excludes deleted files, Git metadata, ignored untracked files,
common credential paths (`.env*`, private keys, OAuth tokens), and refuses
recognized private-key/token contents without printing them. Review the path-only
`source-selected.txt` and `source-excluded.txt`; detection is conservative, not a
guarantee against arbitrary secrets disguised as ordinary configuration. Symlinks
are archived as links, never followed; symlink parents and submodules are refused.
Do not edit the worktree concurrently while it is being captured.

Artifacts retain `source.tar`, `source.tar.sha256`, and `source-tree.sha256`.
Manifest schema 2 distinguishes `source_mode=worktree` from `head`; `base_commit`
is provenance, never the identity of an uncommitted snapshot. The canonical tree
hash binds selected paths, bytes, modes and symlink targets, excluding timestamps
and ownership. HEAD exports normalize regular-file modes to Git's `0644`/`0755`
semantics rather than adding group-write permissions through `git archive`.
Worktree snapshots retain their actual file modes; extract with `tar -xpf` when
the caller's umask would otherwise remove permission bits.
Embedded `.archcfg-source.files` and `.archcfg-source.sha256` allow
verification in the builder, bundled ISO, live guest, and installed system. No
guest export falls back to `git archive HEAD` for a verified snapshot.

`--safe` prepares only the explicitly selected disposable VirtualBox disk in a
separate test fixture, then calls the installer without `--vm`, `--disk` or
`--yes`. It compares the partition table and checks witnesses on root and ESP
after installation, then cold-boots and runs the same verifiers. Safe mode does
not relax the installer's password-file restrictions: the fixture sets a test
password in the mounted guest after installation.

The live SSH key remains in private run state so both modes can test the same
ISO. Remove `runs/<run-id>/live-ssh-key{,.pub}` after all tests. E2E results are
separate under `runs/<run-id>/e2e-vm` and `e2e-safe`.

Use an official Arch ISO only as the builder environment. The ISO produced by
the build contains the selected repository source, not files embedded
in the bootstrap ISO.

```bash
scripts/vbox-build.sh \
  --bootstrap-iso /path/to/archlinux-current.iso
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
   NAT, two vCPUs, 3 GiB RAM, a 50 GiB dynamic VDI, and a temporary 4 GiB
   swapfile. ISO compression uses one worker to keep memory bounded.
2. Uses a temporary Ed25519 key and an SSH forward bound to `127.0.0.1` to
   install `archiso` inside that VM, build the frozen source on its virtual
   disk, and copy out the ISO plus checksum manifest.
3. Creates a separate test VM with the same EFI/graphics settings, two vCPUs,
    3 GiB RAM, and a new 24 GiB dynamic VDI.
4. Generates a random one-use test password and SSH key outside the repository,
   transfers the password to a root-owned runtime file in the live guest, and
   invokes the installer with `--user-password-file`. The generated ISO enables
   SSH only when the one-use public key is injected by the builder.
5. Powers the VM off, ejects the ISO, cold-boots the installed disk, then uses
   the same temporary SSH key as `archcfg-e2e` to run configuration verifiers,
   boot service checks, and guest smoke tests. The smoke tests cover IPv4
   routing, DNS resolution, HTTPS, network ownership, profile commands, UEFI,
    Docker, VirtualBox guest services, and selected user configuration files.
    The runner logs into the live greeter with the public `live:live` ISO account.
    Live desktop checks require a real Hyprland monitor via IPC, zero nonempty config
    errors, the active custom Waybar unit, and an actual Rofi share-picker layer.
     The runner also logs into the installed greeter with its one-use password
     before hardware verification, checking real monitor IPC, config errors and
     generic desktop deployment. An SSH-only session does not activate desktop
     audio clients and is not the documented post-boot verifier context.
     Installed console input uses the shipped `la-latin1` mapping for the test
     username's hyphen; the generated password contains only hexadecimal digits.
     Installed checks exercise apply idempotency, private-file preservation and
    rollback with the bundled manifests in an isolated guest home.
   The runner retains the key in private state for a second installation mode.

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

The runner does not use shared folders, bridged networking, or USB passthrough.
SSH is restricted to a dynamically allocated `127.0.0.1` NAT forward and a
one-use key stored below the runner state directory. It does not configure
`vboxusers`; preflight reports any missing VirtualBox device access.

## Coverage Limits

The E2E test proves ISO creation, live boot, automatic installation, target
cold boot, configured services, system configuration, and user dotfiles. It
cannot prove real fingerprint hardware, battery charge limits, Wi-Fi hardware,
suspend/resume, or complete graphical application behavior. Live IPC and a
screenshot provide narrower evidence, not proof of portal screen streaming,
every binding, or physical monitor behavior. Installed graphical login and its
monitor/config checks are covered separately; physical audio remains untested.

Post-boot `verify-hardware.sh --profile virtualbox --json` evidence is retained
with its original exit status. Exit 3 means incomplete observations, not hardware
certification, and does not block the VM integration checks. Actual failures,
dependency errors and SSH errors block E2E success. Absent physical capabilities
remain unknown or skipped; the runner does not synthesize hardware evidence.
