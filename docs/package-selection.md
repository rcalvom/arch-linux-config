# Package Selection

## Source and Scope

Source: Ricardo's explicit interactive decisions, as restated in the requests to create and update this record. These are future setup selections, not an inventory of the host or evidence of installation, testing, or deployment.

The original selection was closed on September 14, 2026, with the explicit updates below recorded on October 31, 2026. Implementation is authorized as an optional personal recipe, not a replacement for generic package profiles. Existing manifests and installed packages are not evidence that this selection has been implemented or tested.

The accompanying task authorizes disposable sequential VM/build validation (2 CPUs, 3 GiB RAM), necessary local commits, local sanitization of known institutional printing data in history, and cleanup of confirmed contaminated generated artifacts. It does not authorize host installation/deployment/removal, service or network configuration changes, reboot, pushes, force pushes, or Git configuration changes. Preserve unrelated work, official ISOs, existing VMs and user data. Dependencies are resolved automatically by the package manager; exclusions do not prohibit required libraries or authorize host removals. Models, credentials, SDK license acceptance, fingerprint enrollment and PAM configuration remain separate.

## Approved Selections

| Area | Explicitly approved choices | Decision details |
| --- | --- | --- |
| Email | Thunderbird | Keep. |
| Editors | Visual Studio Code, Neovim | Keep VS Code as `visual-studio-code-bin`; keep Neovim with the same managed configuration. |
| Terminal music | Cliamp | Keep. |
| Virtualization | VirtualBox, QEMU/KVM | Keep both. |
| Calendar | Calcurse, Vdirsyncer with Google integration | Keep this combination; credentials and integration setup are separate. |
| Browsers | Firefox, Google Chrome | Selected. |
| Communications | Discord, Zoom | Slack deferred; presence on an existing host does not select it for a fresh installation. |
| Documents | LibreOffice, Evince, Xournal++, Zotero, Drawio, veraPDF | Selected. |
| AI | OpenCode, Codex, Claude Code, ChatGPT Desktop, Ollama, Whisper, OpenClaw | Selected, subject to the source and safety decisions below. |
| Multimedia and games | MPV, Spotify, OBS, DaVinci Resolve, MuseScore, Inkscape, GIMP, Audacity, Steam | Selected. |
| Development baseline | Full `base-devel`, Git, OpenSSH, GCC, Java OpenJDK, Node.js with npm, Python with pip, wget, unzip, btop, fastfetch, lazygit | Approved development baseline; this does not approve the general base-system category. |
| Containers | Docker, Docker Compose, Docker Buildx, Apptainer | Building and running containers explicitly confirmed. The earlier Buildx question is resolved: keep Buildx. Use Docker with `sudo`; do not automatically add the user to the `docker` group in the future setup, and do not remove any existing host membership. |
| Development tools | gh, tmux, clang, cmake, ninja, gdb, valgrind, shellcheck, shfmt, Go, Rust, uv | Selected. |
| Specialized development | Android Studio, Flutter, ARM none-eabi binutils/GCC/GDB, QEMU ARM and user-mode emulation, gfortran, SPIN, D2, cloc, Lua, LuaRocks | Select current Lua and LuaRocks only; see the explicit legacy exclusions below. |
| Cloud and model tooling | Hugging Face CLI, gcloud, AWS CLI | `extra/python-huggingface-hub` (`hf`), `extra/aws-cli-v2`, and AUR `google-cloud-cli` subject to recipe review and pinning. No authentication setup. |
| Research | R, NumPy, SciPy, Matplotlib, gnuplot, Pandoc | Selected. |
| Research typesetting | LaTeX recommended and extra packages, recommended fonts, BibTeX extra, Biber, LuaTeX, math/science, plain/generic, extra fonts | Approved research typesetting selection; this does not approve the general system-font category. |
| Base and desktop | Current base, Hyprland, Waybar, Rofi, Mako, locks, Hyprsunset, Alacritty, Yazi, current utilities | Keep the managed desktop and application configurations. No bulk legacy Xorg; retain `xorg-xwayland` and required dependencies. |
| Fonts | All current system fonts (D6) | Approved independently of the research fonts. |
| Audio | PipeWire, `pipewire-pulse`, WirePlumber, Pavucontrol, `pipewire-alsa`, `alsa-utils` | No `pamixer`. |
| Bluetooth | `bluez`, `bluez-utils`, `bluetui` | Selected. |
| Printing | `cups`, `avahi`, `nss-mdns`, `system-config-printer` | Basic printing only; site/account settings stay private. No Gutenprint or Foomatic databases as explicit personal selections. |
| System tools | `tailscale`, `rsync`, `gparted`, `dmidecode`, `openbsd-netcat`, `archiso`, `yay`, `dialog`, `which` | `yay` is AUR and still requires review/pinning; no host changes. |
| GPU | Hardware-selected VA-API/Vulkan drivers, Steam multilib, `mesa-utils`, `vulkan-tools` | No universal AMD/ROCm/OpenCL defaults. Unknown/NVIDIA hardware must fail clearly rather than guess; NVIDIA is not validated. |
| Fingerprint | Optional `fprintd` for supported hardware | Enrollment and PAM are separate. |
| Dependency libraries | Required libraries including Qt (H11) | Do not suppress dependencies because an application was excluded. |

