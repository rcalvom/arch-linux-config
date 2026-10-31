# GRUB Themes

`theme/` contains Midnight Terminal, Ricardo's graphical profile using the
Alacritty palette and personal dark-blue accent. `classic/` remains the installer/live-ISO default and the
alternative terminal-style presentation. Both use gfxterm and bundled PF2 fonts.

From the repository, activate Midnight with:

```bash
sudo bash scripts/apply-grub-profile.sh --profile graphical
sudo bash scripts/apply-grub-profile.sh --profile graphical --size large
```

Type `APPLY` when prompted. This installs the assets, merges the display settings
and three-second visible timeout, enables recovery entries, then runs
`grub-mkconfig` and `grub-script-check`. Do not copy the whole defaults file over
an existing installation, or run the legacy `theme/install.sh`.

See [profiles, backups and recovery](../docs/grub.md) before applying.

`--size compact|normal|large` is explicit and graphical-only; omitted means
compact. Classic rejects `--size`. The installer and live ISO still use classic.
Each selected variant is deployed with its fonts, icons and licenses to the same
canonical `arch/theme.txt` path. Application does not require Pillow or font tools.

## Shared Size Source

Edit only `theme.template` and `sizes.json` for layout changes, then regenerate.
`theme/variants/{compact,normal,large}/` contains generated, self-contained GRUB
assets intended to be versioned. `theme/theme.txt` is the generated compact snapshot,
not a fourth source. Existing compact font/icon sources remain available at the
theme root; variants derive from those shared icon masks and keycaps.

| Size | Target Modes | Bold Title / Regular Menu / Footer | Rows | Menu Width |
| --- | --- | --- | --- | --- | --- |
| compact | 640x480-1024x768 | 24 / 22 / 18 px | 3 | `40%+240` |
| normal | 1280x720-1600x900 | 30 / 28 / 22 px | 5 | 660 px |
| large | 1920x1080-2560x1440 | 36 / 32 / 24 px | 5 | 760 px |

All variants share the 94% x 94% frame at 3% from the edges and 2 px blue border. Title, menu and
counter share a 32%-height origin with fixed offsets. Large at 1920x1200 places
them at y=384/472/780; normal places them at y=384/456/738. The footer remains
anchored to the panel bottom and spans its width. Three actual entries stay
top-aligned in the viewport, not dynamically centered by entry count. Five-row
variants reserve two empty rows, while long fixtures exercise all five rows.

Development dependencies on Arch: `python-pillow`, `grub` and `fontconfig`, plus
the actual UbuntuMono Nerd Font Regular/Bold and Adwaita Mono Bold TTFs for font
rebuilds. None are installed by the generator or helper.

```bash
python3 grub/generate-theme.py
python3 grub/generate-theme.py --build-assets
python3 grub/generate-theme.py --build-assets --build-fonts
```

The first command regenerates theme text only. `--build-assets` copies bundled
PF2s/licenses and regenerates PNGs deterministically. `--build-fonts` explicitly
invokes `fc-match` and `grub-mkfont` for real size-specific bitmaps and verifies
their full PF2 family/style/size names, rejecting unexpected font fallback.
Use `--output EXISTING_DIRECTORY` to regenerate outside the source tree.
No dynamic metadata or timestamps are embedded. Tests compare full regenerated
trees byte-for-byte, including a font rebuild and repeated asset-only rebuilds.
Byte identity assumes the same source fonts and grub-mkfont/Pillow versions.

## Design Assets

