# GRUB Profiles

New installations and the live ISO still use `classic`. The personal graphical
profile is an explicit opt-in for an existing host; preparing repository files
does not activate anything in `/etc` or `/boot`.

## Midnight Terminal (Graphical)

`grub/grub`, the shared `grub/theme.template` and `grub/sizes.json` define Ricardo's
terminal-style graphical menu. Generated assets are bundled in
`grub/theme/variants/{compact,normal,large}/`; `grub/theme/theme.txt` is the generated
compact snapshot. Do not edit generated themes independently.

| Explicit Size | Target Modes | Title / Menu / Footer Pixels | Visible Rows |
| --- | --- | --- | --- |
| `compact` (default) | 640x480 through 1024x768 | 24 / 22 / 18 | 3 |
| `normal` | 1280x720 through 1600x900 | 30 / 28 / 22 | 5 |
| `large` | 1920x1080 through 2560x1440 | 36 / 32 / 24 | 5 |

No runtime size detection is attempted. `GRUB_GFXMODE=auto` selects a firmware
video mode, not a theme variant. Choose the variant for that mode explicitly.

- Managed wallpaper `qtile/wallpapers/wallpaper2.png`, without global dimming,
  with centered proportional `crop` scaling to fill every screen, not stretching.
  Its bytes matched `~/Pictures/wallpaper2.png` during read-only inspection;
  neither source is changed. Pure-white `#ffffff` option and help text,
  green prompt `#10a778` and light-cyan icons/keycaps `#4fb8cc` in both states.
  The title is cyan `#4fb8cc`; the countdown uses Alacritty bright yellow `#f3e430`.
  The green and bright cyan match `packages/alacritty/alacritty.toml` and the
  inspected local Alacritty configuration. White is intentionally pure white,
  not Alacritty's gray foreground or off-white ANSI colors.
  A black RGBA `panel.png` (alpha 204/255) blends only inside the blue frame,
  matching the inspected local Alacritty `window.opacity = 0.8`: 80% black,
  20% wallpaper. The exterior retains the original wallpaper brightness.
  This is a terminal-like effect over a static bundled wallpaper, not live
  desktop transparency or transparent E/C text cells. GRUB's native image
  widget supports alpha: upstream `gui_image.c:image_paint` calls
  `grub_video_blit_bitmap` with `GRUB_VIDEO_BLIT_BLEND`. The panel is positioned
  after wallpaper cropping, so its percentage bounds work at every aspect ratio.
- A centered frame occupies 94% of screen width and height, starting at 3% x/y.
  Its only outline is 2 px dark blue `#033e8c`, matching `general.border_size`
  and `general.col.active_border` in the inspected local configuration and
  in the current `wayland/hypr/hyprland.lua` (also present in legacy Hyprlang).
  There is no header bar, `ARCH LINUX` heading or `boot:~$` label. The bright
   `Select an operating system or an option` title uses one centered real Bold line,
   since GRUB labels neither wrap nor adapt font sizes. The sizes above use separate
    PF2 rasterizations, not scaled text bitmaps. Compact's title advances 468 px and fits the 565 px inner
  width at 640x480. Local Alacritty uses 12 pt (about 16 px at 96 DPI before
  monitor scaling); PF2 bitmaps are not an exact physical-size match. See
  `grub/README.md` for the sizing rationale and font rebuild commands.
- A green arrow in the west selection slice follows only the selected row.
  All selection slices are RGBA: only the exact arrow glyph is opaque; the
  center, east edge and space around the arrow are fully transparent. Selection
  never adds a black rectangle or dims the wallpaper again.
  Both selected and unselected text stay white with no colored row fill.
   West slices are 36/45/54 px wide for compact/normal/large, with 24/30/36 px
   arrow slots and icons, followed by 12/15/18 px icon-to-text gaps.
  It is rasterized from the actual U+279C glyph used by the local Fontconfig
  fallback, Adwaita Mono Bold: UbuntuMono Nerd Font does not contain U+279C.
  The bundled single-glyph PF2 preserves that glyph, not a hand-drawn approximation.
  Ginger requests bold in `packages/oh-my-zsh/ginger.zsh-theme`.
  The bold ANSI green remains normal
  `#10a778`: Alacritty defaults `draw_bold_text_with_bright_colors` to false,
  and the repository does not override it. It is not bright green `#5fd7af`.
  There is no unselected item pixmap, so other entries never repeat the arrow.
