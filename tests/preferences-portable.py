#!/usr/bin/env python3
"""Validate portable preferences without reading or modifying the host home."""

import configparser
import json
from pathlib import Path
import re
import subprocess
import tomllib


ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ROOT / "packages"


def load_toml(path):
    return tomllib.loads((PACKAGES / path).read_text())


terminal = load_toml("alacritty/alacritty.toml")
assert {"key": "Return", "mods": "Shift", "chars": "\x1b\r"} in terminal["keyboard"]["bindings"]
assert load_toml("cliamp/config.toml") == {"theme": "archcfg-terminal"}
assert (PACKAGES / "cliamp/themes/archcfg-terminal.toml").is_file()
btop = load_toml("btop/btop.conf")
assert btop["color_theme"] == "adwaita-dark"
assert btop["theme_background"] is False
assert set(btop) == {
    "color_theme", "theme_background", "truecolor", "rounded_corners",
    "shown_boxes", "update_ms", "proc_sorting", "proc_reversed", "proc_tree",
    "check_temp", "show_cpu_freq",
}
for version in (3, 4):
    gtk = configparser.ConfigParser()
    gtk.read(PACKAGES / f"gtk/gtk{version}-settings.ini")
    assert gtk["Settings"]["gtk-theme-name"] == "Adwaita-dark"
    assert gtk["Settings"]["gtk-application-prefer-dark-theme"] == "1"

git = configparser.ConfigParser()
git.read(PACKAGES / "git/config")
assert git.sections() == ["core", "init"]
assert dict(git["core"]) == {"editor": "nvim"}
assert dict(git["init"]) == {"defaultbranch": "main"}
assert (PACKAGES / "git/ignore").read_text() == "**/.claude/settings.local.json\n"

settings = json.loads((PACKAGES / "vscode/settings.json").read_text())
assert settings["security.workspace.trust.untrustedFiles"] == "prompt"
assert not any(key.startswith(("claudeCode.", "github.copilot.", "remote.", "mcp.")) for key in settings)
extensions = [line for line in (PACKAGES / "vscode/extensions.txt").read_text().splitlines()
              if line and not line.startswith("#")]
assert len(extensions) == len(set(extensions))
assert all(re.fullmatch(r"[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9-]*", item) for item in extensions)
assert settings["[python]"]["editor.defaultFormatter"] in extensions
assert "pkief." + settings["workbench.iconTheme"] in extensions
associations = configparser.ConfigParser()
associations.read(PACKAGES / "vscode/mimeapps.list")
assert all(value == "code.desktop;" for value in associations["Default Applications"].values())
# Optional editor associations must not overwrite the default browser/mail map.
assert "mimeapps.list" not in (PACKAGES / "vscode/files.conf").read_text()

for folder in ("gtk", "btop", "git", "cliamp", "alacritty", "vscode"):
    for line in (PACKAGES / folder / "files.conf").read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        kind, mode, source, destination = line.split("|")
        assert kind in ("user_file", "user_tree") and mode == "0644"
        assert (PACKAGES / folder / source).exists()
        assert not Path(destination).is_absolute() and ".." not in Path(destination).parts

desktop = (PACKAGES / "desktop.txt").read_text().splitlines()
live = (ROOT / "live/packages.x86_64").read_text().splitlines()
assert {"evince", "neovim"} <= set(desktop)
assert {"evince", "neovim", "terminus-font"} <= set(live)
assert "fprintd" not in desktop
lock = (ROOT / "wayland/hypr/hyprlock.conf").read_text()
assert re.search(r"fingerprint\s*\{\s*enabled\s*=\s*false", lock)
assert "placeholder_text = password or fingerprint" not in lock
for script in ("scripts/packages.sh", "postinstall.sh", "tests/package-profiles.sh"):
    subprocess.run(["bash", "-n", str(ROOT / script)], check=True)
print("Portable preference checks passed")
