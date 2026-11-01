#!/usr/bin/env python3
"""Exercise the real profile helper in a rewritten sandbox, never on host GRUB."""

import os
import re
import runpy
import shutil
import stat
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class GrubProfileTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="grub-profile-", dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ("repo/scripts", "repo/lib", "etc/default", "boot/grub", "usr/share/grub/themes/arch", "run/lock", "bin"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        shutil.copytree(REPO / "grub", self.root / "repo/grub")
        (self.root / "repo/qtile/wallpapers").mkdir(parents=True)
        shutil.copyfile(REPO / "qtile/wallpapers/wallpaper2.png", self.root / "repo/qtile/wallpapers/wallpaper2.png")
        for relative in ("repo/grub/grub", "repo/grub/classic/grub"):
            profile = self.root / relative
            profile.write_text(profile.read_text().replace("/usr/share/grub/themes", str(self.root / "usr/share/grub/themes")))
        shutil.copy2(REPO / "lib/log.sh", self.root / "repo/lib/log.sh")
        source = (REPO / "scripts/apply-grub-profile.sh").read_text()
        for prefix in ("/etc/default/grub", "/boot/grub", "/usr/share/grub/themes", "/var/lib/arch-linux-config/grub-backups", "/run/lock"):
            source = source.replace(prefix, str(self.root) + prefix)
        source = source.replace("export PATH=/usr/bin:/bin", f"export PATH={self.root}/bin:/usr/bin:/bin")
        source = source.replace("[[ $EUID -eq 0 ]]", "[[ $EUID -eq $UID ]]")
        source = source.replace('$(stat -c %u "$path") == 0', '$(stat -c %u "$path") == "$UID"')
        self.script = self.root / "repo/scripts/apply-grub-profile.sh"
        self.script.write_text(source)
        self.defaults = self.root / "etc/default/grub"
        self.defaults.write_text(
            '# Keep host-specific settings\nGRUB_DEFAULT=saved\nGRUB_TIMEOUT=3\n'
            'export GRUB_TIMEOUT=8\nGRUB_TIMEOUT_STYLE=hidden\nGRUB_TERMINAL=console\n'
            'GRUB_CMDLINE_LINUX="cryptdevice=UUID=fixture:root resume=UUID=fixture"\n'
            'GRUB_DISABLE_OS_PROBER=true\nGRUB_GFXPAYLOAD_LINUX=text\n'
            'GRUB_THEME="old-theme"\nGRUB_BACKGROUND="old-wallpaper"\n'
        )
        self.defaults.chmod(0o640)
        self.config = self.root / "boot/grub/grub.cfg"
        self.config.write_text("# Original custom boot configuration\nmenuentry 'Previous' { true; }\n")
        self.config.chmod(0o600)
        self.theme = self.root / "usr/share/grub/themes/arch"
        (self.theme / "old-asset").write_text("original")
        self.before = self.defaults.read_bytes(), self.config.read_bytes()
        self.mock("chown", "#!/bin/sh\nexit 0\n")
        self.mock("grub-mkconfig", f'''#!/usr/bin/python3
import os, re, signal, sys
from pathlib import Path
mode = os.environ.get("MOCK_MODE", "ok")
print("PRIVATE_DISK_IDENTIFIER")
if mode == "fail":
    sys.exit(1)
if mode == "interrupt":
    os.kill(os.getppid(), signal.SIGTERM)
    sys.exit(1)
text = Path({str(self.defaults)!r}).read_text()
theme = re.findall(r'^GRUB_THEME="(.*)"$', text, re.M)[-1]
timeout = re.findall(r'^GRUB_TIMEOUT=(.*)$', text, re.M)[-1]
if mode == "missing-theme":
    theme = "missing"
if mode == "wrong-timeout":
    timeout = "9"
if mode == "old-timeout":
    timeout = "1"
output = f'set theme="{{theme}}"\\nset timeout_style=menu\\nset timeout={{timeout}}\\nmenuentry "Fixture" {{{{ true; }}}}\\n'
if mode == "syntax":
    output += "if\\n"
Path(sys.argv[2]).write_text(output)
''')

    def mock(self, name, source):
        path = self.root / "bin" / name
        path.write_text(source)
        path.chmod(0o755)

    def run_helper(self, profile="graphical", mode="ok", confirmation="APPLY\n", extra=()):
        return subprocess.run(
            ["bash", str(self.script), "--profile", profile, *extra], input=confirmation,
            text=True, capture_output=True, env={**os.environ, "MOCK_MODE": mode},
        )

    def assert_unchanged(self):
        self.assertEqual(self.before, (self.defaults.read_bytes(), self.config.read_bytes()))
        self.assertEqual((self.theme / "old-asset").read_text(), "original")
        self.assertEqual(stat.S_IMODE(self.defaults.stat().st_mode), 0o640)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertFalse(list((self.root / "boot/grub").glob("grub.cfg.*")))
        self.assertFalse(list(self.theme.parent.glob(".arch-stage.*")))

    def test_apply_repeat_and_classic(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        applied = self.defaults.read_text()
        for line in self.before[0].decode().splitlines():
            if line.startswith(("#", "GRUB_DEFAULT=", "GRUB_CMDLINE", "GRUB_DISABLE_OS_PROBER", "GRUB_GFXPAYLOAD")):
                self.assertIn(line + "\n", applied)
        self.assertEqual(applied.count("GRUB_TIMEOUT="), 1)
        self.assertIn("GRUB_TIMEOUT=3\n", applied)
        self.assertIn("GRUB_DISABLE_RECOVERY=false\n", applied)
        self.assertNotIn("GRUB_TERMINAL=", applied)
        self.assertNotIn("GRUB_BACKGROUND=", applied)
        self.assertFalse((self.theme / "install.sh").exists())
        self.assertFalse((self.theme / "old-asset").exists())
        self.assertTrue((self.theme / "midnight-select_w.png").is_file())
        for asset in ("terminal-edge.png", "icons/os.png", "icons/settings.png", "UbuntuMonoNerdFont-Bold-24.pf2",
                       "UbuntuMonoNerdFont-Regular-22.pf2", "UbuntuMonoNerdFont-Regular-18.pf2",
                       "UbuntuMonoNerdFont-Footer-Regular-18.pf2",
                      "AdwaitaMono-Bold-24-arrow.pf2", "Adwaita-FONT-LICENSE.txt", "Ubuntu-FONT-LICENCE.txt",
                      "key-arrows.png", "key-enter.png", "key-escape.png", "key-e.png", "key-c.png"):
            self.assertEqual((self.theme / asset).read_bytes(), (REPO / "grub/theme/variants/compact" / asset).read_bytes())
            self.assertEqual(stat.S_IMODE((self.theme / asset).stat().st_mode), 0o644)
        self.assertEqual(stat.S_IMODE(self.theme.stat().st_mode), 0o755)
        self.assertEqual(stat.S_IMODE((self.theme / "theme.txt").stat().st_mode), 0o644)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertEqual(self.run_helper().returncode, 0)
        self.assertEqual(applied, self.defaults.read_text())
        backups = list((self.root / "var/lib/arch-linux-config/grub-backups").iterdir())
        self.assertEqual(len(backups), 2)
        for backup in backups:
            self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE((backup / "generation.log").stat().st_mode), 0o600)
            self.assertIn("PRIVATE_DISK_IDENTIFIER", (backup / "generation.log").read_text())
        self.assertNotIn("PRIVATE_DISK_IDENTIFIER", result.stdout + result.stderr)
        self.assertEqual(self.run_helper(profile="classic").returncode, 0)
        self.assertIn("GRUB_TIMEOUT=3\n", self.defaults.read_text())
        self.assertTrue((self.theme / "theme.txt").exists())

    def test_generation_failures_restore_everything(self):
        for mode in ("fail", "syntax", "missing-theme", "wrong-timeout", "old-timeout", "interrupt"):
            with self.subTest(mode=mode):
                result = self.run_helper(mode=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("PRIVATE_DISK_IDENTIFIER", result.stdout + result.stderr)
                self.assert_unchanged()

    def test_failure_removes_new_theme(self):
        shutil.rmtree(self.theme)
        self.assertNotEqual(self.run_helper(mode="fail").returncode, 0)
        self.assertFalse(self.theme.exists())
        self.assertEqual(self.before, (self.defaults.read_bytes(), self.config.read_bytes()))

    def test_cancel_and_invalid_profile(self):
        for profile, confirmation in (("graphical", "NO\n"), ("invalid", "APPLY\n")):
            self.assertNotEqual(self.run_helper(profile=profile, confirmation=confirmation).returncode, 0)
            self.assert_unchanged()
        self.assertFalse((self.root / "var").exists())

    def test_refuse_symlink(self):
        target = self.defaults.with_suffix(".original")
        self.defaults.rename(target)
        self.defaults.symlink_to(target)
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assert_unchanged()

    def test_theme_assets_and_font_names(self):
        theme = REPO / "grub/theme"
        text = (theme / "theme.txt").read_text()
        self.assertEqual(text.count("{"), text.count("}"))
        common = {"left", "top", "width", "height", "id"}
        allowed = {
            "canvas": common,
            "image": common | {"file"},
            "label": common | {"text", "font", "color", "align"},
            "boot_menu": common | {
                "item_font", "selected_item_font", "item_color", "selected_item_color",
                "icon_width", "icon_height", "item_icon_space", "item_height",
                "item_padding", "item_spacing", "selected_item_pixmap_style",
                "scrollbar", "scrollbar_left_pad",
            },
        }
        renderer = runpy.run_path(str(REPO / "grub/render-preview.py"))
        tree = renderer["parse_components"](text)
        stack = []
        components = []
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("+ "):
                match = re.fullmatch(r"\+ (label|boot_menu|image|canvas) \{", line)
                self.assertIsNotNone(match)
                self.assertTrue(not stack or stack[-1] == "canvas")
                stack.append(match[1])
                components.append({"kind": match[1]})
            elif line == "}":
                self.assertTrue(stack)
                stack.pop()
            elif stack:
                match = re.fullmatch(r'(\w+) = ("[^"]*"|false|\d+(?:%(?:[+-]\d+)?)?)', line)
                self.assertIsNotNone(match, line)
                self.assertIn(match[1], allowed[stack[-1]])
                components[-1][match[1]] = match[2].strip('"')
            else:
                self.assertRegex(line, r'^(title-text|desktop-(color|image|image-scale-method)|terminal-(font|box|border|left|top|width|height)): "[^"]*"$')
        self.assertFalse(stack)
        fonts = {}
        metrics = {}
        for size in (16, 18, 22, 24):
            style = "Bold" if size == 24 else "Regular"
            family = "UbuntuMono Nerd Font Footer" if size == 18 else "UbuntuMono Nerd Font"
            filename_style = "Footer-Regular" if size == 18 else style
            data = (theme / f"UbuntuMonoNerdFont-{filename_style}-{size}.pf2").read_bytes()
            self.assertEqual(data[:12], b"FILE\x00\x00\x00\x04PFF2")
            self.assertIn(f"{family} {style} {size}".encode(), data)
            if size == 24:
                self.assertIn(b"WEIG\x00\x00\x00\x05bold\x00", data)
                regular = renderer["load_font"](theme / "UbuntuMonoNerdFont-Regular-24.pf2")
                bold = renderer["load_font"](theme / "UbuntuMonoNerdFont-Bold-24.pf2")
                self.assertNotEqual(regular[2][ord("S")][-1], bold[2][ord("S")][-1])
                for font in (regular, bold):
                    self.assertEqual(sum(font[2][ord(c)][4] for c in "Select an operating system or an option"), 468)
            offset = 0
            while offset < len(data):
                section, length = struct.unpack_from(">4sI", data, offset)
                offset += 8
                if section in (b"ASCE", b"DESC"):
                    metrics.setdefault(size, {})[section] = int.from_bytes(data[offset:offset + length], "big")
                if section == b"CHIX":
                    fonts[size] = {code: struct.unpack_from(">HHhhh", data, location)
                                   for code, flags, location in struct.iter_unpack(">IBI", data[offset:offset + length])}
                    break
                offset += length
            self.assertIn(size, fonts)
        for edge, width in (("w", 36), ("c", 1), ("e", 1)):
            data = (theme / f"midnight-select_{edge}.png").read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", data[16:24]), (width, 36))
        self.assertIn('id = "__timeout__"', text)
        self.assertIn("icon_width = 24", text)
        titles = [c for c in components if c.get("font") == "UbuntuMono Nerd Font Bold 24"]
        self.assertEqual(len(titles), 1)
        self.assertEqual(titles[0]["text"], "Select an operating system or an option")
        self.assertEqual(titles[0]["align"], "center")
        timeout = next(c for c in components if c.get("id") == "__timeout__")
        self.assertEqual(timeout["align"], "center")
        self.assertEqual(timeout["text"], "Booting in %d s")
        self.assertEqual(timeout["font"], "UbuntuMono Nerd Font Footer Regular 18")
        self.assertEqual(timeout["left"], titles[0]["left"])
        self.assertEqual(timeout["width"], "94%-36")
        for component in components:
            for key in ("color", "item_color", "selected_item_color"):
                if key in component:
                    expected_color = ("#4fb8cc" if component == titles[0] else
                                      "#f3e430" if component.get("id") == "__timeout__" else "#ffffff")
                    self.assertEqual(component[key], expected_color)
        hints = [c for c in components if c.get("text") in ("select", "boot", "edit", "console", "back")]
        keys = [c for c in components if c.get("file", "").startswith("key-")]
        self.assertEqual([c["text"] for c in hints], ["select", "boot", "edit", "console", "back"])
        self.assertEqual(len(keys), 5)
        self.assertEqual({c["top"] for c in hints}, {"1"})
        self.assertEqual({c["top"] for c in keys}, {"0"})
        self.assertEqual({c["font"] for c in hints}, {"UbuntuMono Nerd Font Footer Regular 18"})
        for edge, dimension in zip(components[:4], ("height", "width", "width", "height")):
            self.assertEqual(edge[dimension], "2")
        for removed in ("ARCH LINUX", "boot:~$", "terminal-bar.png", "[UP/DOWN]", "[ENTER]", "[ESC]"):
            self.assertNotIn(removed, text)
        self.assertEqual(text.count("pixmap_style"), 1)
        self.assertIn('desktop-color: "#000000"', text)
        self.assertTrue(text.isascii())
        menu = next(component for component in components if component["kind"] == "boot_menu")
        self.assertNotIn("item_align", menu)  # Unsupported by GRUB 2.14.
        self.assertEqual(menu["item_font"], menu["selected_item_font"])
        self.assertEqual(menu["item_font"], "UbuntuMono Nerd Font Regular 22")
        self.assertEqual(menu["item_icon_space"], "12")
        self.assertEqual(menu["scrollbar"], "false")
        self.assertEqual(menu["scrollbar_left_pad"], "0")
        def coordinate(value, extent):
            match = re.fullmatch(r"(\d+)%([+-]\d+)?", value)
            return int(int(match[1]) * extent / 100) + int(match[2] or 0) if match else int(value)

        for width, height in renderer["PROFILES"]["compact"]["resolutions"]:
            components = list(renderer["layout"](tree, width, height))
            menu = next(c for c in components if c["kind"] == "boot_menu")
            hints = sorted((c for c in components if c.get("text") in ("select", "boot", "edit", "console", "back")), key=lambda c: int(c["left"]))
            keys = sorted((c for c in components if c.get("file", "").startswith("key-")), key=lambda c: int(c["left"]))
            panel = next(c for c in components if c.get("file") == "terminal-edge.png" and c["height"] == "2")
            self.assertEqual(coordinate(panel["width"], width), width * 94 // 100)
            self.assertLessEqual(abs(2 * coordinate(panel["left"], width) + coordinate(panel["width"], width) - width), 2)
            self.assertLessEqual(abs(2 * coordinate(menu["left"], width) + coordinate(menu["width"], width) - width), 2)
            self.assertEqual(int(menu["width"]), width * 40 // 100 + 240)
            self.assertEqual(int(menu["top"]), height * 32 // 100 + 48)
            rectangles = []
            for slot, (key, hint) in enumerate(zip(keys, hints)):
                self.assertEqual(coordinate(hint["left"], width) - coordinate(key["left"], width)
                                  - int(key["width"]), 6)
                group_left = int(key["left"])
                group_right = int(hint["left"]) + int(hint["width"])
                inner_left, inner_width = width * 3 // 100 + 16, width * 94 // 100 - 32
                self.assertLessEqual(abs((group_left + group_right) / 2
                                        - (inner_left + inner_width * (slot * 2 + 1) / 10)), 1)
                self.assertGreaterEqual(group_left, inner_left)
                self.assertLessEqual(group_right, inner_left + inner_width)
            self.assertGreater(coordinate(keys[-1]["left"], width), width * 7 // 10)
            for component in components:
                top = coordinate(component["top"], height)
                bottom = top + coordinate(component["height"], height)
                left = coordinate(component["left"], width)
                component_width = coordinate(component["width"], width)
                self.assertGreaterEqual(left, 0)
                if component["kind"] == "image":
                    self.assertTrue((theme / component["file"]).is_file())
                # Non-border components stay inside the panel, regardless of paint order.
                if component.get("file") != "terminal-edge.png":
                    self.assertGreater(left, width * 3 // 100)
                    self.assertLess(left + component_width, width * 97 // 100)
                    self.assertGreater(top, height * 3 // 100)
                    self.assertLess(bottom, height * 97 // 100)
                    if component.get("file") == "panel.png":
                        continue
                    for x, y, right, lower in rectangles:
                        self.assertTrue(left >= right or left + component_width <= x or top >= lower or bottom <= y,
                                        f"Overlapping components at {width}x{height}: {component}")
                    rectangles.append((left, top, left + component_width, bottom))
                self.assertLessEqual(bottom, height)
                self.assertLessEqual(coordinate(component["left"], width) + coordinate(component["width"], width), width)
                if component["kind"] == "label":
                    size = int(component["font"].split()[-1])
                    glyphs = fonts[size]
                    label = component["text"].replace("%d", "3")
                    self.assertTrue(all(ord(char) in glyphs for char in label))
                    self.assertLessEqual(sum(glyphs[ord(char)][4] for char in label), component_width)
                    self.assertLessEqual(sum(metrics[size].values()), coordinate(component["height"], height))
                    advance = 0
                    for char in label:
                        w, h, dx, dy, step = glyphs[ord(char)]
                        self.assertGreaterEqual(advance + dx, 0)
                        self.assertLessEqual(advance + dx + w, component_width)
                        self.assertGreaterEqual(metrics[size][b"ASCE"] - dy - h, 0)
                        self.assertLessEqual(metrics[size][b"ASCE"] - dy, coordinate(component["height"], height))
                        advance += step
            # Match gui_list.c:get_num_shown_items for side-only selection slices.
            padding, spacing = int(menu["item_padding"]), int(menu["item_spacing"])
            row_height = int(menu["item_height"])
            self.assertLessEqual(sum(metrics[22].values()), row_height)
            text_width = coordinate(menu["width"], width) - 2 * padding - 36 - 24 - 12 - 1
            for entry in ("Arch Linux", "Advanced options for Arch Linux", "Windows Boot Manager",
                           "UEFI Firmware Settings", "Arch Linux (fallback initramfs)",
                           "Linux (recovery mode)", "Other operating system", "Custom entry without classes"):
                self.assertLessEqual(sum(fonts[22][ord(char)][4] for char in entry), text_width)
            menu_height = coordinate(menu["height"], height)
            visible = (menu_height + spacing - 2 * padding) // (row_height + spacing)
            self.assertEqual(visible, 3)
            rows_top = int(menu["top"]) + padding
            rows_bottom = rows_top + visible * (row_height + spacing) - spacing
            self.assertEqual(rows_bottom - rows_top, 120)
            for selected in range(30):
                first = max(0, selected - visible + 1)
                self.assertLess(selected - first, visible)
                last_bottom = coordinate(menu["top"], height) + padding + min(visible, 8) * (row_height + spacing) - spacing
                self.assertLessEqual(last_bottom, coordinate(menu["top"], height) + menu_height)

    def test_prompt_and_class_assets(self):
        from PIL import Image

        theme = REPO / "grub/theme"
        renderer = runpy.run_path(str(REPO / "grub/render-preview.py"))
        arrow_font = renderer["load_font"](theme / "AdwaitaMono-Bold-24-arrow.pf2")
        self.assertEqual(set(arrow_font[2]), {0x279c})
        width, height, dx, dy, _, bitmap = arrow_font[2][0x279c]
        self.assertGreater(width, 0)
        self.assertGreater(height, 0)
        self.assertTrue(any(bitmap))
        expected = Image.new("RGBA", (36, 36), (0, 0, 0, 0))
        renderer["draw_text"](expected, ((24 - width) // 2 - dx, (36 - height) // 2 + height + dy),
                              "\u279c", arrow_font, "#10a778")
        for edge in ("w", "c", "e"):
            with Image.open(theme / f"midnight-select_{edge}.png") as image:
                colors = {color for count, color in image.getcolors()}
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(colors, {(0, 0, 0, 0), (16, 167, 120, 255)} if edge == "w" else {(0, 0, 0, 0)})
                if edge == "w":
                    self.assertEqual(image.tobytes(), expected.tobytes())
                    self.assertEqual(image.crop((24, 0, 36, 36)).getextrema(), ((0, 0),) * 4)
        with Image.open(theme / "terminal-edge.png") as image:
            self.assertEqual(image.size, (1, 1))
            self.assertEqual(image.getpixel((0, 0)), (3, 62, 140))
        for name, width in (("arrows", 36), ("enter", 22), ("escape", 28), ("e", 16), ("c", 16)):
            with Image.open(theme / f"key-{name}.png") as image:
                self.assertEqual(image.format, "PNG")
                self.assertEqual(image.mode, "RGB")
                self.assertEqual(image.size, (width, 16))
                self.assertEqual({color for count, color in image.getcolors()},
                                 {(0, 0, 0), (79, 184, 204)})
        for path in (theme / "icons").glob("*.png"):
            with Image.open(path) as image:
                self.assertEqual(image.format, "PNG")
                self.assertEqual(image.size, (24, 24))
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.convert("RGB").getextrema(), ((79, 79), (184, 184), (204, 204)))
                alpha = image.getchannel("A")
                x, y, right, bottom = alpha.getbbox()
                self.assertEqual(max(right - x, bottom - y), 20)
                self.assertLessEqual(sum(alpha.tobytes()), 140 * 255)
        result = subprocess.run(
            ["python3", str(self.root / "repo/grub/render-preview.py"), "--build-assets",
             "--output", str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for path in theme.rglob("*.png"):
            self.assertEqual(path.read_bytes(), (self.root / "repo/grub/theme" / path.relative_to(theme)).read_bytes())
        for entry_set, selected in (("fixture", 0), ("fixture", 7), ("fixture-long", 0), ("fixture-long", 29)):
            result = subprocess.run(
                ["python3", str(REPO / "grub/render-preview.py"), "--selected", str(selected),
                 "--entries", entry_set, "--output", str(self.root)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            for width, height in renderer["PROFILES"]["compact"]["resolutions"]:
                menu = next(c for c in renderer["layout"](
                    renderer["parse_components"]((theme / "theme.txt").read_text()), width, height)
                            if c["kind"] == "boot_menu")
                visible = (int(menu["height"]) + 6 - 8) // 42
                prefix = "grub-terminal" + (f"-{entry_set}" if entry_set != "fixture" else "")
                with Image.open(self.root / f"{prefix}-{width}x{height}-selected-{selected}.png") as image:
                    self.assertEqual(image.size, (width, height))
                    background = renderer["desktop"](theme, width, height)
                    self.assertEqual(image.getpixel((0, 0)), background.getpixel((0, 0)))
                    self.assertEqual(image.getpixel((width // 2, height * 3 // 100)), (3, 62, 140))
                    first = max(0, selected - visible + 1)
                    x = width * 30 // 100 - 116
                    y = int(menu["top"]) + 4 + (selected - first) * 42
                    arrow_background = background.crop((x, y, x + 36, y + 36))
                    arrow_background.paste(expected, (0, 0), expected)
                    self.assertEqual(image.crop((x, y, x + 36, y + 36)).tobytes(), arrow_background.tobytes())
                    self.assertEqual(image.getpixel((width // 2, y + 1)), background.getpixel((width // 2, y + 1)))
                    components = list(renderer["layout"](
                        renderer["parse_components"]((theme / "theme.txt").read_text()), width, height))
                    for component in components:
                        if component.get("align") != "center":
                            continue
                        left, top, w, h = (int(component[k]) for k in ("left", "top", "width", "height"))
                        style = "Bold" if component["font"].endswith("24") else "Regular"
                        size = int(component["font"].split()[-1])
                        if size == 18:
                            style = "Footer-Regular"
                        font = renderer["load_font"](theme / f"UbuntuMonoNerdFont-{style}-{size}.pf2")
                        label = component["text"].replace("%d", "3")
                        advance = sum(font[2][ord(c)][4] for c in label)
                        expected_label = background.crop((left, top, left + w, top + h))
                        renderer["draw_text"](expected_label, ((w - advance) // 2, font[0]),
                                              label, font, component["color"])
                        self.assertEqual(image.crop((left, top, left + w, top + h)).tobytes(),
                                         expected_label.tobytes())
                    keys = sorted((c for c in components if c.get("file", "").startswith("key-")), key=lambda c: int(c["left"]))
                    hints = sorted((c for c in components if c.get("text") in ("select", "boot", "edit", "console", "back")), key=lambda c: int(c["left"]))
                    for slot, (key, hint) in enumerate(zip(keys, hints)):
                        left, top = int(key["left"]), int(key["top"])
                        right = int(hint["left"]) + int(hint["width"])
                        center = width * 3 // 100 + 16 + (width * 94 // 100 - 32) * (slot * 2 + 1) // 10
                        self.assertLessEqual(abs((left + right) / 2 - center), 1)

    def test_actual_entry_previews(self):
        from PIL import Image

        renderer = runpy.run_path(str(REPO / "grub/render-preview.py"))
        entries = renderer["ENTRIES"]
        self.assertEqual(len(entries["fixture"]), 8)
        self.assertEqual(len(entries["fixture-long"]), 30)
        self.assertEqual([title for title, classes in entries["actual"]],
                         ["Arch Linux", "Advanced options for Arch Linux", "UEFI Firmware Settings"])
        self.assertEqual([classes for title, classes in entries["actual"]][1:], [(), ()])
        self.assertEqual(len(entries["actual-advanced"]), 2)
        theme = REPO / "grub/theme"
        font = renderer["load_font"](theme / "UbuntuMonoNerdFont-Regular-22.pf2")
        source = (theme / "theme.txt").read_text()
        for entry_set in ("actual", "actual-advanced"):
            for selected in range(len(entries[entry_set])):
                result = subprocess.run(
                    ["python3", str(REPO / "grub/render-preview.py"), "--entries", entry_set,
                     "--selected", str(selected), "--output", str(self.root)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                for width, height in renderer["PROFILES"]["compact"]["resolutions"]:
                    menu = next(c for c in renderer["layout"](renderer["parse_components"](source), width, height)
                                if c["kind"] == "boot_menu")
                    x, y = int(menu["left"]) + 4, int(menu["top"]) + 4
                    with Image.open(self.root / f"grub-terminal-{entry_set}-{width}x{height}-selected-{selected}.png") as image:
                        self.assertEqual(image.size, (width, height))
                        background = renderer["desktop"](theme, width, height)
                        if entry_set == "actual-advanced":
                            box = (width * 3 // 100 + 18, height * 32 // 100 + 192,
                                   width * 97 // 100 - 18, height * 32 // 100 + 214)
                            self.assertEqual(image.crop(box).tobytes(), background.crop(box).tobytes())
                        for index, (title, classes) in enumerate(entries[entry_set]):
                            text_width = int(menu["width"]) - 8 - 72 - (index == selected)
                            row_y = y + index * 42
                            box = (x + 72, row_y, x + 72 + text_width, row_y + 36)
                            expected = background.crop(box)
                            renderer["draw_text"](expected, (0, (36 - font[0] - font[1]) // 2 + font[0]),
                                                  title, font, "#ffffff")
                            self.assertEqual(image.crop((x + 72, row_y, x + 72 + text_width, row_y + 36)).tobytes(),
                                             expected.tobytes())
                            if not classes:
                                box = (x + 36, row_y, x + 60, row_y + 36)
                                expected = background.crop(box)
                                self.assertEqual(image.crop(box).tobytes(), expected.tobytes())
                        last_bottom = y + len(entries[entry_set]) * 42 - 6
                        box = (x, last_bottom, x + int(menu["width"]) - 8, int(menu["top"]) + int(menu["height"]))
                        self.assertEqual(image.crop(box).tobytes(), background.crop(box).tobytes())
                        longest = max(sum(font[2][ord(c)][4] for c in title) for title, _ in entries[entry_set])
                        if width <= 800 and entry_set == "actual-advanced":
                            self.assertGreater(longest, text_width)
                        else:
                            self.assertLessEqual(longest, text_width)
        result = subprocess.run(
            ["python3", str(REPO / "grub/render-preview.py"), "--entries", "actual",
             "--selected", "7", "--output", str(self.root)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)

    def test_size_selection_and_rollback(self):
        for size in ("large", "normal", "compact"):
            result = self.run_helper(extra=("--size", size))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            source = REPO / "grub/theme/variants" / size
            self.assertEqual({p.relative_to(self.theme): p.read_bytes() for p in self.theme.rglob("*") if p.is_file()},
                             {p.relative_to(source): p.read_bytes() for p in source.rglob("*") if p.is_file()})
            self.assertIn(str(self.theme / "theme.txt"), self.config.read_text())
            self.assertIn("set timeout=3\n", self.config.read_text())
            previous = {p.relative_to(self.theme): p.read_bytes() for p in self.theme.rglob("*") if p.is_file()}
            defaults, config = self.defaults.read_bytes(), self.config.read_bytes()
            for mode in ("fail", "syntax", "missing-theme", "wrong-timeout", "old-timeout", "interrupt"):
                result = self.run_helper(extra=("--size", "normal" if size != "normal" else "large"), mode=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((defaults, config), (self.defaults.read_bytes(), self.config.read_bytes()))
                self.assertEqual(previous, {p.relative_to(self.theme): p.read_bytes() for p in self.theme.rglob("*") if p.is_file()})
        self.assertEqual(self.run_helper(profile="classic").returncode, 0)
        self.assertEqual(previous, {p.relative_to(self.theme): p.read_bytes() for p in self.theme.rglob("*") if p.is_file()})

    def test_invalid_size_has_no_writes(self):
        before = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        for profile, extra in (("graphical", ("--size",)), ("graphical", ("--size", "tiny")),
                               ("graphical", ("--size", "../large")), ("classic", ("--size", "compact")),
                               ("classic", ("--size", "large")), ("graphical", ("--unknown",))):
            result = self.run_helper(profile=profile, extra=extra)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(before, {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
            self.assertFalse((self.root / "var").exists())
        self.assertEqual(self.run_helper(extra=("--help",)).returncode, 0)

    def test_variant_regeneration(self):
        self.check_variant_regeneration(build_fonts=False)

    def test_font_regeneration(self):
        for executable in ("fc-match", "grub-mkfont"):
            if shutil.which(executable) is None:
                self.skipTest(f"Font rebuild requires {executable}")
        for family, style in (("UbuntuMono Nerd Font", "Regular"),
                              ("UbuntuMono Nerd Font", "Bold"),
                              ("Adwaita Mono", "Bold")):
            actual = subprocess.check_output(
                ["fc-match", "-f", "%{family}|%{style}", f"{family}:style={style}"], text=True)
            if actual != f"{family}|{style}":
                self.skipTest(f"Font rebuild requires {family} {style}; fallback is not acceptable")
        self.check_variant_regeneration(build_fonts=True)

    def check_variant_regeneration(self, *, build_fonts):
        generator = runpy.run_path(str(REPO / "grub/generate-theme.py"))
        output = self.root / "generated"
        output.mkdir()
        generator["generate"](output, build_assets=True, build_fonts=build_fonts)
        source = REPO / "grub/theme/variants"
        expected = {p.relative_to(source): p.read_bytes() for p in source.rglob("*") if p.is_file()}
        for _ in range(2):
            actual = {p.relative_to(output / "variants"): p.read_bytes()
                      for p in (output / "variants").rglob("*") if p.is_file()}
            self.assertEqual(expected, actual)
            self.assertEqual((output / "theme.txt").read_bytes(), (REPO / "grub/theme/theme.txt").read_bytes())
            self.assertEqual((output / "theme.txt").read_bytes(), (output / "variants/compact/theme.txt").read_bytes())
            generator["generate"](output, build_assets=True)

    def test_wallpaper_and_console_bounds(self):
        from PIL import Image, ImageOps

        renderer = runpy.run_path(str(REPO / "grub/render-preview.py"))
        with Image.open(REPO / "qtile/wallpapers/wallpaper2.png") as wallpaper:
            expected = wallpaper.convert("RGB")
        # Independent ordering fixture: reverse siblings, not the flattened tree.
        fixture = [
            {"kind": "image", "file": "front", "left": "0", "top": "0", "width": "10", "height": "10", "children": []},
            {"kind": "canvas", "left": "5", "top": "7", "width": "10", "height": "10", "children": [
                {"kind": "image", "file": name, "left": "1", "top": "2", "width": "3", "height": "4", "children": []}
                for name in ("child-front", "child-back")]},
            {"kind": "image", "file": "back", "left": "0", "top": "0", "width": "10", "height": "10", "children": []},
        ]
        painted = list(renderer["layout"](fixture, 100, 100))
        self.assertEqual([c["file"] for c in painted], ["back", "child-back", "child-front", "front"])
        self.assertEqual((painted[1]["left"], painted[1]["top"]), ("6", "9"))
        for size, profile in renderer["PROFILES"].items():
            theme = REPO / "grub/theme/variants" / size
            source = (theme / "theme.txt").read_text()
            tree = renderer["parse_components"](source)
            self.assertEqual(tree[-1].get("file"), "panel.png")
            self.assertEqual(list(renderer["layout"](tree, 1920, 1200))[0].get("file"), "panel.png")
            self.assertIn('desktop-image-scale-method: "crop"', source)
            with Image.open(theme / "background.png") as background:
                self.assertEqual(background.size, expected.size)
                self.assertEqual(background.tobytes(), expected.tobytes())
            with Image.open(theme / "panel.png") as panel:
                self.assertEqual(panel.mode, "RGBA")
                self.assertEqual(panel.getpixel((0, 0)), (0, 0, 0, 204))
            terminal = dict(re.findall(r'^terminal-([\w-]+): "([^"]*)"$', source, re.M))
            fonts = dict(renderer["load_font"](p, with_name=True) for p in theme.glob("*.pf2"))
            font = fonts[terminal["font"]]
            border = int(terminal["border"])
            for edge in ("c", "n", "ne", "e", "se", "s", "sw", "w", "nw"):
                with Image.open(theme / f"console_{edge}.png") as asset:
                    self.assertEqual(asset.mode, "RGB")
                    self.assertEqual(asset.size, (8, 8))
                    self.assertEqual(asset.getextrema(), ((0, 0),) * 3)
            for width, height in profile["resolutions"]:
                wallpaper = ImageOps.fit(expected, (width, height), method=Image.Resampling.LANCZOS)
                composited = renderer["desktop"](theme, width, height)
                left, top = width * 3 // 100 + 2, height * 3 // 100 + 2
                right, bottom = left + width * 94 // 100 - 4, top + height * 94 // 100 - 4
                reference = wallpaper.copy()
                region = wallpaper.crop((left, top, right, bottom))
                region = Image.blend(region, Image.new("RGB", region.size, "black"), 0.8)
                reference.paste(region, (left, top))
                # Pillow's integer alpha blend rounds, while Image.blend truncates.
                from PIL import ImageChops
                self.assertLessEqual(max(hi for lo, hi in ImageChops.difference(reference, composited).getextrema()), 1)
                for box in ((0, 0, width, top), (0, bottom, width, height),
                            (0, top, left, bottom), (right, top, width, bottom)):
                    self.assertEqual(composited.crop(box).tobytes(), wallpaper.crop(box).tobytes())
                x, y = renderer["coord"](terminal["left"], width), renderer["coord"](terminal["top"], height)
                w, h = renderer["coord"](terminal["width"], width), renderer["coord"](terminal["height"], height)
                # view.c:terminal_sanity_check must not enlarge/recenter this rectangle.
                self.assertGreaterEqual(w, 80 * font[2][ord("M")][4] + 2 * border)
                self.assertGreaterEqual(h, 24 * max(g[1] for g in font[2].values()) + 2 * border)
                self.assertGreater(x - 8, width * 3 // 100 + 2)
                self.assertGreater(y - 8, height * 3 // 100 + 2)
                self.assertLess(x + w + 8, width * 97 // 100 - 2)
                footer_top = height * 97 // 100 - round(40 * profile["footer"] / 18)
                self.assertLess(y + h + 8, footer_top)
            result = subprocess.run(["python3", str(REPO / "grub/render-preview.py"), "--size", size,
                                     "--console", "--output", str(self.root)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

            # Reintroduce the reported bug in the sandbox. The preview must show
            # foreground dimming, not silently move the panel behind the text.
            candidate = self.root / "repo/grub/theme/variants" / size / "theme.txt"
            command = ["python3", str(self.root / "repo/grub/render-preview.py"), "--size", size,
                       "--resolution", "1920x1200", "--entries", "actual", "--output", str(self.root)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            preview = self.root / f"{size}-1920x1200.png"
            with Image.open(preview) as image:
                colors = image.getcolors(image.width * image.height)
                self.assertGreater(sum(n for n, color in colors if color == (255, 255, 255)), 100)
            start = source.rindex("+ image {")
            candidate.write_text(source[:start].replace("+ label {", source[start:] + "+ label {", 1))
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            with Image.open(preview) as image:
                interior = image.crop((60, 38, 1860, 1162))
                colors = {color for n, color in interior.getcolors(interior.width * interior.height)}
                for foreground in ((255, 255, 255), (79, 184, 204), (243, 228, 48), (16, 167, 120)):
                    self.assertNotIn(foreground, colors)
            candidate.write_text(source)

    def test_variant_metrics_and_previews(self):
        from PIL import Image

        renderer = runpy.run_path(str(REPO / "grub/render-preview.py"))
        common = {"kind", "left", "top", "width", "height", "id"}
        allowed = {"image": common | {"file"}, "label": common | {"text", "font", "color", "align"},
                   "boot_menu": common | {"item_font", "selected_item_font", "item_color", "selected_item_color",
                                           "icon_width", "icon_height", "item_icon_space", "item_height",
                                           "item_padding", "item_spacing", "scrollbar", "scrollbar_left_pad",
                                           "selected_item_pixmap_style"}}
        for size, profile in renderer["PROFILES"].items():
            theme = REPO / "grub/theme/variants" / size
            fonts = dict(renderer["load_font"](path, with_name=True) for path in theme.glob("*.pf2"))
            self.assertIn("UbuntuMono Nerd Font Regular 18", fonts)
            self.assertIn(b"WEIG\x00\x00\x00\x05bold\x00",
                          (theme / f"UbuntuMonoNerdFont-Bold-{profile['title']}.pf2").read_bytes())
            for path in (theme / "icons").glob("*.png"):
                with Image.open(path) as icon:
                    self.assertEqual(icon.size, (profile["icon"], profile["icon"]))
                    self.assertEqual(icon.convert("RGB").getextrema(), ((79, 79), (184, 184), (204, 204)))
            source = (theme / "theme.txt").read_text()
            self.assertTrue(source.isascii())
            self.assertNotIn("item_align", source)
            tree = renderer["parse_components"](source)
            resolutions = profile["resolutions"] + ([[1920, 1200]] if size == "normal" else [])
            for width, height in resolutions:
                with self.subTest(size=size, resolution=(width, height)):
                    components = list(renderer["layout"](tree, width, height))
                    rectangles = []
                    for c in components:
                        self.assertLessEqual(set(c), allowed[c["kind"]])
                        x, y, w, h = (int(c[k]) for k in ("left", "top", "width", "height"))
                        if c.get("file") == "terminal-edge.png":
                            self.assertEqual(min(w, h), 2)
                            continue
                        self.assertGreater(x, width * 3 // 100)
                        self.assertLess(x + w, width * 97 // 100)
                        self.assertGreater(y, height * 3 // 100)
                        self.assertLess(y + h, height * 97 // 100)
                        if c.get("file") == "panel.png":
                            continue
                        for left, top, right, bottom in rectangles:
                            self.assertTrue(x >= right or x + w <= left or y >= bottom or y + h <= top, c)
                        rectangles.append((x, y, x + w, y + h))
                        if c["kind"] == "label":
                            font = fonts[c["font"]]
                            label = c["text"].replace("%d", "3")
                            advance = sum(font[2][ord(char)][4] for char in label)
                            self.assertLessEqual(advance, w)
                            self.assertLessEqual(font[0] + font[1], h)
                            cursor = (w - advance) // 2 if c.get("align") == "center" else 0
                            for char in label:
                                gw, gh, dx, dy, step, bitmap = font[2][ord(char)]
                                self.assertGreaterEqual(cursor + dx, 0)
                                self.assertLessEqual(cursor + dx + gw, w)
                                self.assertGreaterEqual(font[0] - dy - gh, 0)
                                self.assertLessEqual(font[0] - dy, h)
                                cursor += step
                    menu = next(c for c in components if c["kind"] == "boot_menu")
                    title = next(c for c in components if c.get("text", "").startswith("Select an"))
                    counter = next(c for c in components if c.get("id") == "__timeout__")
                    self.assertEqual(int(title["top"]), height * 32 // 100)
                    self.assertEqual(int(menu["top"]) - int(title["top"]), profile["menu_offset"])
                    self.assertEqual(int(counter["top"]) - int(menu["top"]) - int(menu["height"]), profile["counter_gap"])
                    self.assertEqual(title["color"], "#4fb8cc")
                    self.assertEqual(counter["color"], "#f3e430")
                    self.assertEqual(menu["item_font"], menu["selected_item_font"])
                    font = fonts[menu["item_font"]]
                    padding, spacing, row = (int(menu[k]) for k in ("item_padding", "item_spacing", "item_height"))
                    visible = (int(menu["height"]) + spacing - 2 * padding) // (row + spacing)
                    self.assertEqual(visible, profile["rows"])
                    self.assertLessEqual(font[0] + font[1], row)
                    with Image.open(theme / "midnight-select_w.png") as arrow:
                        arrow_width = arrow.width
                        expected_arrow = arrow.copy()
                    arrow_font = fonts[f"Adwaita Mono Bold {profile['icon']}"]
                    gw, gh, dx, dy, _, _ = arrow_font[2][0x279c]
                    expected = Image.new("RGBA", (arrow_width, row), (0, 0, 0, 0))
                    renderer["draw_text"](expected, ((profile["icon"] - gw) // 2 - dx,
                                                    (row - gh) // 2 + gh + dy), "\u279c", arrow_font, "#10a778")
                    self.assertEqual(expected_arrow.tobytes(), expected.tobytes())
                    for edge in ("c", "e"):
                        with Image.open(theme / f"midnight-select_{edge}.png") as asset:
                            self.assertEqual(asset.mode, "RGBA")
                            self.assertEqual(asset.getchannel("A").getextrema(), (0, 0))
                    available = int(menu["width"]) - 2 * padding - arrow_width - profile["icon"] - int(menu["item_icon_space"]) - 1
                    for label, _ in renderer["ENTRIES"]["actual"]:
                        self.assertLessEqual(sum(font[2][ord(c)][4] for c in label), available)
                    for entry_set, selected in (("actual", 0), ("actual", 2), ("fixture-long", 0), ("fixture-long", 29)):
                        result = subprocess.run(["python3", str(REPO / "grub/render-preview.py"), "--size", size,
                                                 "--resolution", f"{width}x{height}", "--entries", entry_set,
                                                 "--selected", str(selected), "--output", str(self.root)],
                                                capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        prefix = f"grub-terminal-{entry_set}" if size == "compact" else f"{size}-{entry_set}"
                        with Image.open(self.root / f"{prefix}-{width}x{height}-selected-{selected}.png") as image:
                            background = renderer["desktop"](theme, width, height)
                            first = max(0, selected - visible + 1)
                            x = int(menu["left"]) + padding
                            y = int(menu["top"]) + padding + (selected - first) * (row + spacing)
                            arrow_background = background.crop((x, y, x + arrow_width, y + row))
                            arrow_background.paste(expected_arrow, (0, 0), expected_arrow)
                            self.assertEqual(image.crop((x, y, x + arrow_width, y + row)).tobytes(), arrow_background.tobytes())
                            for c in components:
                                if c["kind"] != "label":
                                    continue
                                left, top, w, h = (int(c[k]) for k in ("left", "top", "width", "height"))
                                label = c["text"].replace("%d", "3")
                                label_font = fonts[c["font"]]
                                advance = sum(label_font[2][ord(char)][4] for char in label)
                                expected = background.crop((left, top, left + w, top + h))
                                renderer["draw_text"](expected, ((w - advance) // 2 if c.get("align") == "center" else 0,
                                                                label_font[0]), label, label_font, c["color"])
                                self.assertEqual(image.crop((left, top, left + w, top + h)).tobytes(), expected.tobytes())
                            entries = renderer["ENTRIES"][entry_set][first:first + visible]
                            for index, (label, classes) in enumerate(entries):
                                row_y = int(menu["top"]) + padding + index * (row + spacing)
                                text_x = x + arrow_width + profile["icon"] + int(menu["item_icon_space"])
                                expected = background.crop((text_x, row_y, text_x + available, row_y + row))
                                renderer["draw_text"](expected, (0, (row - font[0] - font[1]) // 2 + font[0]), label, font, "#ffffff")
                                self.assertEqual(image.crop((text_x, row_y, text_x + available, row_y + row)).tobytes(), expected.tobytes())
                                # Every row keeps its background except the arrow, icon and text.
                                box = (x, row_y, x + int(menu["width"]) - 2 * padding, row_y + row)
                                expected_row = background.crop(box)
                                is_selected = index + first == selected
                                if is_selected:
                                    expected_row.paste(expected_arrow, (0, 0), expected_arrow)
                                icon = next((name for name in classes if (theme / "icons" / f"{name}.png").is_file()), None)
                                if icon:
                                    with Image.open(theme / "icons" / f"{icon}.png") as asset:
                                        expected_row.paste(asset, (arrow_width, (row - profile["icon"]) // 2), asset)
                                text_offset = text_x - x
                                viewport = expected_row.crop((text_offset, 0, expected_row.width - int(is_selected), row))
                                renderer["draw_text"](viewport, (0, (row - font[0] - font[1]) // 2 + font[0]), label, font, "#ffffff")
                                expected_row.paste(viewport, (text_offset, 0))
                                self.assertEqual(image.crop(box).tobytes(), expected_row.tobytes())
                            if entry_set == "actual":
                                bottom = int(menu["top"]) + padding + len(entries) * (row + spacing) - spacing
                                box = (x, bottom, x + int(menu["width"]) - 2 * padding, int(menu["top"]) + int(menu["height"]))
                                self.assertEqual(image.crop(box).tobytes(), background.crop(box).tobytes())
        with Image.open(self.root / "comparison-1920x1200.png") as comparison:
            self.assertEqual(comparison.size, (3840, 1224))
            for column, size in enumerate(("normal", "large")):
                with Image.open(self.root / f"{size}-1920x1200.png") as original:
                    self.assertEqual(comparison.crop((column * 1920, 24, (column + 1) * 1920, 1224)).tobytes(),
                                     original.tobytes())


if __name__ == "__main__":
    unittest.main()