- Up/down, return, Escape, E and C keycaps are original vector-stroke PNG assets
  displayed by standard `image` components, beside pure-white action labels.
   The proportionally scaled keys and short `select`, `boot`, `edit`, `console`, `back`
  labels occupy one horizontal row across a standard GRUB `canvas`. Percentage
  positions minus half-group widths center the complete groups at 10%, 30%,
   50%, 70% and 90% of the inner width, with 6/7/8 px key-to-label gaps.
  Labels themselves remain left-aligned. Stopping the timer
  is explained below rather than taking an extra help row.
  The arrow PNG is generated from bundled PF2 coverage; keycaps use vector strokes.
- The title starts at 32% of screen height. Menu and countdown use that same
   percentage plus fixed pixel offsets, forming one cohesive central block.
   Menus start 48/72/88 px below the title, with heights 128/262/284 px,
   rows 36/44/48 px, gaps 6/8/8 px and padding 4/5/6 px.
   The countdown follows the viewport by 16/20/24 px. At 1920x1200, large has
   title y=384, menu y=472 and countdown y=780, rather than spreading them from
   the panel's top to bottom. Help remains anchored near the panel's bottom edge.
   The compact menu width is `40%+240`; normal and large use centered fixed
   660/760 px boxes sized for typical main titles, not the whole panel width.
   Three actual entries are top-aligned, leaving two empty rows in normal/large.
   GRUB does not dynamically center rows based on entry count or support a
   `max_shown_items` theme property; two-entry submenus use the same fixed viewport.
  Additional entries scroll with the arrow keys without a visible scrollbar;
   footer hints remain outside the list. Eight- and thirty-entry fixtures exercise scrolling.
  Designed for 640x480 and larger; long entry names can be clipped at low
   resolutions or with unusually long titles. Using a variant outside its target
   modes can cause clipping or poor proportions; size selection does not force
   a matching video mode (the graphical profile keeps `GRUB_GFXMODE=auto`).
- Visible **three-second** countdown, centered across the inner panel using the
  supported `__timeout__` label, `Booting in %d s` template and `align = "center"`.
   Press an arrow key to cancel automatic boot and select Advanced
  options. `E` edits an entry, `C` opens the console, and `ESC` returns from a
  submenu. Recovery entries are enabled when supported by the Linux generator;
  existing fallback-initramfs entries and custom generators are not removed.
- White-on-black / white-on-blue fallback colors if the theme cannot load.

### Icons and Clock Limits

GRUB supports `icon_width`, `icon_height`, `item_icon_space` and
`selected_item_pixmap_style`; compact icons use 24x24 canvases with a centered 20 px
silhouette envelope and alpha coverage capped at 140 opaque-pixel equivalents.
Normal/large scale these shared alpha masks to 30/36 px while preserving cyan RGB.
This balances dense and outline logos without replacing their shapes. All use cyan, including `arch`,
`gnu-linux`, `windows`, `recovery` and `efi`. Original `os` and `settings` icons
provide additional class matches.
An `os` icon is a fallback only for entries declaring `--class os`, not a global
fallback. GRUB chooses a matching class, not an icon inferred from the title.

The title and menu box are centered, but individual menu titles are not.
The official GRUB 2.14 theme manual has no `item_align` property, and upstream
`gui_list.c:list_set_property` does not implement it. `draw_menu` places icons
after the widest west slice and draws text left-aligned after icon width and
spacing. Centering arbitrary entry labels would require changing GRUB itself;
no unsupported property, title-padding hack or misleading preview is used.

The read-only inspection of `/etc/grub.d/10_linux` declares distribution, `gnu-linux`, `gnu`
and `os` classes. Recovery normally inherits Linux classes rather than declaring
`recovery`. The installed `30_uefi-firmware` and Linux Advanced submenu do not
declare icon classes, so those entries remain iconless. No generators or entry
definitions are changed to force icons.

There is no native live-clock theme component. GRUB's `date` command can display
firmware time in its console; `datehook` exposes date/time variables, but neither
provides a periodically refreshed theme label or reliable local-time conversion.
A true live clock would require additional GRUB code/module work. No build-time
clock, boot-time snapshot, RTC timezone assumption or fake static time is added.
The only changing time display is the real automatic-boot countdown.

