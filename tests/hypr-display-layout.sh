#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

python3 -B - "$REPO_DIR/wayland/bin/hypr-display-layout" <<'PY'
import importlib.machinery
import importlib.util
import sys

loader = importlib.machinery.SourceFileLoader("hypr_display_layout", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

enabled = [
    {
        "action": "enable",
        "output": "DP-8",
        "mode": "preferred",
        "position": "0x0",
        "scale": 1.0,
        "mirror": "",
        "transform": 0,
    },
    {
        "action": "enable",
        "output": "DP-9",
        "mode": "preferred",
        "position": "1920x0",
        "scale": 1.0,
        "mirror": "",
        "transform": 0,
    },
]
disabled = [
    {"action": "disable", "output": "eDP-1"},
    {"action": "disable", "output": "HDMI-A-1"},
]
calls = []
waits = []


class Result:
    returncode = 0
    stdout = "ok\n"
    stderr = ""


def fake_run(arguments, **_kwargs):
    calls.append(arguments)
    return Result()


module.subprocess.run = fake_run
module.wait_for_operations = waits.append
module.apply_operations([*enabled, *disabled])

assert calls == [
    [module.HYPRCTL, "eval", "\n".join(module.lua_for_operation(operation) for operation in enabled)],
    [module.HYPRCTL, "eval", "\n".join(module.lua_for_operation(operation) for operation in disabled)],
]
assert waits == [enabled, disabled]
PY
