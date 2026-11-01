#!/usr/bin/env python3
"""Build Midnight Terminal assets and illustrative previews, not GRUB screenshots.

Requires Pillow; no host changes. Reads geometry, colors, PNGs and PF2 glyphs
from the theme. Firmware video modes still require a real boot test.
"""

import argparse
import json
import re
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

SIZES = ((640, 480), (800, 600), (1024, 768), (1280, 720),
         (1366, 768), (1600, 900), (1920, 1080), (1920, 1200), (2560, 1440))
PROFILES = json.loads((Path(__file__).resolve().parent / "sizes.json").read_text())

# Only titles/classes, transcribed read-only from grub.cfg on 2026-09-14.
# Firmware is conditional on EFI fwsetup support, not nested in Advanced.
LINUX_CLASSES = ("arch", "gnu-linux", "gnu", "os")
ENTRIES = {
    "fixture": (("Arch Linux", ("arch",)), ("Advanced options for Arch Linux", ()),
                ("Windows Boot Manager", ("windows",)), ("UEFI Firmware Settings", ()),
                ("Arch Linux (fallback initramfs)", ("arch",)),
                ("Linux (recovery mode)", ("gnu-linux",)),
                ("Other operating system", ("os",)), ("Custom entry without classes", ())),
    "actual": (("Arch Linux", LINUX_CLASSES), ("Advanced options for Arch Linux", ()),
               ("UEFI Firmware Settings", ())),
    "actual-advanced": (("Arch Linux, with Linux linux", LINUX_CLASSES),
                        ("Arch Linux, with Linux linux (recovery mode)", LINUX_CLASSES)),
    "fixture-long": tuple((f"Sample boot option {index + 1:02d}", ("os",)) for index in range(30)),
}


def coord(value, extent):
    match = re.fullmatch(r"(\d+)%([+-]\d+)?", value)
    return extent * int(match[1]) // 100 + int(match[2] or 0) if match else int(value)


def parse_components(source):
    root = []
    stack = [root]
    for line in source.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("+ "):
            kind = re.fullmatch(r"\+ (label|boot_menu|image|canvas) \{", line)[1]
            node = {"kind": kind, "children": []}
            stack[-1].append(node)
            stack.append(node["children"])
        elif line == "}":
            stack.pop()
        elif len(stack) > 1:
            key, value = line.split("=", 1)
            stack[-2][-1][key.strip()] = value.strip().strip('"')
    if len(stack) != 1:
        raise ValueError("Unbalanced theme components")
    return root


def layout(components, width, height, left=0, top=0):
    # GRUB 2.14 gui_canvas.c:canvas_add prepends; canvas_paint walks that list.
    # Apply this at every canvas level, including the implicit root canvas.
    for component in reversed(components):
        props = {k: v for k, v in component.items() if k != "children"}
        for key, extent in (("left", width), ("top", height), ("width", width), ("height", height)):
            props[key] = str(coord(props[key], extent))
        props["left"] = str(int(props["left"]) + left)
        props["top"] = str(int(props["top"]) + top)
        if props["kind"] == "canvas":
            yield from layout(component["children"], int(props["width"]), int(props["height"]),
                              int(props["left"]), int(props["top"]))
        else:
            yield props


