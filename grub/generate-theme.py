#!/usr/bin/env python3
"""Generate all size variants. Asset/font rebuilds require explicit flags, never root."""

import argparse
import json
import runpy
import shutil
import subprocess
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parent
PROFILES = json.loads((ROOT / "sizes.json").read_text())


def generate(output, build_assets=False, build_fonts=False):
    # Rendering and asset generation share the PF2 decoder, not host TTF guesses.
    renderer = runpy.run_path(str(ROOT / "render-preview.py"))
    from PIL import Image

    if build_assets:
        with Image.open(ROOT.parent / "qtile/wallpapers/wallpaper2.png") as wallpaper:
            background = wallpaper.convert("RGB")
        background.save(output / "background.png")
        # Snapshot of local Alacritty window.opacity = 0.8; no host config dependency.
        Image.new("RGBA", (1, 1), (0, 0, 0, 204)).save(output / "panel.png")
        for edge in ("c", "n", "ne", "e", "se", "s", "sw", "w", "nw"):
            Image.new("RGB", (8, 8), "black").save(output / f"console_{edge}.png")

    for name, profile in PROFILES.items():
        p = dict(profile)
        p["terminal"] = 12 if name == "compact" else 18
        destination = output / "variants" / name
        destination.mkdir(parents=True, exist_ok=True)
        source = ROOT / "theme"
        font_specs = (("UbuntuMono Nerd Font", "Bold", p["title"], ""),
                      ("UbuntuMono Nerd Font", "Regular", p["menu"], ""),
                      ("UbuntuMono Nerd Font", "Regular", p["footer"], "Footer-"),
                      ("Adwaita Mono", "Bold", p["icon"], "arrow"))
        for family, style, size, suffix in font_specs:
            filename = (f"AdwaitaMono-Bold-{size}-arrow.pf2" if suffix == "arrow" else
                        f"UbuntuMonoNerdFont-{suffix}{style}-{size}.pf2")
            target = destination / filename
            if build_fonts:
                font_path = subprocess.check_output(
                    ["fc-match", "-f", "%{file}", f"{family}:style={style}"], text=True)
                command = ["grub-mkfont", "-s", str(size), "-r",
                           "0x279c-0x279c" if suffix == "arrow" else "0x20-0x7e",
                           "-o", str(target)]
                if suffix == "Footer-":
                    command += ["-n", "UbuntuMono Nerd Font Footer"]
                subprocess.run(command + [font_path], check=True)
            elif build_assets:
                bundled = source / "variants" / name / filename
                if not bundled.exists():
                    bundled = source / filename
                if bundled.resolve() != target.resolve():
                    shutil.copyfile(bundled, target)
            if build_assets:
                expected_name = f"{family}{' Footer' if suffix == 'Footer-' else ''} {style} {size}"
                actual_name, _ = renderer["load_font"](target, with_name=True)
                if actual_name != expected_name:
                    raise ValueError(f"Unexpected font fallback: {actual_name!r}; expected {expected_name!r}")
        if build_assets:
            background.save(destination / "background.png")
            shutil.copyfile(output / "panel.png", destination / "panel.png")
            for path in output.glob("console_*.png"):
                shutil.copyfile(path, destination / path.name)
            for filename in ("UbuntuMonoNerdFont-Regular-12.pf2", "UbuntuMonoNerdFont-Regular-18.pf2", "Ubuntu-FONT-LICENCE.txt",
                             "Adwaita-FONT-LICENSE.txt", "terminal-edge.png"):
                shutil.copyfile(source / filename, destination / filename)
            (destination / "icons").mkdir(exist_ok=True)
            for path in sorted((source / "icons").glob("*.png")):
                with Image.open(path) as image:
                    # Preserve cyan RGB even in transparent pixels; scale only coverage.
                    alpha = image.getchannel("A").resize((p["icon"], p["icon"]), Image.Resampling.LANCZOS)
                    asset = Image.new("RGBA", alpha.size, "#4fb8cc")
                    asset.putalpha(alpha)
                    asset.save(destination / "icons" / path.name)
            arrow = renderer["load_font"](destination / f"AdwaitaMono-Bold-{p['icon']}-arrow.pf2")
            w, h, dx, dy, _, _ = arrow[2][0x279c]
            for edge, width in (("w", p["icon"] + p["icon"] // 2), ("c", 1), ("e", 1)):
                asset = Image.new("RGBA", (width, p["row"]), (0, 0, 0, 0))
                if edge == "w":
                    renderer["draw_text"](asset, ((p["icon"] - w) // 2 - dx,
                                                 (p["row"] - h) // 2 + h + dy),
                                          "\u279c", arrow, "#10a778")
                asset.save(destination / f"midnight-select_{edge}.png")
        p["title_height"] = p["title"] + 10
        p["footer_height"] = p["footer"] + 4
        p["canvas_height"] = p["footer"] + 3
        p["footer_offset"] = round(40 * p["footer"] / 18)
        p["icon_gap"] = p["icon"] // 2
        p["menu_height"] = p["rows"] * p["row"] + (p["rows"] - 1) * p["spacing"] + 2 * p["padding"]
        p["counter_offset"] = p["menu_offset"] + p["menu_height"] + p["counter_gap"]
        p["hints"] = ""
        for percent, key, label, base_width in ((10, "arrows", "select", 36), (30, "enter", "boot", 22),
                                                (50, "e", "edit", 16), (70, "c", "console", 16),
                                                (90, "escape", "back", 28)):
            key_width = round(base_width * p["footer"] / 18)
            key_height = round(16 * p["footer"] / 18)
            gap = round(6 * p["footer"] / 18)
            label_width = len(label) * (p["footer"] // 2)
            half = (key_width + gap + label_width) // 2
            if build_assets:
                with Image.open(source / f"key-{key}.png") as image:
                    image.resize((key_width, key_height), Image.Resampling.NEAREST).save(destination / f"key-{key}.png")
            p["hints"] += (f'+ image {{\n  left = {percent}%{-half:+d}\n  top = 0\n'
                           f'  width = {key_width}\n  height = {key_height}\n  file = "key-{key}.png"\n}}\n'
                           f'+ label {{\n  left = {percent}%{key_width + gap - half:+d}\n  top = 1\n'
                           f'  width = {label_width}\n  height = {p["footer"] + 2}\n  text = "{label}"\n'
                           f'  font = "UbuntuMono Nerd Font Footer Regular {p["footer"]}"\n  color = "#ffffff"\n}}\n')
        text = Template((ROOT / "theme.template").read_text()).substitute(p)
        (destination / "theme.txt").write_text(text)
        if name == "compact":
            (output / "theme.txt").write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "theme", help="Existing output directory")
    parser.add_argument("--build-assets", action="store_true", help="Rebuild deployable PNGs and copy bundled fonts/licenses")
    parser.add_argument("--build-fonts", action="store_true", help="Rebuild PF2s with grub-mkfont and Fontconfig (requires --build-assets)")
    args = parser.parse_args()
    if not args.output.is_dir():
        parser.error("The output directory must already exist")
    if args.build_fonts and not args.build_assets:
        parser.error("--build-fonts requires --build-assets")
    generate(args.output, args.build_assets, args.build_fonts)
