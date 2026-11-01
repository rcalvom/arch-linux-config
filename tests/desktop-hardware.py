#!/usr/bin/env python3
"""Offline hardware defaults and topology regressions; never call live setters."""

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader(
    "display_layout", str(ROOT / "wayland/bin/hypr-display-layout")
)
spec = importlib.util.spec_from_loader(loader.name, loader)
layout = importlib.util.module_from_spec(spec)
loader.exec_module(layout)

# Hyprland monitor JSON fixtures, not inferred from the test host.
PANEL = {"name": "eDP-3", "description": "Example Internal Panel 123",
         "width": 2560, "height": 1600, "scale": 2, "transform": 0}
EXTERNAL = {"name": "DP-9", "description": "Example External Display 456",
            "width": 1920, "height": 1080, "scale": 1, "transform": 0}
FIXTURES = {
    "laptop": [PANEL],
    "desktop": [EXTERNAL, dict(EXTERNAL, name="HDMI-A-4", description="Second Display 789")],
    "hybrid": [EXTERNAL, PANEL],
}


class HardwareTests(unittest.TestCase):
    def setUp(self):
        self.process = patch.object(layout.subprocess, "run", side_effect=AssertionError("live command forbidden"))
        self.process.start()
        self.addCleanup(self.process.stop)

    def test_native_waybar_defaults(self):
        config = json.loads((ROOT / "wayland/waybar/config.jsonc").read_text())
        self.assertIn("battery", config["modules-right"])
        self.assertIn("backlight", config["modules-right"])
        self.assertNotIn("bat", config["battery"])
        self.assertNotIn("adapter", config["battery"])
        self.assertNotIn("device", config["backlight"])
        self.assertEqual(config["battery"]["states"], {"warning": 20, "critical": 10})
        self.assertEqual(set(config["battery"]["events"]),
                         {"on-discharging-warning", "on-discharging-critical"})
        self.assertNotIn("exec", config["battery"])

    def test_brightness_and_tablet_defaults(self):
        for filename in ("hyprland.lua", "hyprland.conf"):
            text = (ROOT / "wayland/hypr" / filename).read_text()
            commands = re.findall(r"brightnessctl[^\"\n]+", text)
            self.assertEqual(commands, ["brightnessctl --class=backlight -e4 -n2 set 5%+",
                                        "brightnessctl --class=backlight -e4 -n2 set 5%-"])
            self.assertNotIn("eDP-1", text)
            self.assertNotRegex(text, r"tablet\s*= ?\{|tablet\s*\{")
        personal = (ROOT / "hardware/ricardo/hardware.lua").read_text()
        self.assertIn('output = "eDP-1"', personal)

    def test_generic_topologies_and_renames(self):
        with patch.object(layout, "PROFILES", {}):
            for name, monitors in FIXTURES.items():
                with self.subTest(topology=name):
                    plan = layout.plan_for_state(layout.DEFAULT_STATE, monitors)
                    self.assertEqual(plan["state"]["kind"], "extend")
                    self.assertNotIn("fallback", plan)
                    self.assertEqual({op["output"] for op in plan["operations"]},
                                     {m["name"] for m in monitors})
                    self.assertTrue(all(op["action"] == "enable" for op in plan["operations"]))
                    self.assertEqual(plan["operations"][0]["position"], "0x0")
                    if name == "hybrid":
                        self.assertEqual([op["output"] for op in plan["operations"]], ["eDP-3", "DP-9"])
                        self.assertEqual(plan["operations"][1]["position"], "1280x0")
                    renamed = [dict(m, name=f"DP-{index + 20}") for index, m in enumerate(monitors)]
                    for old, new in zip(monitors, renamed):
                        identity = layout.monitor_identity(old, monitors)
                        state = {"version": 1, "kind": "single", "output": identity}
                        selected = layout.plan_for_state(state, renamed)
                        self.assertNotIn("fallback", selected)
                        self.assertEqual(selected["operations"][0]["output"], new["name"])
        for connector in ("eDP-8", "LVDS-2", "DSI-4"):
            panel = dict(PANEL, name=connector)
            self.assertIs(layout.laptop_monitor([EXTERNAL, panel]), panel)
        self.assertIsNone(layout.laptop_monitor(FIXTURES["desktop"]))

    def test_personal_opt_in_and_fallback(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}, clear=True):
            self.assertEqual(layout.load_profiles(), {})
            with patch.dict(os.environ, {"HYPR_DISPLAY_PROFILES": str(ROOT / "hardware/ricardo/display-profiles.json")}):
                profiles = layout.load_profiles()
        for name, profile in profiles.items():
            monitors = [dict(EXTERNAL, name=f"DP-{index + 30}",
                             description=identity.removeprefix("description-prefix:"))
                        for index, identity in enumerate(item for row in profile["rows"] for item in row)]
            with self.subTest(profile=name), patch.object(layout, "PROFILES", profiles):
                state = {"version": 1, "kind": "profile", "profile": name}
                self.assertNotIn("fallback", layout.plan_for_state(state, monitors))
                for unavailable in (monitors[:-1], monitors + [dict(monitors[0], name="DP-99")]):
                    plan = layout.plan_for_state(state, unavailable)
                    self.assertIn("fallback", plan)
                    self.assertEqual(plan["state"], state)
                    self.assertTrue(all(op["action"] == "enable" for op in plan["operations"]))

    def test_mapping_sources_and_opt_in_boundary(self):
        shared = (ROOT / "wayland/files.conf").read_text()
        self.assertNotIn("hardware.lua", shared)
        self.assertNotIn("display-profiles.json", shared)
        for base in (ROOT / "wayland", ROOT / "hardware/ricardo"):
            for line in (base / "files.conf").read_text().splitlines():
                if not line or line.startswith("#"):
                    continue
                kind, mode, source, destination = line.split("|")
                self.assertTrue((base / source).exists(), source)
                self.assertTrue(destination)
        self.assertIn("user_tree|0755|bin|.local/bin", shared)
        self.assertIn("user_tree|0644|waybar|.config/waybar", shared)


if __name__ == "__main__":
    unittest.main()