Midnight Terminal uses bundled UbuntuMono Nerd Font PF2s at the sizes above;
the separate GRUB terminal uses Regular 12 px in compact and 18 px otherwise. No font generation or package
installation is needed to apply it.
The centered cyan Bold title, `Select an operating system or an option`, fits
on one line at all target modes, including compact at 640x480.
The new ASCII-only Footer family avoids replacing the existing terminal font.
The inspected local Alacritty font is UbuntuMono Nerd Font at 12 pt, approximately
16 px at 96 DPI before monitor scaling. The active Hyprland scale was unavailable
in the editing session. GRUB's PF2 size is a pixel rasterization size, not points;
bitmap ink bounds and firmware resolution affect perceived size. These larger
sizes improve readability without claiming an exact Alacritty match.
The 39-character title advances 468 px inside 565 px at 640x480.
Selected and unselected entries and action hints are pure white; the countdown
is Alacritty bright yellow `#f3e430`, centered across the full inner panel width,
with the supported timeout template `Booting in %d s`.
Three RGBA selection slices draw only the real green U+279C glyph, with no
row fill. All non-glyph pixels, including the entire center/east slices, have
zero alpha. West slices are 36/45/54 px, arrow slots and icons are 24/30/36 px,
and icon-to-text spacing is 12/15/18 px for compact/normal/large.
GRUB's `gui_list.c:draw_menu` draws the selected pixmap box through
[`widget-box.c:blit`](https://github.com/rhboot/grub2/blob/master/grub-core/gfxmenu/widget-box.c),
which uses `GRUB_VIDEO_BLIT_BLEND`. In
[`view.c`](https://github.com/rhboot/grub2/blob/master/grub-core/gfxmenu/view.c),
changing selection redraws the menu region's wallpaper before repainting the
canvas, including the alpha panel and new arrow. This restores the old arrow's
background rather than depending on an opaque row to erase it. Previews blend
the actual selection PNGs; firmware repaint behavior still needs a boot test.
One blue pixel image draws all four border edges at 2 px, matching the local and
repository Hyprland `border_size` (not 3 px), at responsive dimensions;
the background is the managed `qtile/wallpapers/wallpaper2.png`, copied without
dimming into `background.png`. The source is unchanged and was byte-identical to
`~/Pictures/wallpaper2.png` during read-only inspection. GRUB's supported
`desktop-image-scale-method: "crop"` fills the screen without stretching.
The generated 1x1 RGBA `panel.png` is black with alpha 204/255, matching the
read-only local Alacritty opacity of 0.8. A standard image widget scales it to
the frame interior (3%+2 px origin, 94%-4 px dimensions), leaving the 2 px blue
border and exterior wallpaper untouched. This is static wallpaper blending,
not a desktop compositor or transparency of GRUB's E/C terminal. Upstream
[gui_image.c](https://github.com/rhboot/grub2/blob/master/grub-core/gfxmenu/gui_image.c)
rescales images and paints them with `GRUB_VIDEO_BLIT_BLEND`; no unsupported
theme opacity property is used. The generator records the opacity explicitly
and never reads host configuration. The preview blends the same PNG once after
cropping the wallpaper. Firmware rendering and rounding can differ; a real
boot remains untested.
There is no title bar or shell-prefix heading.
Five proportionally scaled PNG keycap assets draw up/down, return, E, C and Escape, without
font symbols. Compact labels (`select`, `boot`, `edit`, `console`, `back`) span
one horizontal row in a standard GRUB `canvas`. Complete key/label groups are
centered at 10/30/50/70/90% of its inner width using half-group pixel offsets
and 6/7/8 px key-to-label gaps. Labels remain left-aligned. Compact group widths are
96/64/58/85/70 px, fitting the 113 px slots even at 640x480. The help canvas uses
16 px side insets; the title and counter retain 18 px insets.
All keycaps and class icons use Alacritty bright cyan `#4fb8cc`. Class icon
silhouettes fit a centered 20 px envelope within 24x24 PNGs. Alpha coverage is
capped at 140 opaque-pixel equivalents in compact, then proportionally scaled
for normal/large to keep dense logos from overpowering
outline icons; shapes are not replaced. Two original generic icons add `os` and
`settings` matches. Entries without matching classes remain iconless.

The compact menu uses `left = 30%-120`, `width = 40%+240`: 496 px at 640.
Normal/large use `left = 50%-330` / `50%-380` with fixed 660/760 px widths.
Compact's viewport uses `top = 32%+48`, `height = 128`: three 36 px rows,
two 6 px gaps and 4 px padding at each end. Normal uses five 44 px rows with
8 px gaps and 5 px padding; large uses five 48 px rows with 8 px gaps and 6 px
padding. Longer menus scroll without a scrollbar.
GRUB does not dynamically center the entries by count or expose `max_shown_items`;
two-entry submenus retain this same viewport. The title and footer stay in place.
`theme_loader.c:parse_proportional_spec` supports these percentage/pixel sums.
GRUB 2.14 does not support `item_align`: `gui_list.c`
draws entry text at x=0 inside its text viewport, after the selection slice,
icon width and icon spacing. Individual entry titles remain left-aligned;
the preview deliberately does not fake centered entries.

With Pillow installed, regenerate selection/keycap assets and illustrative previews into an
existing directory:

```bash
python3 grub/render-preview.py --build-assets --output /tmp/opencode
python3 grub/render-preview.py --selected 7 --output /tmp/opencode
python3 grub/render-preview.py --entries fixture-long --selected 29 --output /tmp/opencode
python3 grub/render-preview.py --entries actual --output /tmp/opencode
python3 grub/render-preview.py --entries actual-advanced --selected 1 --output /tmp/opencode
python3 grub/render-preview.py --size normal --resolution 1920x1200 --entries actual --output /tmp/opencode
python3 grub/render-preview.py --size large --entries actual --output /tmp/opencode
python3 grub/render-preview.py --size large --resolution 1920x1200 --console --output /tmp/opencode
python3 grub/render-preview.py --size large --entries fixture-long --selected 29 --output /tmp/opencode
```

The renderer's legacy `--build-assets` rebuilds shared compact PNG sources only;
follow it with `generate-theme.py --build-assets` to propagate changes to variants.
Omit `--build-assets` to render previews only. Geometry and labels are read from
the theme, and text uses the bundled PF2 bitmaps, metrics and glyph advances.
These images are not GRUB screenshots or firmware validation. The default eight
sample entries still exercise class matching and scrolling independently.
`fixture-long` provides 30 synthetic entries for first/last selection checks;
it does not generate or install boot entries.
`actual` uses only the three main titles/classes read without privileges from
`/boot/grub/grub.cfg` on 2026-09-14: Arch Linux, Advanced options for Arch Linux,
and UEFI Firmware Settings (conditional on firmware support). `actual-advanced`
uses its two Linux entries, not additional main-menu entries. The submenu preview
hides the countdown, cancelled when navigating into Advanced. No kernel commands,
arguments, IDs, UUIDs or raw configuration are stored. This is a dated snapshot,
not a live host reader. No classes are inferred from titles: Advanced and firmware
have none and remain iconless. Linux declares `arch`, `gnu-linux`, `gnu`, `os`.
The 44-character recovery title is clipped to the real gfxmenu text viewport at
640 and slightly at 800; it fits compact at 1024. Normal/large can clip this
long recovery title because their fixed menu widths target typical main titles.
All three main titles fit every target mode. No ellipsis,
wrapping or fake overflow is painted.
Outputs are named `grub-terminal-WIDTHxHEIGHT-selected-INDEX.png`.
Snapshot filenames insert `-actual` or `-actual-advanced` after `grub-terminal`,
so they never replace the eight-entry validation previews.
By default only the selected variant's target modes are rendered: compact at
640x480, 800x600, 1024x768; normal at 1280x720, 1366x768, 1600x900; large at
1920x1080, 1920x1200, 2560x1440. `--resolution WIDTHxHEIGHT` overrides this for
comparison. Normal/large filenames start with `SIZE-ENTRYSET`; compact retains
the existing prefix. Overview contact sheets use thumbnails. Actual selection 0
also produces `SIZE-WIDTHxHEIGHT.png`; when both normal/large images exist,
`comparison-WIDTHxHEIGHT.png` places them side by side at 1:1 pixels with a label
strip, without resizing. Regenerate both after changes to avoid stale comparisons.
The renderer resolves nested
canvas coordinates and selects PF2 assets by full family, weight and size,
not just size. No automatic variant selection is performed at boot or in previews.

The small 16/18-footer/22 px PF2 files contain printable ASCII only and were generated
with the already installed tool and font (existing fonts remain untouched):

```bash
grub-mkfont -s 22 -r 0x20-0x7e -o grub/theme/UbuntuMonoNerdFont-Regular-22.pf2 \
  "$HOME/.local/share/fonts/UbuntuMonoNerdFont-Regular.ttf"
grub-mkfont -s 16 -r 0x20-0x7e -o grub/theme/UbuntuMonoNerdFont-Regular-16.pf2 \
  "$HOME/.local/share/fonts/UbuntuMonoNerdFont-Regular.ttf"
grub-mkfont -s 18 -n 'UbuntuMono Nerd Font Footer' -r 0x20-0x7e \
  -o grub/theme/UbuntuMonoNerdFont-Footer-Regular-18.pf2 \
  "$HOME/.local/share/fonts/UbuntuMonoNerdFont-Regular.ttf"
fc-match -f '%{file}\n%{family}\n%{style}\n' 'UbuntuMono Nerd Font:style=Bold'
grub-mkfont -s 24 -r 0x20-0x7e -o grub/theme/UbuntuMonoNerdFont-Bold-24.pf2 \
  "$HOME/.local/share/fonts/UbuntuMonoNerdFont-Bold.ttf"
```

The Bold source above was resolved read-only on the host. Its generated PF2
NAME is `UbuntuMono Nerd Font Bold 24` and WEIG is `bold`; no synthetic bold
flag or renamed Regular glyphs are used. Both weights advance the full heading
468 px. The source is Nerd Fonts' `patched-fonts/UbuntuMono/Bold/UbuntuMonoNerdFont-Bold.ttf`:
https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/UbuntuMono

Run those commands from the repository root only when rebuilding the bundled fonts.
The existing third-party font terms still apply; see `THIRD_PARTY_NOTICES.md`
and the bundled `theme/Ubuntu-FONT-LICENCE.txt`.
UbuntuMono Nerd Font has no U+279C glyph. The local Fontconfig fallback for
Ginger's bold arrow is Adwaita Mono Bold, verified with:

```bash
fc-match -f '%{file}\n' 'UbuntuMono Nerd Font:style=Bold:charset=279c'
grub-mkfont -s 24 -r 0x279c-0x279c -o grub/theme/AdwaitaMono-Bold-24-arrow.pf2 \
  /usr/share/fonts/Adwaita/AdwaitaMono-Bold.ttf
```

The bundled one-glyph PF2 is the source for the selection PNG. This uses the
actual U+279C outline, not a substitute drawing or missing-glyph rectangle.
PF2 monochrome rasterization at 24 px is not pixel-identical to Alacritty's
antialiased rendering at its configured size. See `theme/Adwaita-FONT-LICENSE.txt`.
The Python generator deterministically renders PNGs from bundled glyphs and
normalized icon alpha masks; repeated builds are byte-identical and need no host
font lookup to rebuild assets.
No clock is painted: standard GRUB themes cannot provide a live wall-clock label.

## Canvas Layering

GRUB 2.14 paints canvas siblings in reverse declaration order, including the
implicit root canvas. `theme_loader.c:570` calls the parent's `add` operation;
`gui_canvas.c:204-214` prepends each child, and `canvas_paint` at lines 90-149
walks that list from its head. Declare the full-panel image **last**, behind
the title, boot menu, countdown and nested help canvas. `id` is an identifier,
not a stacking control; these components implement no `z-index` property.
Sources refer to the official [GRUB 2.14 release archive](https://ftp.gnu.org/gnu/grub/grub-2.14.tar.xz),
under `grub-core/gfxmenu/`, rather than a moving development branch.

The former panel-before-text order darkened every foreground pixel by 80%.
The old preview concealed this by precompositing the panel into the wallpaper
and skipping it during component painting. The renderer now reverses siblings
at every canvas level and paints the panel as an ordinary image. `desktop()`'s
optional panel composition is only a reference for pixel tests, not the initial
render surface. Tests deliberately restore the bad order in a sandbox and
require the preview to reproduce foreground dimming for all three variants.
Normal rendering checks white text, cyan labels/icons, yellow countdown, green
selection, transparent row backgrounds and unchanged exterior wallpaper.

See [real boot evidence and deployment](../docs/grub.md#panel-layering-fix).

## Console Separation

The console has opaque black nine-slice `console_*.png` assets, an 8 px inner
border and an 88% x 80% text window starting at 6% x/y. Its decoration remains
inside the blue frame and above the footer at all target modes. The terminal
replaces the central menu area, rather than preserving the menu title behind text.
GRUB enforces a minimum 80-column/24-row terminal in `view.c:terminal_sanity_check`;
compact uses 12 px so low resolutions do not trigger expansion over the frame.
The console preview illustrates the intended rectangle, not actual E/C behavior,
boot output or Linux framebuffer clearing. See [diagnosis and limits](../docs/grub.md#console-and-boot-output).
