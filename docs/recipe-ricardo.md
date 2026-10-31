# Ricardo Recipe

The closed selection is implemented as an opt-in package recipe, independent of
generic profiles and the personal display/tablet hardware profile. It installs
into a new target only; it is not a host migration or uninstall tool.

## Preview and Installation

```bash
bash install.sh --recipe ricardo --dry-run
bash install.sh --profile virtualbox --recipe ricardo --gpu software --aur --defer-manual --dry-run
```

Dry-run needs neither root nor network, does not inspect host graphics, and
prints official packages, AUR pins, manual selections and optional dependencies.
With `--gpu auto`, hardware packages are resolved on the actual target. For an
approved future installation on prepared safe-mode mounts:

```bash
sudo bash install.sh --target /mnt --recipe ricardo --aur --defer-manual
```

Safe-mode storage prerequisites still apply. VM erasure still requires explicit
`--vm --disk DEVICE`. The recipe accepts `developer` (default) or `virtualbox`;
the latter additionally installs guest integration. Only `--extra fingerprint`
may extend the closed selection. Fingerprint enrollment/PAM remain separate.
`--hardware-profile ricardo` is independent and never implied by the recipe.

`--aur` opts into the 13 reviewed automatic AUR packages. Without it, only the
official package selection is installed; the plan still lists the selected AUR
applications. With `--aur`, installation fails **before disk operations** unless
`--defer-manual` explicitly acknowledges the three blocked manual selections
below. This is not automatic license acceptance or a claim of complete personal
application installation. The target retains `/var/lib/archcfg/recipe-selection.txt`
showing the selection and deferrals. Failed downloads/builds are fatal, never
silently replaced by another source or a version with disabled verification.

## Official Packages and Hardware

`packages/recipes/ricardo.txt` is independent of generic desktop/development
manifests, so personal exclusions do not remove generic profile support or
required dependency libraries. Base packages are shared. Official metadata was
resolved from Arch core/extra/multilib on September 14, 2026. Current names are
`pandoc-cli` (provides Pandoc), `virtualbox-host-dkms` with `linux-headers`,
`drawio-desktop`, `openai-codex`, `python-openai-whisper`,
`python-huggingface-hub` (`hf`) and `aws-cli-v2`. No duplicate npm/pip CLI installs.
The recipe also installs tmux; its managed `packages/tmux/files.conf` deploys the
blue Alacritty-matched status bar to `~/.tmux.conf`.

The October 31, 2026 update adds `chafa` for the shipped terminal image viewer,
`python-openpyxl` for XLSX previews, `python-pillow` for GRUB theme generation,
and `uv` for isolated Python tooling. These are official repository packages;
this does not migrate existing user-level pip packages or install project styles.
The generic desktop profile also includes the two Yazi preview dependencies,
and the generic developer profile includes `uv`.

The recipe enables multilib only inside the target. GPU policies:

- `auto`: software Vulkan in VMs; `amdgpu` selects AMD, `xe` selects modern Intel.
- `amd`: Mesa VA-API, RADV and matching 32-bit Mesa/Vulkan.
- `intel`: explicitly confirmed Broadwell-or-newer Intel, media-driver and ANV,
  with matching 32-bit Mesa/Vulkan. Older/ambiguous i915 is not auto-guessed.
- `software`: Mesa and software Vulkan, including 32-bit providers; not a claim
  of hardware acceleration or suitability for DaVinci Resolve.

Unknown, mixed or NVIDIA graphics fail automatic selection. NVIDIA support has
not been validated. No automatic ROCm/OpenCL stack or universal AMD drivers.
VirtualBox host modules use DKMS against the selected stock `linux` kernel's
headers. Nested virtualization and physical driver loading are not VM-validated.
Libvirt activation, fingerprint enrollment, SDK setup, cloud login, models and
private application enrollment are separate. Docker uses sudo, not automatic
`docker` membership. Generic developer profiles now also include Docker Buildx
so the shipped Docker build command is usable.

## AUR Review

The immutable revisions are in `ricardo-aur.txt` and `ricardo-manual.txt` under
`packages/recipes/`. Review covered PKGBUILD, selected x86_64 `.SRCINFO` sections,
referenced local launchers, patches and install hooks, without executing recipes
on the host. Pins freeze recipes, not networked Go/npm/Bun dependencies. Source
checksums and PGP checks remain enabled; upstream availability is not guaranteed.

