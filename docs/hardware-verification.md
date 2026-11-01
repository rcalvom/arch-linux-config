# Post-Boot Hardware Verification

Run on the booted installed system as the desktop user, without sudo:

```bash
bash scripts/verify-hardware.sh --profile developer
bash scripts/verify-hardware.sh --profile developer --json
```

Profiles: `minimal`, `desktop`, `developer` (default), `virtualbox`. Select the
installed profile, not the hardware vendor. This is not a chroot/preflight tool
and accepts no alternate root. It does not source installer or deployment code.
Use `verify-system-config.sh` separately for managed-file and enablement policy
comparisons; this verifier reports post-boot observations, not file mappings.

## Safety And Privacy

Requires Bash and Python 3 standard library. Optional `systemctl`,
`systemd-detect-virt`, and `ip` queries have five-second individual timeouts.
No installation, sudo, writes, module loading, restart, deployment, journal reads,
DNS requests, Internet requests, Wi-Fi scans, audio connections, playback,
GL/Vulkan context creation, renderer probes, or NVIDIA wakeup probes occur.
The script only reads procfs/sysfs, checks socket/device metadata, and executes
the above status commands. It does not create report files itself.

Reports omit hostname, username, PCI addresses, CPU model/serials, custom kernel
suffixes, interface names, MAC/IP addresses, routes' endpoints, SSIDs, DNS
configuration, process identifiers, command lines, unit descriptions and logs.
Failed system/user unit **names** are included as requested; custom instance names
can themselves contain private identifiers. Review these before sharing a report.
Raw command output and errors are never forwarded.

## Meaning Of Results

- `pass`: the stated observation or expectation is satisfied, not a whole-system certification.
- `fail`: a concrete profile expectation is unmet, or systemd reports failed units.
- `unknown`: evidence unavailable, inaccessible, transitional or insufficient. Missing optional tools and unavailable user managers are not failures.
- `skipped`: deliberately untested or not required, including Internet connectivity, absent Wi-Fi/Bluetooth, and inactive socket-activated services/oneshots.

Exit codes: `0` means no failures or unknowns; `1` means at least one failure;
`2` means CLI/dependency error; `3` means unknowns without failures. Skips do not
affect the exit code. JSON schema version 1 contains `profile`, `checks` (stable
check keys, status and English detail), `summary`, and `exit_code`. GPU indexes
are report-local, not stable device identities.

UEFI sysfs and the running kernel's module directory are checked. Their absence
in a detected virtualized environment is unknown rather than a hardware failure.
The module directory check does not validate every module or prove ABI matching.
CPU vendor and exposed microcode revision availability are reported without
claiming microcode freshness. No kernel regression or root cause is inferred.

PCI display devices are enumerated independently, including hybrid GPUs. Driver
binding and render-node access are separate from acceleration.
Unknown driver names, unbound GPUs and inaccessible render nodes are `unknown`,
not failed hardware or evidence of acceleration. Nonzero
`drm-engine-render`, `gfx`, or `3d` nanosecond counters in readable current-user
process fdinfo constitute **observed historical graphics-engine work**. This does
not prove the current compositor renderer, every GPU, video decode, or performance.
Absence of counters (including NVIDIA stacks without these counters) is unknown,
never proof of software rendering. No process/device identifiers are emitted.

Network checks count operational links and IPv4/IPv6 default routes. Offline
operation is unknown connectivity, not failure. No endpoint is contacted.
Audio checks inspect PipeWire/Pulse socket metadata and user-unit states without
connecting, so they do not trigger socket activation or prove audible output.

Service expectations follow the current repository policy in `scripts/services.sh`
and `scripts/verify-system-config.sh`: core network/time services, scheduled TRIM,
resolver path and charge timer should be enabled and active. Network-online and
charge-limit oneshots need enablement, not continuous activity. Desktop profiles
expect greetd, PipeWire sockets and WirePlumber; developer/virtualbox also expect
Docker, and virtualbox expects vboxservice. IWD/Bluetooth runtime expectations are
conditional on observed hardware. PipeWire services may remain inactive behind
active sockets. Enabled and active PipeWire/Pulse services are also accepted in
place of their sockets, matching the managed configuration verifier. Minimal
profiles skip desktop/audio expectations. User enablement is effective enablement for the invoking user,
not an audit of global user configuration. Enabled and active are reported
separately; failed units are checked in both managers even in minimal profiles.

## Baseline And Tests

For a physical-host baseline, run the human command above in the normal logged-in
session, then the JSON command if a machine-readable report is needed. Neither
requires sudo or changes the session. Record the exit code even when it is 1 or 3;
do not treat an incomplete report as a successful acceleration test. A baseline
is a point-in-time observation, not evidence of a regression against another kernel.

The initial physical-host run with `--profile developer --json` reported 41 pass,
5 fail, 1 unknown and 7 skipped checks (exit 1). Sanitized observations:

- x86_64, EFI sysfs present, no virtualization detected; kernel 7.2.4 with its module directory present and 191 loaded modules.
- AMD CPU with an exposed microcode revision; AMD GPU bound to amdgpu, one accessible render node, and passive graphics-engine work observed.
- PipeWire and Pulse socket files present; one operational network link and an IPv4 default route. No IPv6 default route observed (unknown); Internet testing skipped.
- `fstrim.timer` and `archcfg-charge-limit.timer` did not satisfy enabled/active expectations (four failed checks). The user manager reported failed units (one failed check); names are omitted from this shareable baseline.

No remediation was performed. These observations do not establish why a timer
was inactive, whether audio is audible, or which renderer the current session uses.

```bash
bash -n scripts/verify-hardware.sh tests/verify-hardware.sh
shellcheck scripts/verify-hardware.sh tests/verify-hardware.sh
bash tests/verify-hardware.sh
```

Tests mock filesystem observations and command responses, cover Intel/AMD/NVIDIA,
hybrid GPUs, VM/no Wi-Fi, missing tools and sessions, passive acceleration,
socket activation, oneshots, enabled versus running, failed-unit privacy,
module-directory mismatch, CLI validation and JSON/exit semantics. Tests never
query the host's hardware/services; CLI tests only exercise help/error paths.
