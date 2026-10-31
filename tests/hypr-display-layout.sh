#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

python3 -B - "$REPO_DIR/wayland/bin/hypr-display-layout" <<'PY'
import importlib.machinery
import importlib.util
import sys
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader("hypr_display_layout", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

assert module.normalized_state({}) == {
    "version": 1,
    "kind": "extend",
}
with TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_CONFIG_HOME": directory, "XDG_STATE_HOME": directory}, clear=True):
    assert module.load_profiles() == {}
    for state in ({"version": 1, "kind": "extend"}, {"version": 1, "kind": "profile", "profile": "desk-three-screen"}):
        module.write_state(state)
        assert module.read_state() == state
with patch.dict(os.environ, {"HYPR_DISPLAY_PROFILES": str(Path(sys.argv[1]).parents[2] / "hardware/ricardo/display-profiles.json")}):
    module.PROFILES = module.load_profiles()

extend_args = module.build_parser().parse_args(["extend"])
assert module.requested_state(extend_args) == ({"version": 1, "kind": "extend"}, True)

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
real_wait = module.wait_for_operations
module.wait_for_operations = waits.append
module.apply_operations([*enabled, *disabled])

assert calls == [
    [module.HYPRCTL, "eval", "\n".join(module.lua_for_operation(operation) for operation in enabled)],
    [module.HYPRCTL, "eval", "\n".join(module.lua_for_operation(operation) for operation in disabled)],
]
assert waits == [enabled, disabled]

desk_monitors = [
    {
        "name": "eDP-1",
        "description": "Lenovo Group Limited 0x41B5",
        "width": 1920,
        "height": 1200,
        "scale": 1.0,
        "transform": 0,
    },
    {
        "name": "DP-7",
        "description": "Dell Inc. DELL P2422H HDFJ5V3",
        "width": 1920,
        "height": 1080,
        "scale": 1.0,
        "transform": 0,
    },
    {
        "name": "DP-8",
        "description": "Dell Inc. DELL P2422H H3G8XB3",
        "width": 1920,
        "height": 1080,
        "scale": 1.0,
        "transform": 0,
    },
]
desk_plan = module.plan_for_state(
    {"version": 1, "kind": "profile", "profile": "desk-three-screen"}, desk_monitors
)
assert [(operation["output"], operation["position"]) for operation in desk_plan["operations"]] == [
    ("DP-7", "0x0"),
    ("eDP-1", "1920x0"),
    ("DP-8", "3840x0"),
]

extend_plan = module.plan_for_state({"version": 1, "kind": "extend"}, desk_monitors)
assert extend_plan["state"] == {"version": 1, "kind": "extend"}
assert "fallback" not in extend_plan

monitor = dict(desk_monitors[0], x=0, y=0)
operation = module.enable_operation(monitor, 0, 0)
assert module.monitor_matches_operation(monitor, operation, {})
for dimension in ("width", "height"):
    for value in (0, -1, None):
        assert not module.monitor_matches_operation(dict(monitor, **{dimension: value}), operation, {})
with patch.object(module, "PROFILES", {}):
    state = {"version": 1, "kind": "profile", "profile": "desk-three-screen"}
    plan = module.plan_for_state(state, desk_monitors)
    assert plan["state"] == state and "fallback" in plan

# A failed enable must never reach the disable phase.
calls.clear()
with patch.object(module, "wait_for_operations", side_effect=RuntimeError("not converged")):
    try:
        module.apply_operations([*enabled, *disabled])
        raise AssertionError("accepted failed convergence")
    except RuntimeError:
        pass
assert len(calls) == 1 and "disabled = true" not in calls[0][2]

with patch.object(module, "query_monitors", return_value=[dict(monitor, width=0)]), \
        patch.object(module.time, "monotonic", side_effect=[0, 0, 3]), \
        patch.object(module.time, "sleep"):
    try:
        real_wait([operation])
        raise AssertionError("zero-width preferred mode converged")
    except RuntimeError as error:
        assert "did not converge" in str(error)

dock_monitors = [dict(desk_monitors[0], description="Lenovo Group Limited 0x41B5 extra"),
                 dict(desk_monitors[1], description="Dell Inc. DELL P2419H 3B0FPD3"),
                 dict(desk_monitors[2], description="Dell Inc. DELL P2422H 8V9K8T3")]
profile = module.PROFILES["dock-three-screen"]
assert [op["position"] for op in module.profile_operations(profile, dock_monitors)] == ["0x0", "1920x0", "960x1080"]
assert module.profile_operations(profile, dock_monitors + [dict(dock_monitors[0], name="eDP-2")]) is None
with TemporaryDirectory() as directory, patch.dict(os.environ, {"HYPR_DISPLAY_PROFILES": str(Path(directory) / "missing")}):
    try:
        module.load_profiles()
        raise AssertionError("missing explicit profile file accepted")
    except RuntimeError:
        pass
PY