| Automatic package | Version reviewed | Provenance and relevant behavior |
| --- | --- | --- |
| cliamp | 2.2.0-1 | Upstream GitHub tag, SHA-256, Go build. |
| openclaw | 2026.9.3-1 | Upstream npm archive, SHA-256; lifecycle scripts run in guest build. Wrapper does not disable authentication. Fresh install prints enrollment instructions; upgrade hook can restart an already active target gateway. |
| visual-studio-code-bin | 1.137.0-1 | Microsoft binary, SHA-256; user-namespace sandbox, no `--no-sandbox`. |
| google-chrome | 153.0.8010.36-1 | Google binary, SHA-512; local flag launcher, no enrollment. |
| zoom | 7.1.5-1 | Zoom binary, SHA-512; no optional legacy compositors selected. |
| zotero-bin | 10.0.2-1 | Official Zotero binary, SHA-256; chosen instead of building the browser engine. |
| claude-code | 2.1.270-1 | Official Anthropic native binary, SHA-256; updates disabled, not sandboxing. Unhashed source is legal prose only. Bubblewrap/socat included as sandbox dependencies. |
| chatgpt-desktop | 26.908.40834-1 | Official OpenAI Debian archive, SHA-256. Launcher retains sandboxing. Optional existing AppArmor profile can be loaded by target hook. An archive shipping `/usr/bin/codex` is rejected rather than replacing standalone Codex. |
| spotify | 1:1.2.96.518-2 | Official archive, fixed SHA-512 plus signed repository metadata. Exact reviewed public signing fingerprint imported into the temporary build user's keyring. Rotated keys or unavailable pinned releases fail closed. |
| android-studio | 2026.1.4.7-1 | Official Google IDE archive, BLAKE2; extracts IDE only, never runs SDK manager or accepts SDK licenses. |
| google-cloud-cli | 584.0.0-1 | Official Google packager archive, SHA-256. Reviewed overlay appends `pkgname=(google-cloud-cli)` at the exact pinned revision, excluding other split outputs and the GKE component's extra download. No `gcloud init`. |
| gogcli | 0.40.0-1 | Builds the tagged upstream Go source with a pinned SHA-256 and installs the `gog` binary plus shell completions. OAuth enrollment remains private and interactive. |
| yay | 13.0.1-1 | Upstream GitHub tag, SHA-256, Go build; helper installed but never used to discover unreviewed dependencies. |

Official AUR dependencies are explicit in `ricardo-aur-deps.txt`. makepkg checks
dependency versions; no `--nodeps`, `--skipinteg` or `--skippgpcheck`. Only an
artifact whose package name equals the requested name is installed, not debug or
unrequested split packages. Builds use a temporary unprivileged target user home;
they are not an adversarial-code sandbox. Run on disposable/fresh trusted targets.

The personal selection no longer installs `opencode-notifier`; the current host
uses a separate custom plugin. Slack is deferred, even if a copy is present on an
existing host. Neither change uninstalls host packages. The generic optional AUR
profile retains its independent selection.

The [Yazi file chooser](yazi-filechooser.md) is an optional, reversible host setup,
not an automatic recipe package. Its reviewed AUR PKGBUILD fetches a moving Git
branch with `SKIP`; an AUR revision alone does not pin the upstream source.

## Manual Selections

These remain selected and pinned, not silently dropped or automatically executed:

| Package | Reviewed version | Block and supported next step |
| --- | --- | --- |
| davinci-resolve | 21.0.4-1 | Requires privately obtained `DaVinci_Resolve_21.0.4_Linux.zip`, vendor terms and a separately reviewed compatible OpenCL driver. Recipe also installs broad USB permissions. Do not choose an OpenCL provider automatically or fetch a substitute archive. Review hardware/permissions and perform a separate licensed installation. |
| flutter-bin | 3.47.2-1 | MD5-only archive, extra AUR unionfs-fuse dependency, writable SDK/FUSE wrapper and target ACL/group hooks. The alternative `flutter` split recipe is stale and constrains Dart below 3.12 while Arch supplies 3.13.2. Use a separately verified official SDK with explicit runtime/license setup; no automatic insecure wrapper or SDK license acceptance. |
| verapdf | 1.30.2-1 | MD5-only sources and execution of an upstream automated Java installer. Keep manual until stronger source authentication and a separately approved installer path are established. |

## Validation Boundaries

`tests/recipe.sh` checks CLI, exclusions, pins, GPU policies and chroot propagation.
`scripts/verify-recipe-metadata.sh` refreshes an isolated pacman database inside a
disposable VM and resolves the full official selection plus AUR dependencies,
without installing it. Generic E2E additionally builds/runs an offline scratch
container after sudo elevation and checks that the user cannot access Docker
without sudo. These tests do not establish that all AUR/proprietary programs,
large TeX/research sets, physical GPUs or SDKs have been built or exercised.

The live manifest is independent and omits the personal application collection,
Java/Node development payloads, models and credentials. The optional notifier
bridge is documented in `opencode-notifier.md`, not exported or provisioned.
