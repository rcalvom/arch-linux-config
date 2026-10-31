#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 - "$SCRIPT_DIR/../scripts/verify-hardware.sh" <<'PY'
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

script = Path(sys.argv.pop())
source = script.read_text().split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
module = {"__name__": "verifier_test"}
exec(compile(source, str(script), "exec"), module)


class VerificationTests(unittest.TestCase):
    def report(self, vendors=("0x8086",), drivers=("i915",), virtual=False,
               missing=False, wifi=False, observed=False, failed=False,
               inactive=False, disabled=False, no_module_tree=False,
                profile="desktop", sockets=True, unit_missing=False, accessible=True,
                service_audio=False):
        devices = [Path(f"/sys/bus/pci/devices/{i}") for i in range(len(vendors))]
        files = {"/proc/cpuinfo": "vendor_id: GenuineIntel\nvendor_id: AuthenticAMD",
                 "/proc/modules": "i915 123 1 - Live 0", "/sys/class/net/eth0/type": "1",
                 "/sys/class/net/eth0/operstate": "up"}
        for device, vendor in zip(devices, vendors):
            files[str(device / "class")] = "0x030000"
            files[str(device / "vendor")] = vendor

        def entries(path, pattern="*"):
            return {"/sys/bus/pci/devices": devices,
                    "/sys/class/net": [Path("/sys/class/net/eth0")],
                    "/dev/dri": [Path("/dev/dri/renderD128")],
                    "/proc": [Path("/proc/123")] if observed else [],
                    "/proc/123/fdinfo": [Path("/proc/123/fdinfo/4")]}.get(str(path), [])

        def read(path):
            if str(path) == "/proc/123/fdinfo/4":
                return "drm-engine-render: 100 ns\nprivate process name withheld"
            return files.get(str(path))

        def is_dir(path):
            if str(path).endswith("/wireless"):
                return wifi
            if str(path) == "/sys/firmware/efi":
                return not virtual
            if str(path) == "/usr/lib/modules/6.18.1-private-host":
                return not no_module_tree
            return True

        def resolve(path, strict=False):
            driver = drivers[int(path.parent.name)]
            if driver is None:
                raise FileNotFoundError
            return Path("/drivers") / driver

        calls = []

        def command(*args):
            calls.append(args)
            if missing:
                return None, ""
            if args[0] == "systemd-detect-virt":
                return (0 if virtual else 1), ""
            if args[0] == "ip":
                return 0, '[{"gateway":"PRIVATE_ENDPOINT"}]'
            if args[0] != "systemctl":
                self.fail("Unexpected command")
            if "list-units" in args:
                return 0, json.dumps([{"unit": "example.service", "description": "PRIVATE_MESSAGE"}] if failed else [])
            self.assertIn("show", args)
            if unit_missing:
                return 0, "LoadState=not-found\nActiveState=inactive\nUnitFileState=\n"
            name = args[args.index("show") + 1]
            state = "inactive" if inactive or name in ("pipewire.service", "pipewire-pulse.service", "host-network-online.service", "archcfg-charge-limit.service") else "active"
            enabled = "disabled" if disabled or name in ("pipewire.service", "pipewire-pulse.service") else "enabled"
            if service_audio and name in ("pipewire.service", "pipewire-pulse.service"):
                state, enabled = "active", "enabled"
            if service_audio and name in ("pipewire.socket", "pipewire-pulse.socket"):
                state, enabled = "inactive", "disabled"
            return 0, f"LoadState=loaded\nActiveState={state}\nSubState=dead\nUnitFileState={enabled}\n"

        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.dict(module, read=read, entries=entries, command=command))
            stack.enter_context(patch.object(Path, "is_dir", is_dir))
            stack.enter_context(patch.object(Path, "resolve", resolve))
            stack.enter_context(patch.object(Path, "is_socket", return_value=sockets))
            stack.enter_context(patch.object(Path, "stat", return_value=SimpleNamespace(st_uid=1000)))
            stack.enter_context(patch("os.getuid", return_value=1000))
            stack.enter_context(patch("os.access", return_value=accessible))
            stack.enter_context(patch("os.uname", return_value=SimpleNamespace(machine="x86_64", release="6.18.1-private-host")))
            stack.enter_context(patch.dict("os.environ", XDG_RUNTIME_DIR="/run/user/1000"))
            checks = module["verify"](profile)
        text = json.dumps(checks)
        for secret in ("PRIVATE_ENDPOINT", "PRIVATE_MESSAGE", "private-host", "/proc/123", "eth0"):
            self.assertNotIn(secret, text)
        self.assertTrue(all(c[0] in ("systemctl", "ip", "systemd-detect-virt") for c in calls))
        return {c["check"]: c for c in checks}

    def test_intel_amd_nvidia_and_hybrid(self):
        for vendors, drivers in ((("0x8086",), ("i915",)), (("0x1002",), ("amdgpu",)), (("0x10de",), ("nvidia",)), (("0x8086", "0x10de"), ("xe", "nvidia"))):
            with self.subTest(drivers=drivers):
                result = self.report(vendors=vendors, drivers=drivers)
                self.assertEqual(result["gpu.1.driver"]["status"], "pass")
                self.assertEqual(result["gpu.acceleration"]["status"], "unknown")
                self.assertFalse(any(c["status"] == "fail" for c in result.values()))

    def test_observed_acceleration(self):
        self.assertEqual(self.report(observed=True)["gpu.acceleration"]["status"], "pass")

    def test_vm_no_wifi_or_module_tree(self):
        result = self.report(vendors=("0x15ad",), drivers=("vmwgfx",), virtual=True, no_module_tree=True, profile="virtualbox")
        self.assertEqual(result["network.wifi"]["status"], "skipped")
        self.assertEqual(result["boot.uefi"]["status"], "unknown")
        self.assertFalse(any(c["status"] == "fail" for c in result.values()))

    def test_missing_tools_and_session(self):
        result = self.report(missing=True, sockets=False)
        self.assertEqual(result["services.user.failed"]["status"], "unknown")
        self.assertEqual(result["audio.socket.pipewire"]["status"], "unknown")
        self.assertFalse(any(c["status"] == "fail" for c in result.values()))

    def test_socket_activation_and_oneshots(self):
        result = self.report()
        self.assertEqual(result["services.user.pipewire.socket.running"]["status"], "pass")
        self.assertEqual(result["services.user.pipewire.service.running"]["status"], "skipped")
        self.assertEqual(result["services.system.host-network-online.service.running"]["status"], "skipped")

    def test_service_audio_alternative(self):
        result = self.report(service_audio=True)
        self.assertEqual(result["audio.activation.pipewire"]["status"], "pass")
        self.assertEqual(result["services.user.pipewire.socket.running"]["status"], "skipped")
        self.assertFalse(any(c["status"] == "fail" for c in result.values()))

    def test_enablement_is_not_running(self):
        key = "services.system.systemd-networkd.service."
        result = self.report(inactive=True)
        self.assertEqual(result[key + "enabled"]["status"], "pass")
        self.assertEqual(result[key + "running"]["status"], "fail")
        result = self.report(disabled=True)
        self.assertEqual(result[key + "enabled"]["status"], "fail")
        self.assertEqual(result[key + "running"]["status"], "pass")

    def test_failed_units_names_only(self):
        result = self.report(failed=True)
        for scope in ("system", "user"):
            self.assertEqual(result[f"services.{scope}.failed"]["detail"], "Failed units: example.service")

    def test_unbound_gpu_not_assumed_broken(self):
        self.assertEqual(self.report(drivers=(None,))["gpu.1.driver"]["status"], "unknown")

    def test_unknown_driver_and_restricted_render_nodes(self):
        result = self.report(vendors=("0xffff",), drivers=("private-driver",), accessible=False)
        self.assertEqual(result["gpu.1.driver"]["status"], "unknown")
        self.assertEqual(result["gpu.render_nodes"]["status"], "unknown")
        self.assertNotIn("private-driver", json.dumps(result))
        self.assertFalse(any(c["status"] == "fail" for c in result.values()))

    def test_wifi_and_headless_minimal(self):
        result = self.report(wifi=True, vendors=(), drivers=(), profile="minimal")
        self.assertEqual(result["services.system.iwd.service.running"]["status"], "pass")
        self.assertEqual(result["gpu.inventory"]["status"], "unknown")
        self.assertEqual(result["audio.session"]["status"], "skipped")

    def test_missing_expected_unit(self):
        result = self.report(unit_missing=True)
        for field in ("enabled", "running"):
            self.assertEqual(result["services.system.systemd-networkd.service." + field]["status"], "fail")

    def test_physical_module_mismatch(self):
        self.assertEqual(self.report(no_module_tree=True)["kernel.module_tree"]["status"], "fail")

    def test_exit_codes_and_json(self):
        for statuses, code in ((["pass", "skipped"], 0), (["unknown"], 3), (["fail", "unknown"], 1)):
            with patch.dict(module, verify=lambda _: [dict(check="test", status=s, detail="test") for s in statuses]), patch.object(sys, "argv", ["verify", "--json"]), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(module["main"](), code)
                self.assertEqual(json.loads(output.getvalue())["exit_code"], code)

    def test_command_timeout_and_missing(self):
        for error in (FileNotFoundError(), subprocess.TimeoutExpired("systemctl", 5)):
            with patch("subprocess.run", side_effect=error):
                self.assertEqual(module["command"]("systemctl", "show"), (None, ""))

    def test_cli(self):
        for args, code in ((["--help"], 0), (["--root", "/mnt"], 2), (["--profile", "invalid"], 2), (["--profile"], 2)):
            result = subprocess.run(["bash", str(script), *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, code)


unittest.main()
PY
