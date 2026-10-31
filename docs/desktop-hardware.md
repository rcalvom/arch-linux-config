# Desktop Hardware Defaults

The shared Wayland configuration delegates discovery to the existing tools;
it does not generate host-specific configuration or require a detection helper.

- Waybar's native `battery` module omits `bat` and `adapter`. It discovers system
  batteries regardless of their names and aggregates multiple batteries. Device-scope
  peripheral batteries are excluded by native discovery. With no system battery,
  Waybar hides the module before processing notification events, rather than
  displaying a fabricated 0% charge. A one-time `No batteries.` log warning is
  normal on a desktop, not a failed installation.
- Waybar's native `backlight` module omits `device`. Brightness keys use
  `brightnessctl --class=backlight`, keeping automatic selection within display
  backlights instead of falling through to keyboard or other LEDs. With no
  backlight, brightnessctl reports no matching device; it does not control an
  external monitor through DDC/CI automatically.
- On hybrid-GPU machines with multiple backlights, Waybar and brightnessctl have
  independent native selection policies. They are not guaranteed to select the
  same device. Explicit local `device` and `--device` overrides may be necessary;
  generic configuration must not guess a GPU name. Permissions and driver support
  remain prerequisites for changing brightness.
- Hyprland's shared Lua configuration uses the existing catch-all monitor rule
  (`preferred`, `auto`, scale 1). The layout controller defaults to extended mode,
  discovers connected outputs through Hyprland JSON, and recognizes internal
  `eDP-`, `LVDS-`, and `DSI-` connectors without requiring `eDP-1`. Unique display
  descriptions preserve saved selections across connector renames; ambiguous or
  missing descriptions cannot guarantee identity across renames.
- Neither shared Lua nor the legacy `.conf` pins tablet output. Hyprland's native
  defaults apply. No new Lua API or tablet hotplug callback is introduced.

## Personal Profile

The existing `--hardware-profile ricardo` opt-in deploys
`hardware/ricardo/hardware.lua` and `display-profiles.json` using its own
`files.conf`. The shared mapping does not deploy them. The personal tablet mapping
still intentionally targets `eDP-1`; adjust that profile if the personal panel is
renamed. Personal display layouts match description prefixes, not connector numbers.
Missing or ambiguous profile displays fall back to the controller's safe extended
layout while preserving the saved choice. Generic defaults do not erase an already
deployed personal profile.

Repository files under `hardware/` are templates, not evidence of active host
configuration. No deployment, compositor reload, monitor setter, or service action
is needed to run the tests below.

## Historical Personal Hardware

This is a source-backed historical worksheet, not a fresh hardware inventory:

| Component | Evidence and limits |
| --- | --- |
| CPU and firmware | The August 3, 2026 [maintenance backlog](maintenance-backlog.md) records an AMD Ryzen 7 PRO 7840U and Lenovo BIOS 1.35 dated February 20, 2024. Exact laptop model and current firmware remain unconfirmed here. |
| Graphics | The September [physical baseline](hardware-verification.md) observed an AMD GPU bound to `amdgpu`, an accessible render node and passive graphics work. It did not identify the active renderer or certify dock output. |
| Displays | `hardware/ricardo/display-profiles.json` defines Dell P2419H/P2422H dock displays and a Lenovo internal panel, plus a separate desk arrangement. These are profile identities, not proof that those outputs are currently connected. |
| Tablet | The personal profile maps a One by Wacom Small CTL-472 to `eDP-1`; see the [Wayland notes](../wayland/README.md#drawing-tablet). Runtime behavior still requires physical testing. |
| Power and storage | Historical notes describe about 14 GiB RAM, a 32 GiB swap partition and NVMe/ext4 storage. Resume from swap and current charge/TRIM timer behavior are not certified. |

The prior review raised dock/DRM behavior and its timing relative to a kernel change as an unresolved diagnostic question. A temporal association is not proof of a kernel regression, dock fault or fix. No controlled kernel comparison or new physical reproduction was performed for this documentation update; the exact failing topology and causal evidence remain pending confirmation. The recorded kernel 7.2.4 baseline is only a point-in-time observation.

VirtualBox can exercise generic monitor IPC and installation flow, but cannot certify physical dock modesetting, USB-C power delivery, panel behavior or suspend/resume. Keep those limits separate from the [historical ISO result](host-deployment.md).

## Verification

```bash
python3 -B tests/desktop-hardware.py
bash tests/hypr-display-layout.sh
python3 -B tests/hypr-desktop.py
luac -p wayland/hypr/hyprland.lua
luac -p hardware/ricardo/hardware.lua
```

Fixtures cover laptop, desktop, hybrid-output topology, renamed connectors,
personal opt-in, and missing/ambiguous profile outputs. Subprocess calls in layout
tests are blocked. Configuration assertions check native delegation and deployment
mapping, not a reimplementation of Waybar's discovery algorithm.

The native behavior was checked against Waybar 0.15.0's
[battery implementation](https://github.com/Alexays/Waybar/blob/0.15.0/src/modules/battery.cpp)
and [backlight implementation](https://github.com/Alexays/Waybar/blob/0.15.0/src/modules/backlight.cpp),
and brightnessctl's documented
[class selection](https://github.com/Hummer12007/brightnessctl#usage).
Offline tests do not exercise GTK rendering, real sysfs/udev discovery, battery
hotplug, backlight permissions, or physical multi-GPU selection. Lua syntax checking
alone does not validate the compositor API; this change only alters existing
command strings and removes a legacy device pin.