## Explicit Source Decisions

- Codex: Ricardo explicitly approved `extra/openai-codex`. Do not add a duplicate npm installation.
- Whisper: Ricardo explicitly approved `extra/python-openai-whisper`. Do not add a duplicate pip installation. Model downloads are separate from package selection and require separate approval.
- ChatGPT Desktop: Ricardo explicitly approved the AUR desktop application with a pinned, reviewed recipe. Keep sandboxing enabled. Its internal bundled CLI must not replace the standalone CLI. This selection does not claim that a recipe was pinned, reviewed, built, or tested during this documentation update.
- Ollama and other AI applications: selecting an application does not approve downloading models or provisioning credentials.
- Hugging Face CLI and AWS CLI: use the official package identifiers above, not AWS CLI v1. Review and pin the AUR gcloud recipe before execution.
- Claude Code and ChatGPT Desktop: review pinned recipes that repackage official binaries; do not execute AUR scripts on the host or disable sandboxing/signature checks. Package selection is not build evidence.
- OpenCode notifications: the personal recipe excludes the removed `opencode-notifier` package. The current custom notification plugin and the separate personal-assistant bridge are private host configuration, not provisioned by this recipe. Do not copy runtime credentials or assume that the historical packaged-plugin instructions describe the current host.
- OpenClaw: private runtime enrollment, no insecure wrapper or implicit credential provisioning.
- Proprietary applications and SDKs: no automatic license acceptance or fallback installer scripts. Explicitly document unavailable or unvalidated builds.

## Future Exclusions

The October 2026 host review adds explicit runtime dependencies `chafa` and
`python-openpyxl` for the managed Yazi previews, plus `python-pillow` for the GRUB
theme generator. The optional Yazi portal remains separately configured and
reversible; the proposed in-TUI help bar is still pending. Existing pip packages,
MCP installations, and legacy Xorg packages are not imported wholesale.

| Application | Decision | Scope |
| --- | --- | --- |
| khal | Exclude from the future selection. | Any removal ambiguity is treated as future selection only, not permission to uninstall it from the host. |
| Rnote | Explicitly unselected; exclude from the future selection. | No host uninstall authorized. |
| imv | Unselected; exclude from the future selection. | No host uninstall authorized. |
| LazyDocker | Exclude from the future selection. | No host uninstall authorized. |
| Ruby | Exclude from the future selection. | No host uninstall authorized; required dependencies remain allowed. |
| pipx | Unselected; exclude from the future selection. | No host uninstall authorized. |
| `lua51`, `lua51-luarocks` | Exclude as explicit selections; keep current Lua and LuaRocks instead. | Allowed if required as dependencies; no host uninstall authorized. |
| JupyterLab | Unselected; exclude from the future selection. | No host uninstall authorized. |
| Picom, lxappearance, hyprlauncher | Exclude from the personal recipe. | Generic package support is not removed by this decision. |
| `pamixer`, `wireless_tools` | Exclude as explicit selections. | Required dependencies remain allowed. |
| Gutenprint, Foomatic databases and legacy Xorg bulk sets | Exclude from the personal recipe. | Retain Xwayland and required libraries. |
| `opencl-mesa`, `rocm-smi`, `radeontop` | Not defaults. | GPU selection follows actual supported target hardware. |

## Implementation and Validation Contract

No further category selection is required. The optional personal recipe must remain distinct from `--hardware-profile ricardo`, which opts into matching display/tablet layouts. The live ISO must remain a lightweight diagnostic environment without heavy applications, models or credentials. The large installed recipe must not become the live package list or generic default.

Implementation and source review are documented in the [executable recipe](recipe-ricardo.md), including exact manifests, automatic AUR pins and explicitly deferred manual packages. Validate final committed sources using the authenticated official ISO and a newly built custom ISO. Generic VM/safe E2E and recipe mock/metadata checks do not establish successful builds of every AUR/proprietary application or physical hardware support. See [Ricardo's setup worksheet](ricardo-setup.md) for private installation settings that still require target-specific confirmation.