References: [GNU GRUB theme manual](https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html)
and upstream [gui_list.c](https://github.com/rhboot/grub2/blob/master/grub-core/gfxmenu/gui_list.c)
(`get_num_shown_items`, `draw_menu`, `make_selected_item_visible`),
[theme_loader.c](https://github.com/rhboot/grub2/blob/master/grub-core/gfxmenu/theme_loader.c)
(`parse_proportional_spec`, percentage plus/minus pixel offsets), and
[gui_label.c](https://github.com/rhboot/grub2/blob/master/grub-core/gfxmenu/gui_label.c)
(`label_set_property`, `label_set_state`, supported `%d` timeout template).

## Classic

`grub/classic/` is unchanged: black, white `#e0e0e0`, blue `#008ec4`, Terminus
Bold 22/18 px, and a three-second visible countdown. It is a simpler gfxterm
alternative, not a pure-console profile. Switching to it retains the installed
Midnight directory. Neither profile switch removes unrelated theme directories.

## Apply Safely

Run from the repository:

```bash
bash scripts/apply-grub-profile.sh --help
sudo bash scripts/apply-grub-profile.sh --profile graphical
sudo bash scripts/apply-grub-profile.sh --profile graphical --size large
```

Type `APPLY`. The helper installs the theme **and** generates the configuration;
running only `grub-mkconfig` would not install or activate the repository assets.
No `grub-install`, EFI changes, package installation or reboot is performed.
Omitting `--size` selects compact. `--size normal` and `--size large` are explicit
alternatives; `--profile classic --size ...` and invalid sizes are rejected before
any writes. Only the selected self-contained variant is deployed to
`/usr/share/grub/themes/arch/theme.txt` and its sibling assets. The canonical
`GRUB_THEME` path stays unchanged. PF2s are installed beside the theme, where
Arch's `00_header` enumerates them into `loadfont` commands; no Pillow, Fontconfig
or font generator is needed for application. Failure restores the previous
variant's complete directory along with defaults and `grub.cfg`.

The helper requires regular root-owned defaults and `grub.cfg`, takes an
exclusive profile-update lock, and creates a unique mode-0700 directory under
`/var/lib/arch-linux-config/grub-backups/`. It backs up `default-grub`, `grub.cfg`
and the replaced `theme/`, preserving metadata. Generator output and validation
diagnostics stay in that private directory because they can contain disk IDs.

Only timeout, terminal, graphics mode, theme/background, palette and recovery
settings are merged. Kernel command lines, saved/default selection, payload,
encryption, UUID handling, OS probing and `/etc/grub.d` are preserved. The
ordinary single-line assignment format in `/etc/default/grub` is expected;
do not use this helper with custom shell control flow or multiline display
assignments. Do not run other boot-management tools concurrently.

Assets are staged as root-owned readable files. `grub-mkconfig` writes a temporary
file on the boot filesystem; `grub-script-check`, theme, menu and timeout checks
must pass before it replaces `grub.cfg`. Errors or handled interrupts restore
defaults, assets and the previous generated configuration. This is not a
power-loss-safe filesystem transaction. Reapplying does not duplicate settings,
though each application keeps a fresh backup and regenerates the menu.

Regeneration reflects currently installed kernels and the existing generators;
it does not guarantee byte-for-byte preservation of stale generated entries.
Keep recovery media available. Both profiles now allow three seconds for intervention.

## Recovery

To return to the simpler profile (including its three-second timeout):

```bash
sudo bash scripts/apply-grub-profile.sh --profile classic
```

If graphics itself fails, press `C` at the menu and enter `terminal_output console`
to switch to GRUB's text terminal, then `normal` to return to the menu. This
requires a working keyboard/console and is not guaranteed on every firmware.
For persistent text output set `GRUB_TERMINAL_OUTPUT=console` and comment out
`GRUB_THEME` in `/etc/default/grub`, then regenerate GRUB.

For exact rollback, use the backup path printed by the helper. For a graphical
application, replace the example path below with that actual directory:

```bash
backup=/var/lib/arch-linux-config/grub-backups/ACTUAL_BACKUP_DIRECTORY
sudo test -f "$backup/default-grub" && sudo test -f "$backup/grub.cfg"
sudo cp -a -- "$backup/default-grub" /etc/default/grub
sudo cp -a -- "$backup/grub.cfg" /boot/grub/grub.cfg
```

If that backup contains `theme/`, restore it to `/usr/share/grub/themes/arch`
before rebooting (use `arch-classic` for a classic application). Remove the
replacement directory first so old and new assets are not mixed. If no theme
backup exists, the directory was newly installed; the restored defaults and
configuration no longer reference it. Exact rollback restores the saved
`grub.cfg` directly; do not regenerate it unless intentionally updating it.

## Verification

```bash
bash -n scripts/apply-grub-profile.sh
python3 tests/grub-profile.py
python3 grub/generate-theme.py --build-assets
python3 grub/render-preview.py --output /tmp/opencode
python3 grub/render-preview.py --selected 7 --output /tmp/opencode
python3 grub/render-preview.py --entries fixture-long --selected 29 --output /tmp/opencode
python3 grub/render-preview.py --entries actual --output /tmp/opencode
python3 grub/render-preview.py --entries actual-advanced --selected 1 --output /tmp/opencode
python3 grub/render-preview.py --size normal --resolution 1920x1200 --entries actual --output /tmp/opencode
python3 grub/render-preview.py --size large --entries actual --output /tmp/opencode
python3 grub/render-preview.py --size large --resolution 1920x1200 --console --output /tmp/opencode
```

The tests use isolated paths and mocked configuration generation, including
failure rollback between sizes, invalid-argument no-write checks, supported theme
properties, PF2 ink bounds and byte-identical theme/asset/font regeneration.
The renderer defaults to each variant's target modes: compact 640x480, 800x600,
1024x768; normal 1280x720, 1366x768, 1600x900; large 1920x1080, 1920x1200,
2560x1440. `--resolution WIDTHxHEIGHT` selects one mode, including normal at
1920x1200 for direct comparison. Previews use the actual theme geometry,
PNG assets and bundled PF2 bitmaps/advances. Both selection 0 and selection 7
are supported for the original eight illustrative fixtures, not additional
installed boot entries. `fixture-long` adds 30 synthetic options, not host entries.
Separate `actual` and `actual-advanced` previews use a
sanitized 2026-09-14 snapshot read without privileges from `/boot/grub/grub.cfg`:
three main entries (Arch Linux, Advanced options for Arch Linux, UEFI Firmware
Settings), with two Linux entries inside Advanced. Firmware display remains
conditional on EFI support. Only titles/classes were retained, never kernel
arguments, IDs or full configuration. Both Advanced and UEFI have no classes
and remain iconless. There is no Windows entry in this snapshot.
All main titles fit every tested size. The longer real recovery title clips at
640 and slightly at 800, matching the `gui_list.c` viewport; it fits compact at
1024. Normal/large's fixed text boxes can clip the recovery title at all modes;
they deliberately prioritize typical main titles over arbitrarily long names.
The renderer uses viewport clipping, not wrapping, ellipses or fake centering.
Snapshot image names include `actual` or `actual-advanced`, distinct from fixtures.
No host menu or generators are changed. These are not actual GRUB boots.
For actual selection 0, convenient filenames are `normal-1920x1200.png` and
`large-1920x1200.png`. When both exist in the output directory, the renderer
also writes `comparison-1920x1200.png`, a 3840x1224 side-by-side sheet with no
resizing (24 px label strip). Ordinary overview contact sheets are thumbnails,
not suitable for judging relative font size. Regenerate both comparison images
after changes to avoid comparing stale files.
The arrow uses the real fallback glyph, but its monochrome PF2 rasterization is
not pixel-identical to Alacritty's antialiasing. Rebuild commands and font licenses
are documented in `grub/README.md`.
`grub-script-check` validates GRUB scripts,
not `theme.txt`. Static asset/layout checks cannot replace a firmware/VM boot
test of gfxmenu rendering, font loading, scrolling or recovery navigation.

## Panel Layering Fix

On 2026-09-14, read-only comparison found `/usr/share/grub/themes/arch` identical
to the pre-fix generated `large` variant, including fonts and PNGs. The active
`/boot/grub/grub.cfg` references that path, loads the large fonts and specifies
a three-second timeout. This was not a stale asset path or a failed application.

The official GRUB 2.14 source establishes the cause:

- `grub-core/gfxmenu/theme_loader.c:570` adds each parsed component to its parent.
- `grub-core/gfxmenu/gui_canvas.c:204-214` prepends it to the child list.
- `grub-core/gfxmenu/gui_canvas.c:90-149` paints that list in forward list order,
  hence reverse theme declaration order, at the root and inside nested canvases.
- `canvas_set_property` and `image_set_property` implement `id` as an identifier,
  not depth. No `z-index` property is used or supported by those setters.

The alpha-204 black panel was declared before the foreground, so GRUB painted
it over text, icons, countdown and help. It now comes last in `theme.template`;
all three generated variants and the root compact snapshot were regenerated.
Opacity, wallpaper, fonts, geometry, selection assets and classic are unchanged.
The preview no longer precomposites/skips the panel: it paints ordinary images
in GRUB's reverse sibling order, recursively. The 13-test suite includes an
independent nested-order fixture and deliberately broken ordering in each size,
in addition to full foreground/row/background pixel and deployment checks.
No apply-helper change was needed: it already deploys the selected variant
byte-for-byte, which the sandbox tests verify.

A real GRUB 2.14 UEFI boot was also tested using installed `grub-mkrescue`,
`xorriso` and VirtualBox, with a disposable 2-CPU/2048-MiB VM, no hard disk and
no network. A new lightweight ISO contains only GRUB, the large candidate and
a read-only copy of the installed pre-fix theme. No Arch installer was run.
At 1920x1200, the old theme reproduces dim foreground and the candidate restores
bright text/icons while retaining the same darkened wallpaper. Moving selection
erases the old arrow cleanly and cancels the countdown. The VM was powered off
and unregistered afterward; existing VMs were not modified.
Pixel comparison found 9,174 white menu glyph pixels (`#ffffff`) in the fixed
capture at coordinates that were all `#333333` before the fix. Sampled exterior
wallpaper and empty panel regions were byte-identical between captures.

Local evidence (temporary artifacts, not repository assets):

- `/tmp/opencode/grub-2.14/`: extracted official release source.
- `/tmp/opencode/grub-layer-vm/layers.iso`: boot-only comparison ISO.
- `/tmp/opencode/grub-layer-vm/iso/boot/grub/`: fixture configs and both themes.
- `/tmp/opencode/grub-layer-vm/before-boot.png`: real pre-fix GRUB capture.
- `/tmp/opencode/grub-layer-vm/fixed-boot.png`: real corrected GRUB capture.
- `/tmp/opencode/grub-layer-vm/fixed-selection.png`: real selection repaint.

The fixture uses explicitly labeled display-only entries and a 300-second timer
for capture, not host boot commands or production timeout settings. Only large
at this UEFI mode received real boot validation; other sizes/modes have automated
preview tests. This does not validate Linux boot, recovery, E/C transitions or
physical firmware. No host `/boot` or defaults were changed, packages installed,
services changed, host reboot performed, or commits created.

To deploy the corrected large variant later, from the repository:

```bash
sudo bash scripts/apply-grub-profile.sh --profile graphical --size large
```

Type `APPLY`; retain the printed backup path. Running only `grub-mkconfig` will
not replace the installed theme. Do not omit `--size large` if retaining that
size, since the helper defaults to compact.

## Console and Boot Output

Read-only host inspection found the large theme, `gfxterm`, a one-second generated
timeout, `gfxpayload=keep`, and a loaded Regular 18 PF2. Missing terminal fonts
were not established as the cause. The old terminal occupied x=10% through 90%,
sharing the blue frame's side coordinates, without an explicit opaque styled box.
Upstream `view.c:terminal_sanity_check` also enforces at least 80 columns and 24
rows and can enlarge/recenter undersized windows, especially at 640x480.

All graphical variants now define an opaque black nine-slice `terminal-box`,
8 px padding and a window at 6% x/y with 88% width and 80% height. The box stays
inside the expanded blue frame and above the footer. Compact uses Regular 12 px
to satisfy the minimum terminal size; normal/large retain Regular 18 px.
Tests check the font metrics, box opacity, deployment and geometric margins.
The menu's alpha panel does not change this opaque E/C box or console colors.

Moving the menu selection is not the same as opening the E editor or C command
line, executing a boot entry, or receiving Linux/initramfs messages. The theme
controls GRUB's terminal decoration, not the kernel's console. `GRUB_GFXPAYLOAD_LINUX`
is preserved: `keep` retains the graphics mode, and changing it to `text` is not
a portable UEFI framebuffer-clearing fix. Kernel parameters and generators are
also untouched. The observed boot-transition cause remains unconfirmed without
a real boot or a photograph showing the message and when it appears.

`--console` writes separately named illustrative console previews. They are not
runtime captures and do not demonstrate firmware or kernel handoff behavior.
The earlier console investigation had no real boot capture. The subsequent
VirtualBox layering test above covers the menu only, not console or kernel
handoff. No host boot configuration was applied or packages installed.
