#!/usr/bin/env python3
"""Desktop regressions with no live IPC or deployed configuration access."""

import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / "wayland/bin" / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class DesktopTests(unittest.TestCase):
    def test_window_log(self):
        watcher = load("hypr-workspace-watch")
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True):
            watcher.WINDOW_LOG = Path(directory) / "events.log"
            watcher.log_window_event("openwindow", "private title")
            self.assertFalse(watcher.WINDOW_LOG.exists())
            os.environ["HYPR_WINDOW_EVENT_LOG"] = "1"
            watcher.WINDOW_LOG_LIMIT = 5000
            for _ in range(20):
                watcher.log_window_event("openwindow", "x" * 10000 + "\nsecret")
            self.assertEqual(len(list(Path(directory).iterdir())), 2)
            for path in Path(directory).iterdir():
                self.assertLessEqual(path.stat().st_size, 5000)
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_sunset_sessions(self):
        sunset = load("hyprsunset-set")
        with patch.object(sunset.sys, "argv", ["hyprsunset-set", "identity"]), \
                patch.object(sunset.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "\n]\n")) as run:
            self.assertEqual(sunset.main(), 0)
            self.assertEqual(run.call_count, 1)
        instances = [{"instance": "one", "wl_socket": "wayland-1"},
                     {"instance": "two", "wl_socket": "wayland-2"}]
        for count, env, expected in ((0, {}, 0), (1, {}, 0), (2, {}, 1),
                                     (2, {"WAYLAND_DISPLAY": "wayland-2"}, 0),
                                     (2, {"HYPRLAND_INSTANCE_SIGNATURE": "one"}, 0),
                                     (2, {"HYPRLAND_INSTANCE_SIGNATURE": "one", "WAYLAND_DISPLAY": "wayland-2"}, 0)):
            with self.subTest(count=count, env=env), patch.dict(os.environ, env, clear=True), \
                    patch.object(sunset.sys, "argv", ["hyprsunset-set", "identity"]), \
                    patch.object(sunset.Path, "is_socket", return_value=True), \
                    patch.object(sunset.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, json.dumps(instances[:count]))) as run, \
                    patch.object(sunset.sys, "stderr", io.StringIO()):
                self.assertEqual(sunset.main(), expected)
                selected = count == 1 or (count == 2 and len(env) == 1)
                self.assertEqual(any(call.args[0][0] == "systemctl" for call in run.call_args_list), selected)
                if selected:
                    self.assertEqual(run.call_args_list[-1].args[0], ["hyprctl", "hyprsunset", "identity"])
                    self.assertEqual(os.environ["HYPRLAND_INSTANCE_SIGNATURE"], "two" if "WAYLAND_DISPLAY" in env else "one")

    def test_sunset_timeout_and_failure(self):
        sunset = load("hyprsunset-set")
        for failure in (False, True):
            def run(args, **kwargs):
                self.assertIn("timeout", kwargs)
                if failure and "start" in args:
                    raise subprocess.CalledProcessError(1, args)
                return subprocess.CompletedProcess(args, 0, '[{"instance":"one","wl_socket":"wayland-1"}]')

            with patch.dict(os.environ, {}, clear=True), \
                    patch.object(sunset.sys, "argv", ["hyprsunset-set", "temperature", "3500"]), \
                    patch.object(sunset.Path, "is_socket", side_effect=lambda: True) as socket, \
                    patch.object(sunset.subprocess, "run", side_effect=run) as process, \
                    patch.object(sunset.time, "monotonic", side_effect=[0, 6]), \
                    patch.object(sunset.sys, "stderr", io.StringIO()):
                socket.side_effect = [True, True, False]
                self.assertEqual(sunset.main(), 1)
                self.assertFalse(any(call.args[0][:2] == ["hyprctl", "hyprsunset"] for call in process.call_args_list))


if __name__ == "__main__":
    unittest.main()
