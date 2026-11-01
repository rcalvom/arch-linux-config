#!/usr/bin/env bash
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf '[ERROR] python3 is required\n' >&2
  exit 2
fi
exec python3 - "$@" <<'PY'
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def read(path):
    try:
        return Path(path).read_text(errors="replace").strip()
    except OSError:
        return None


def entries(path, pattern="*"):
    try:
        return sorted(Path(path).glob(pattern))
    except OSError:
        return []


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=5,
                                env={**os.environ, "LC_ALL": "C", "SYSTEMD_COLORS": "0"})
        return result.returncode, result.stdout
    except (OSError, subprocess.TimeoutExpired):
        return None, ""


def verify(profile):
    checks = []

    def add(name, status, detail):
        checks.append(dict(check=name, status=status, detail=detail))

    arch = os.uname().machine
    add("boot.architecture", "pass" if arch == "x86_64" else "fail",
        "x86_64" if arch == "x86_64" else "Not x86_64")
    rc, _ = command("systemd-detect-virt", "--quiet")
    virtual = rc == 0
    add("boot.environment", "pass" if rc in (0, 1) else "unknown",
        "Virtualized" if virtual else "No virtualization detected" if rc == 1 else "Detection unavailable")
    firmware = Path("/sys/firmware")
    add("boot.uefi", "pass" if (firmware / "efi").is_dir() else "unknown" if virtual or not firmware.is_dir() else "fail",
        "EFI sysfs present" if (firmware / "efi").is_dir() else "EFI sysfs absent; UEFI boot not established")
    release = os.uname().release
    # Do not expose custom kernel release strings, which may include host identifiers.
    version = re.match(r"\d+\.\d+(?:\.\d+)?", release)
    add("kernel.running", "pass", "Version " + (version.group() if version else "withheld"))
    modules = Path("/usr/lib/modules")
    present = (modules / release).is_dir()
    add("kernel.module_tree", "pass" if present else "unknown" if virtual or not modules.is_dir() else "fail",
        "Running kernel module directory present" if present else "Running kernel module directory absent; no cause inferred")
    loaded = read("/proc/modules")
    add("kernel.loaded_modules", "pass" if loaded is not None else "unknown",
        f"{len(loaded.splitlines())} loaded modules" if loaded is not None else "Module inventory unavailable")
    cpu = read("/proc/cpuinfo")
    vendors = [label for key, label in (("GenuineIntel", "Intel"), ("AuthenticAMD", "AMD")) if cpu and key in cpu]
    add("cpu.vendor", "pass" if vendors else "unknown", ", ".join(vendors) if vendors else "Vendor unavailable or unrecognized")
    microcode = entries("/sys/devices/system/cpu", "cpu[0-9]*/microcode/version")
    add("cpu.microcode", "pass" if any(read(p) for p in microcode) else "unknown",
        "Revision exposed by kernel; freshness not assessed" if any(read(p) for p in microcode) else "Revision not exposed; not evidence of missing microcode")

    gpus = []
    for device in entries("/sys/bus/pci/devices"):
        cls = read(device / "class")
        if not cls or not cls.startswith("0x03"):
            continue
        vendor = {"0x8086": "Intel", "0x1002": "AMD", "0x10de": "NVIDIA", "0x15ad": "VMware", "0x80ee": "VirtualBox", "0x1af4": "Virtio"}.get(read(device / "vendor"), "Other")
        try:
            driver = (device / "driver").resolve(strict=True).name
        except OSError:
            driver = None
        known = driver if driver in {"i915", "xe", "amdgpu", "radeon", "nvidia", "nouveau", "vmwgfx", "vboxvideo", "virtio-pci", "vfio-pci"} else "other" if driver else "none"
        gpus.append((vendor, driver))
        add(f"gpu.{len(gpus)}.driver", "pass" if known not in {"none", "other", "vfio-pci"} else "unknown",
            f"Vendor={vendor}; bound driver={known}; binding is not acceleration evidence")
    if not gpus:
        add("gpu.inventory", "unknown", "No PCI display device observed; headless and restricted environments are supported")
    render_nodes = entries("/dev/dri", "renderD*")
    accessible = sum(os.access(p, os.R_OK | os.W_OK) for p in render_nodes)
    add("gpu.render_nodes", "pass" if accessible else "unknown",
        f"{len(render_nodes)} render nodes; {accessible} accessible to current user; no device opened")

    # Passive evidence only: no GL/Vulkan contexts, client connections or GPU wakeup probes.
    observed = False
    for process in entries("/proc", "[0-9]*"):
        try:
            if process.stat().st_uid != os.getuid():
                continue
        except OSError:
            continue
        for fd in entries(process / "fdinfo"):
            info = read(fd)
            if info and re.search(r"^drm-engine-(?:render|gfx|3d):\s*[1-9][0-9]*\s+ns\s*$", info, re.M):
                observed = True
                break
        if observed:
            break
    add("gpu.acceleration", "pass" if observed else "unknown",
        "Observed nonzero DRM graphics-engine time in a current-user client; historical work, not proof of current session renderer or every GPU" if observed else "No passive graphics-engine evidence available; driver binding does not establish acceleration")

    links = entries("/sys/class/net")
    nonloop = [p for p in links if read(p / "type") != "772"]
    up = sum(read(p / "operstate") == "up" for p in nonloop)
    wifi = any((p / "wireless").is_dir() for p in nonloop)
    add("network.links", "pass" if up else "unknown", f"{len(nonloop)} non-loopback interfaces; {up} operationally up; connectivity not tested")
    add("network.wifi", "pass" if wifi else "skipped", "Wireless interface present" if wifi else "No wireless interface observed; Wi-Fi not required")
    for family in ("-4", "-6"):
        rc, output = command("ip", "-j", family, "route", "show", "default")
        try:
            routes = json.loads(output) if rc == 0 else None
            count = len(routes) if isinstance(routes, list) else None
        except (ValueError, TypeError):
            count = None
        add("network.default_routes." + family[1:], "pass" if count else "unknown",
            f"{count} default routes; endpoints withheld; reachability not tested" if count is not None else "Route query unavailable")
    add("network.internet", "skipped", "No Internet requests, DNS queries, Wi-Fi scans or connection attempts")

    def unit(name, scope="system", running=True, enabled=True):
        prefix = ("systemctl", "--user") if scope == "user" else ("systemctl",)
        rc, output = command(*prefix, "show", name, "--property=LoadState,ActiveState,SubState,UnitFileState", "--no-pager")
        values = dict(line.split("=", 1) for line in output.splitlines() if "=" in line) if rc == 0 else {}
        load = values.get("LoadState")
        active = values.get("ActiveState")
        enablement = values.get("UnitFileState")
        for field, value, expected in (("enabled", enablement, enabled), ("running", active, running)):
            if not expected:
                status = "fail" if active == "failed" else "skipped"
            elif rc != 0 or not load:
                status = "unknown"
            elif load == "not-found":
                status = "fail"
            elif not value:
                status = "unknown"
            elif field == "enabled":
                status = "pass" if value in ("enabled", "enabled-runtime") else "fail"
            else:
                status = "pass" if value == "active" else "unknown" if value in ("activating", "deactivating", "reloading") else "fail"
            safe = value if value in {"enabled", "enabled-runtime", "disabled", "static", "indirect", "alias", "masked", "masked-runtime", "active", "inactive", "failed", "activating", "deactivating", "reloading"} else "unavailable"
            add(f"services.{scope}.{name}.{field}", status,
                f"Observed={safe}; expected={'yes' if expected else 'not required'}")
        return values

    for name in ("systemd-networkd.service", "systemd-resolved.service", "systemd-timesyncd.service", "fstrim.timer", "archcfg-reset-resolved-if-stub.path", "archcfg-charge-limit.timer"):
        unit(name)
    for name in ("host-network-online.service", "archcfg-charge-limit.service"):
        unit(name, running=False)
    if wifi:
        unit("iwd.service")
    else:
        add("services.system.iwd.service", "skipped", "No wireless interface observed")
    if profile != "minimal":
        unit("greetd.service")
        if entries("/sys/class/bluetooth", "hci*"):
            unit("bluetooth.service")
        else:
            add("services.system.bluetooth.service", "skipped", "No Bluetooth controller observed")
        for name in ("pipewire", "pipewire-pulse"):
            values = unit(name + ".service", scope="user", running=False, enabled=False)
            service_activation = (values.get("LoadState") == "loaded"
                                  and values.get("UnitFileState") in ("enabled", "enabled-runtime")
                                  and values.get("ActiveState") == "active")
            unit(name + ".socket", scope="user", running=not service_activation,
                 enabled=not service_activation)
            if service_activation:
                add("audio.activation." + name, "pass", "Service enabled and active; socket activation not required")
        unit("wireplumber.service", scope="user")
        runtime = os.environ.get("XDG_RUNTIME_DIR")
        for name, relative in (("pipewire", "pipewire-0"), ("pulse", "pulse/native")):
            try:
                present = bool(runtime) and (Path(runtime) / relative).is_socket()
            except OSError:
                present = False
            add("audio.socket." + name, "pass" if present else "unknown", "Socket present; no connection or playback attempted" if present else "Socket not observed in current runtime; audio functionality untested")
    else:
        add("audio.session", "skipped", "Minimal profile does not require desktop audio")
    if profile in ("developer", "virtualbox"):
        unit("docker.service")
    if profile == "virtualbox":
        unit("vboxservice.service")
    for scope in ("system", "user"):
        prefix = ("systemctl", "--user") if scope == "user" else ("systemctl",)
        rc, output = command(*prefix, "list-units", "--failed", "--all", "--plain", "--no-legend", "--no-pager", "--output=json")
        try:
            data = json.loads(output) if rc == 0 else None
            names = [item["unit"] for item in data] if isinstance(data, list) else None
            if names is not None and not all(isinstance(n, str) and re.fullmatch(r"[A-Za-z0-9_.@:\\-]+", n) for n in names):
                names = None
        except (ValueError, KeyError, TypeError):
            names = None
        add("services." + scope + ".failed", "unknown" if names is None else "fail" if names else "pass",
            "Failed-unit inventory unavailable" if names is None else "Failed units: " + ", ".join(names) if names else "No failed units")
    return checks


def main():
    parser = argparse.ArgumentParser(description="Read-only post-boot verification; run as the logged-in user, without sudo.")
    parser.add_argument("--profile", choices=("minimal", "desktop", "developer", "virtualbox"), default="developer")
    parser.add_argument("--json", action="store_true", help="Emit a structured report")
    args = parser.parse_args()
    checks = verify(args.profile)
    summary = {status: sum(c["status"] == status for c in checks) for status in ("pass", "fail", "unknown", "skipped")}
    code = 1 if summary["fail"] else 3 if summary["unknown"] else 0
    if args.json:
        print(json.dumps(dict(schema_version=1, profile=args.profile, checks=checks, summary=summary, exit_code=code), indent=2))
    else:
        for check in checks:
            print(f'[{check["status"].upper()}] {check["check"]}: {check["detail"]}')
        print("Summary: " + ", ".join(f"{key}={value}" for key, value in summary.items()))
    return code


if __name__ == "__main__":
    sys.exit(main())
PY
