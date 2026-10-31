#!/usr/bin/env python3
"""Static lock-screen invariants; does not launch Hyprlock or validate PAM."""

import os
import re
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
config = (ROOT / "wayland/hypr/hyprlock.conf").read_text()

assert re.search(r"general\s*\{\s*hide_cursor = true\s*fail_timeout = 4000\s*\}", config)
assert re.search(
    r"auth\s*\{\s*fingerprint\s*\{\s*enabled = false\s*"
    r"ready_message = Scan fingerprint to unlock\s*"
    r"present_message = Scanning fingerprint\.\.\.\s*retry_delay = 250\s*\}\s*\}",
    re.sub(r"#.*", "", config),
)
assert "grace" not in config and "pam" not in config.lower()
assert "source =" not in config
assert "screenshot" not in config and "onclick" not in config
assert "$USER" not in config and "$DESC" not in config
assert "$font = UbuntuMono Nerd Font" in config
for color in ("033e8c", "4fb8cc", "10a778", "f1f1f1"):
    assert f"rgb({color})" in config
assert "color = rgba(000000cc)" in config
assert "size = 94%, 94%" in config and "border_size = 2" in config
assert "size = 460, 48" in config and "outline_thickness = 2" in config
assert "path = $HOME/Pictures/wallpaper2.png" in config
assert "blur_passes = 0" in config
assert re.search(r"animations\s*\{\s*enabled = false\s*\}", config)
for setting in (
    "fail_text = $FAIL", "text = $FPRINTPROMPT", "text = $FPRINTFAIL",
    "check_text = Checking...", "fade_on_empty = false",
):
    assert setting in config
assert (ROOT / "wayland/wallpapers/wallpaper.png").read_bytes() == (
    ROOT / "qtile/wallpapers/wallpaper2.png"
).read_bytes()
manifest = (ROOT / "wayland/files.conf").read_text()
assert "user_file|0644|hypr/hyprlock.conf|.config/hypr/hyprlock.conf" in manifest
assert "user_file|0644|wallpapers/wallpaper.png|Pictures/wallpaper2.png" in manifest

commands = re.findall(r"text = cmd\[update:1000\] (.*)", config)
assert len(commands) == 2 and config.count("cmd[") == 2
for command, expected in zip(commands, ("01:05:09 PM", "Monday, September 14, 2026")):
    args = shlex.split(command)
    assert args[:2] == ["LC_TIME=C", "date"] and len(args) == 3
    output = subprocess.check_output(
        ["date", "--date=2026-09-14 13:05:09 UTC", args[2]],
        env={**os.environ, "LC_ALL": "", "LC_TIME": "C", "TZ": "UTC"},
        text=True,
    )
    assert output.strip() == expected

assert "$LAYOUT" not in config and "capslock" not in config.lower()
assert "Caps Lock" not in config and "Keyboard:" not in config
labels = re.findall(r"label\s*\{([^}]+)\}", config)
for text, size, y in (("<b>Session locked</b>", 36, 175), (commands[0], 48, 75), (commands[1], 22, -5)):
    label = next(label for label in labels if text in label)
    assert f"font_size = {size}" in label and f"position = 0, {y}" in label
# Panel and field fit the smallest supported logical viewport; runtime captures
# check actual font extents and separation rather than estimating glyph bounds.
for width, height in ((640, 480), (1280, 800), (1920, 1200)):
    assert width * .94 + 4 < width and height * .94 + 4 < height
    assert 460 + 4 < width * .94
print("Hyprlock static design, authentication defaults, and date checks passed.")