def load_font(path, with_name=False):
    data = path.read_bytes()
    sections = {}
    offset = 0
    while offset < len(data):
        name, length = struct.unpack_from(">4sI", data, offset)
        offset += 8
        if name == b"DATA":
            break
        sections[name] = data[offset:offset + length]
        offset += length
    glyphs = {}
    for code, flags, location in struct.iter_unpack(">IBI", sections[b"CHIX"]):
        width, height, x, y, advance = struct.unpack_from(">HHhhh", data, location)
        bitmap = data[location + 10:location + 10 + (width * height + 7) // 8]
        glyphs[code] = (width, height, x, y, advance, bitmap)
    font = (int.from_bytes(sections[b"ASCE"], "big"),
            int.from_bytes(sections[b"DESC"], "big"), glyphs)
    return (sections[b"NAME"].rstrip(b"\0").decode(), font) if with_name else font


def draw_text(image, position, text, font, color):
    x, baseline = position
    for char in text:
        width, height, dx, dy, advance, bitmap = font[2][ord(char)]
        if width and height:
            mask = Image.new("L", (width, height))
            mask.putdata([255 if bitmap[i // 8] & (1 << (7 - i % 8)) else 0
                          for i in range(width * height)])
            image.paste(color, (x + dx, baseline - dy - height,
                               x + dx + width, baseline - dy), mask)
        x += advance


def desktop(theme_dir, width, height, with_panel=True):
    """Wallpaper, optionally with panel for test references; filters differ."""
    with Image.open(theme_dir / "background.png") as asset:
        image = ImageOps.fit(asset.convert("RGB"), (width, height), method=Image.Resampling.LANCZOS)
    for props in layout(parse_components((theme_dir / "theme.txt").read_text()), width, height):
        if with_panel and props.get("file") == "panel.png":
            x, y, w, h = (int(props[k]) for k in ("left", "top", "width", "height"))
            with Image.open(theme_dir / props["file"]) as asset:
                panel = asset.resize((w, h))
                image.paste(panel, (x, y), panel)
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Existing preview directory")
    parser.add_argument("--build-assets", action="store_true", help="Regenerate terminal PNG assets")
    parser.add_argument("--size", choices=PROFILES, default="compact", help="Explicit theme size (default: compact)")
    parser.add_argument("--resolution", help="Render one WIDTHxHEIGHT instead of the size's target modes")
    parser.add_argument("--selected", type=int, default=0)
    parser.add_argument("--console", action="store_true", help="Illustrate terminal bounds, not a boot transition")
    parser.add_argument("--entries", choices=ENTRIES, default="fixture",
                        help="Illustrative 8/30-entry fixtures or sanitized host snapshot (2026-09-14)")
    args = parser.parse_args()
    if not args.output.is_dir():
        parser.error("The output directory must already exist")
    sizes = PROFILES[args.size]["resolutions"]
    if args.resolution:
        if not re.fullmatch(r"[1-9]\d*x[1-9]\d*", args.resolution):
            parser.error("--resolution must be WIDTHxHEIGHT")
        sizes = [tuple(map(int, args.resolution.split("x")))]
    if args.build_assets and args.size != "compact":
        parser.error("Use generate-theme.py --build-assets to rebuild size variants")
    entries = ENTRIES[args.entries]
    if not 0 <= args.selected < len(entries):
        parser.error("Selected index is outside this entry set")
    prefix = "grub-terminal" + (f"-{args.entries}" if args.entries != "fixture" else "")
    theme_dir = Path(__file__).resolve().parent / "theme"
    if args.build_assets:
        # UbuntuMono lacks U+279C. Fontconfig resolves Ginger's bold arrow to Adwaita Mono.
        arrow_font = load_font(theme_dir / "AdwaitaMono-Bold-24-arrow.pf2")
        glyph_width, glyph_height, dx, dy, _, _ = arrow_font[2][0x279c]
        for edge, width in (("w", 36), ("c", 1), ("e", 1)):
            asset = Image.new("RGBA", (width, 36), (0, 0, 0, 0))
            if edge == "w":
                # Keep the glyph in its original 24 px slot; add 12 px after it.
                draw_text(asset, ((24 - glyph_width) // 2 - dx,
                                  (36 - glyph_height) // 2 + glyph_height + dy),
                          "\u279c", arrow_font, "#10a778")
            asset.save(theme_dir / f"midnight-select_{edge}.png")
        Image.new("RGB", (1, 1), "#033e8c").save(theme_dir / "terminal-edge.png")
        # Keycap strokes are original vector artwork, not font symbols.
        for name, width in (("arrows", 36), ("enter", 22), ("escape", 28), ("e", 16), ("c", 16)):
            asset = Image.new("RGB", (width, 16), "#000000")
            pen = ImageDraw.Draw(asset)
            for left, right in ((0, 15), (20, 35)) if name == "arrows" else ((0, width - 1),):
                pen.rounded_rectangle((left, 0, right, 15), radius=2, outline="#4fb8cc")
            strokes = {
                "arrows": [[(7, 11), (12, 6), (17, 11)], [(12, 6), (12, 18)],
                           [(37, 12), (42, 17), (47, 12)], [(42, 6), (42, 17)]],
                "enter": [[(24, 6), (24, 13), (8, 13)], [(13, 8), (8, 13), (13, 18)]],
                "e": [[(16, 6), (8, 6), (8, 18), (16, 18)], [(8, 12), (15, 12)]],
                "c": [[(16, 6), (8, 6), (8, 18), (16, 18)]],
                "escape": [[(12, 7), (6, 7), (6, 17), (12, 17)], [(6, 12), (11, 12)],
                           [(23, 7), (17, 7), (17, 12), (23, 12), (23, 17), (17, 17)],
                           [(34, 7), (28, 7), (28, 17), (34, 17)]],
            }
            for points in strokes[name]:
                pen.line([(round(x * 2 / 3), round(y * 2 / 3)) for x, y in points],
                         fill="#4fb8cc", width=1)
            asset.save(theme_dir / f"key-{name}.png")
        # Original generic class icons; distribution silhouettes retain their shapes.
        for name in ("os", "settings"):
            asset = Image.new("RGBA", (24, 24))
            pen = ImageDraw.Draw(asset)
            pen.rectangle((3, 4, 20, 17), outline="#4fb8cc", width=2)
            pen.line((7, 21, 17, 21), fill="#4fb8cc", width=2)
            if name == "settings":
                pen.line((8, 8, 15, 13), fill="#4fb8cc", width=2)
            asset.save(theme_dir / "icons" / f"{name}.png")
        for path in sorted((theme_dir / "icons").glob("*.png")):
            with Image.open(path) as original:
                alpha = original.convert("RGBA").getchannel("A")
                silhouette = alpha.crop(alpha.getbbox())
                if max(silhouette.size) != 20:
                    size = tuple(max(1, round(side * 20 / max(silhouette.size))) for side in silhouette.size)
                    silhouette = silhouette.resize(size, Image.Resampling.LANCZOS)
                # Limit dense logos' visual weight without thickening thin outlines.
                coverage = sum(silhouette.tobytes())
                if coverage > 140 * 255:
                    silhouette = silhouette.point([int(a * 140 * 255 / coverage) for a in range(256)])
                alpha = Image.new("L", (24, 24))
                alpha.paste(silhouette, ((24 - silhouette.width) // 2, (24 - silhouette.height) // 2))
                asset = Image.new("RGBA", (24, 24), "#4fb8cc")
                asset.putalpha(alpha)
            asset.save(path)
    theme_dir = theme_dir / "variants" / args.size
    if args.size != "compact":
        prefix = args.size + "-" + args.entries
    source = (theme_dir / "theme.txt").read_text()
    fonts = dict(load_font(path, with_name=True) for path in theme_dir.glob("*.pf2"))
    blocks = parse_components(source)
    sheet = Image.new("RGB", (640, len(sizes) * 300), "#202020")
    for row, (width, height) in enumerate(sizes):
        image = desktop(theme_dir, width, height, with_panel=False)
        for props in layout(blocks, width, height):
            kind = props["kind"]
            x, y = coord(props["left"], width), coord(props["top"], height)
            if kind == "image":
                with Image.open(theme_dir / props["file"]) as asset:
                    asset = asset.resize((coord(props["width"], width), coord(props["height"], height)))
                    image.paste(asset, (x, y), asset if asset.mode == "RGBA" else None)
                continue
            font = fonts[props.get("font", props.get("item_font"))]
            if kind == "label":
                if args.entries == "actual-advanced" and props.get("id") == "__timeout__":
                    continue  # Entering a submenu has already cancelled automatic boot.
                text = props["text"].replace("%d", "3")
                if props.get("align") == "center":
                    x += (coord(props["width"], width) - sum(font[2][ord(c)][4] for c in text)) // 2
                draw_text(image, (x, y + font[0]), text, font, props["color"])
                continue
            # gui_list.c applies item_padding around the list, not around each row.
            padding, spacing = int(props["item_padding"]), int(props["item_spacing"])
            x, y = x + padding, y + padding
            menu_width = coord(props["width"], width) - 2 * padding
            row_height = int(props["item_height"])
            visible = (coord(props["height"], height) + spacing - 2 * padding) // (row_height + spacing)
            slices = {edge: Image.open(theme_dir / f"midnight-select_{edge}.png") for edge in ("w", "c", "e")}
            first = max(0, args.selected - visible + 1)
            for index, (text, classes) in enumerate(entries[first:first + visible]):
                icon = next((name for name in classes if (theme_dir / "icons" / f"{name}.png").is_file()), None)
                row_y = y + index * (row_height + spacing)
                selected = index + first == args.selected
                if selected:
                    offset = 0
                    for edge in ("w", "c", "e"):
                        slice_width = menu_width - slices["w"].width - slices["e"].width if edge == "c" else slices[edge].width
                        asset = slices[edge].resize((slice_width, row_height))
                        image.paste(asset, (x + offset, row_y), asset)
                        offset += slice_width
                ascent, descent = font[:2]
                icon_x = x + slices["w"].width
                if icon:
                    with Image.open(theme_dir / "icons" / f"{icon}.png") as asset:
                        icon_width, icon_height = int(props["icon_width"]), int(props["icon_height"])
                        asset = asset.convert("RGBA").resize((icon_width, icon_height))
                        image.paste(asset, (icon_x, row_y + (row_height - icon_height) // 2), asset)
                # Clip entry titles to the list, as gfxmenu does at low resolutions.
                text_x = icon_x + int(props["icon_width"]) + int(props["item_icon_space"])
                right_pad = slices["e"].width if selected else 0
                viewport = image.crop((text_x, row_y, x + menu_width - right_pad, row_y + row_height))
                draw_text(viewport, (0, (row_height - ascent - descent) // 2 + ascent),
                          text, font, props["selected_item_color" if selected else "item_color"])
                image.paste(viewport, (text_x, row_y))
            for slice_image in slices.values():
                slice_image.close()
        if args.console:
            terminal = dict(re.findall(r'^terminal-([\w-]+): "([^"]*)"$', source, re.M))
            x, y = coord(terminal["left"], width), coord(terminal["top"], height)
            w, h = coord(terminal["width"], width), coord(terminal["height"], height)
            border = int(terminal["border"])
            ImageDraw.Draw(image).rectangle((x - border, y - border, x + w + border - 1,
                                            y + h + border - 1), fill="black")
            font = fonts[terminal["font"]]
            for index, text in enumerate(("GRUB console layout illustration", "Not a captured boot transition", "grub> _")):
                draw_text(image, (x + border, y + border + font[0] + index * (font[0] + font[1])), text, font, "white")
        suffix = "-console" if args.console else ""
        destination = args.output / f"{prefix}-{width}x{height}-selected-{args.selected}{suffix}.png"
        image.save(destination)
        if args.entries == "actual" and args.selected == 0 and not args.console:
            image.save(args.output / f"{args.size}-{width}x{height}.png")
            comparison_paths = [args.output / f"{size}-{width}x{height}.png" for size in ("normal", "large")]
            if all(path.is_file() for path in comparison_paths):
                comparison = Image.new("RGB", (width * 2, height + 24), "#202020")
                for column, path in enumerate(comparison_paths):
                    with Image.open(path) as preview:
                        comparison.paste(preview, (column * width, 24))
                    ImageDraw.Draw(comparison).text((column * width + 8, 6), path.stem + " | simulated PF2 | 1:1", fill="white")
                comparison.save(args.output / f"comparison-{width}x{height}.png")
        print(f"Simulated preview ({args.entries}, not a GRUB boot): {destination}")
        thumbnail = image.copy()
        thumbnail.thumbnail((640, 280))
        sheet.paste(thumbnail, ((640 - thumbnail.width) // 2, row * 300 + 20))
        ImageDraw.Draw(sheet).text((8, row * 300 + 3),
                                  f"{width}x{height} | {args.entries} | selected {args.selected} | simulated PF2",
                                  fill="white")
    sheet.save(args.output / f"{prefix}-contact-sheet-selected-{args.selected}{suffix}.png")


if __name__ == "__main__":
    main()
