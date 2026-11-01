# Portable Preferences and Optional Extras

## Scope and Privacy

The September 2026 local audit uses a whitelist, not a home-directory export.
Tracked preferences contain no identity, credentials, provider endpoints, device
IDs, editor state, browsing history, accounts, or machine-specific home paths.
Existing Calcurse work is outside this change.

| Component | Captured preferences | Deployment |
| --- | --- | --- |
| GTK 3/4 | Adwaita dark and icon settings; GTK 3 font/rendering preferences | `packages/gtk/files.conf` |
| btop | Adwaita dark, transparent background, layout and refresh preferences | `packages/btop/files.conf` |
| Alacritty | Shift+Return sends Escape followed by carriage return | Existing manifest |
| cliamp | `theme = "archcfg-terminal"` only | Existing manifest plus config file |
| Git | `core.editor = nvim`, `init.defaultBranch = main`, local settings ignore | `packages/git/files.conf` |
| VS Code | Existing portable appearance/formatter settings, workspace trust prompt | Existing manifest |
| VS Code extensions | Reviewed subset of locally installed extension IDs | Opt-in manifest, not automatically installed |
| VS Code MIME associations | Proposed text/source associations with `code.desktop` | Optional fragment, not automatically deployed |

The btop theme uses a theme name instead of an absolute system path. GTK settings
do not force libadwaita applications to use a legacy theme. No dconf database is
copied. Local VS Code `files.associations` and `editor.selectionClipboard` were
unset; no values are invented for those keys. The MIME fragment is an explicit
proposal, not an export of local application state.

Git uses its standard XDG paths. Existing `~/.gitconfig` settings take precedence;
no identity, remotes, credential helpers, signing configuration, or includes are
copied. Neovim and Evince are now desktop dependencies because Yazi opens text and
PDF files with them. The live image also gains Evince and Terminus, while already
including Neovim.

## Optional Package Sets

`install.sh` and its target `postinstall.sh` accept repeatable `--extra NAME` options:

| Extra | Purpose |
| --- | --- |
| `dev-extras` | Additional compilers, debuggers, build tools, shell linting |
| `research` | R, Jupyter, scientific Python, selected TeX collections |
| `multimedia` | OBS Studio, Audacity, GIMP, Inkscape |
| `virtualization` | QEMU/KVM host, libvirt, virt-manager, UEFI firmware |
| `amd` | AMD GPU Vulkan/VA-API userspace and diagnostics |
| `fingerprint` | fprintd package only, no authentication changes |

Lists live in `packages/extras/*.txt`, use official repository package names, and
are not selected by any default profile. Unknown names and path traversal are
rejected. Repeated extras and overlapping package names are deduplicated before
one `pacman -Syu --needed` transaction. Existing developer Docker selection is
unchanged. The virtualization extra does not enable daemons or grant group access.
The AMD GPU extra is independent of the CPU vendor and does not enable multilib,
ROCm, proprietary drivers, or hardware-specific kernel parameters.

## CPU Microcode

Inside the installed target, `postinstall.sh` defaults to `--microcode auto`.
Virtual machines detected by `systemd-detect-virt --vm` skip microcode because
the hypervisor manages it, including VirtualBox with an exposed AMD or Intel CPU.
On physical hardware, after the profile transaction and before GRUB configuration, it validates an
`x86_64` architecture and a consistent CPU vendor from `/proc/cpuinfo`, installs
only `intel-ucode` for `GenuineIntel` or `amd-ucode` for `AuthenticAMD`, and runs
`mkinitcpio -P`. Unsupported, missing, or mixed vendors fail rather than guess.
`--microcode none` explicitly skips detection and installation, useful for VMs
whose hypervisor supplies the CPU/microcode abstraction. Detection describes the
CPU exposed to the installer, not hardware onto which the disk might later move.
This does not install microcode into the live host or add it to the base list.

## Integration Contract

The desktop installer discovers package manifests automatically. `install.sh`
validates and forwards extras, microcode and the optional hardware profile as
separate array arguments into the target chroot. `postinstall.sh` is a full
installation phase, never a host preference-only command.

For existing homes, back up or merge GTK, Git, btop, VS Code, and especially
`cliamp/config.toml` rather than replacing provider configuration. The new cliamp
file contains only the theme; overwriting an existing file could discard private
settings even though no secrets are shipped. Fresh-install copying is supported;
`apply-config.sh` preserves differing files by default. `--replace` explicitly
backs up and replaces the entire file; it does not merge provider settings.

`packages/vscode/extensions.txt` is deliberately not an executable installer.
After reviewing the IDs, the target user can explicitly consent to marketplace
access with `bash scripts/install-vscode-extensions.sh --apply --consent-marketplace`.
The default invocation only prints the plan. The helper uses `/usr/bin/code`,
rejects root/sudo, and checks its package ownership rather than invoking a PATH wrapper.
Versions and marketplace availability are not pinned by this preference list.

Merge `packages/vscode/mimeapps.list` into the target user's existing default
application map only when `code.desktop` is installed and the user opts in.
Preserve browser/mail/PDF defaults and user-modified associations. Do not deploy
the fragment as a replacement `mimeapps.list`: VS Code itself remains optional
through the existing AUR flow. Yazi's explicit Neovim opener remains unchanged.

## Fingerprint Authentication

Fingerprint support is now package-only and opt-in; it is no longer a desktop
default. The generic Hyprlock template uses password authentication and disables
its optional fingerprint backend. After enrollment and recovery tests, enable
that backend locally if desired; selecting the package extra does not enable it.
There is no portable, tested PAM policy in this change. Hardware and
libfprint compatibility must be checked first, followed by interactive enrollment
on the target. Test password login and recovery access before enabling any
fingerprint path, and retain password authentication as fallback. Do not add a
blanket `sufficient pam_fprintd.so` to system-auth, sudo, greetd, or the lock screen.
Authentication ordering, timeouts, and concurrent password prompts depend on the
consumer and require target-specific tests. No biometric templates are captured.

No personal AI bridge, OpenClaw wrapper, AI credentials, or autonomous service is
provisioned. Existing standalone developer tool selection is not expanded.

## Verification

```bash
bash tests/package-profiles.sh
python3 tests/preferences-portable.py
shellcheck scripts/packages.sh postinstall.sh tests/package-profiles.sh
```

Tests mock package management, initramfs generation, and CPU detection. They do
not install packages, contact extension marketplaces, change PAM, invoke personal
wrappers, or read the host home. A real target boot, repository availability,
GTK rendering, and fingerprint behavior still require VM/hardware validation.
