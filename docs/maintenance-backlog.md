# Maintenance Backlog

This document records host-specific maintenance findings that need a dedicated
review or maintenance window. It is not an instruction to apply every change
blindly. Revalidate each item against current packages, hardware, and logs
before implementation.

Audit date: 2026-08-03.

## Verified Baseline

The system was healthy when this backlog was created:

- No failed system or user units.
- No kernel panic, OOM event, hung task, lockup, NVMe error, filesystem error,
  or AMDGPU reset was found in the current or previous boot.
- The previous boot shut down cleanly.
- Startup completed in 24.5 seconds, including 7.4 seconds of userspace.
- Every persistent journal file passed `journalctl --verify`.
- Persistent journals occupied approximately 891 MiB.
- Greetd, Hyprland, IWD, networkd, resolved, Docker, PipeWire, OpenCode, and
  OpenClaw were active and healthy.

## Priority 1

### Install AMD Microcode

Status: pending.

The AMD Ryzen 7 PRO 7840U host does not have `amd-ucode` installed. The
existing mkinitcpio configuration already includes the `microcode` hook, so
the missing package is the remaining integration gap. The installed BIOS is
Lenovo version 1.35 dated 2024-02-20.

Proposed work:

- New installations now select microcode by target CPU vendor, not in the shared
  base list. This does not repair the existing host.
- Install it during a maintenance window and rebuild the initramfs if the
  package hook does not do so automatically.
- Check Lenovo's supported firmware channel for a newer BIOS.
- Reboot and verify that the kernel reports an early AMD microcode update.

This work requires root privileges and must be run manually by the operator.

### Replace Critical-Battery Suspend

Status: pending design and resume testing.

`power/upower/90-archcfg-critical-battery.conf` deliberately requests Suspend
at 3% battery and enables UPower's risky-action override. UPower warns once per
boot that a suspended system can exhaust the remaining battery and lose data.

The host has approximately 14 GiB of RAM, a 32 GiB swap partition, and kernel
hibernate support. Resume from swap is not configured in the GRUB kernel
command line and has not been validated.

Preferred work:

- Configure and test resume from the swap partition.
- Test hibernation with no external displays, with the dock, and after a full
  suspend/resume cycle.
- Change `CriticalPowerAction` to `Hibernate` only after reliable resume is
  demonstrated.
- Use `PowerOff` instead if hibernation cannot be made reliable.
- Update `docs/charge-limits.md` and the deployed UPower drop-in together.

### Enable Periodic NVMe Trim

Status: pending.

The ext4 root filesystem is mounted without continuous discard. The NVMe
device supports discard, but `fstrim.timer` is disabled and has no recorded
trigger.

Proposed work:

- Enable the packaged weekly `fstrim.timer`.
- Confirm a successful first run and inspect the amount trimmed.
- Keep continuous `discard` disabled unless a separate benchmark justifies it.

This work requires root privileges and must be run manually by the operator.

## Priority 2

### Order Cisco VPN After Network Readiness

Status: pending controlled VPN maintenance.

`vpnagentd.service` has no dependency or ordering on `network-online.target`.
It starts before `host-network-online.service` completes and emits transient
address, transport, and DNS errors. Cisco Secure Client produced most of the
warning-or-higher records in both audited boots, although the tunnel remained
connected and the service did not restart.

Proposed work:

- Add a systemd drop-in with `Wants=network-online.target` and
  `After=network-online.target`.
- Replace the legacy `/var/run/vpnagentd.pid` reference with
  `/run/vpnagentd.pid`, or remove `PIDFile` if vendor behavior confirms it is
  unnecessary for the `Type=simple` unit.
- Check for a newer organization-supported Cisco client.
- Compare warning counts before and after the ordering change.

Cisco also assumes NetworkManager APIs while this system intentionally uses
IWD, networkd, and resolved. Ordering will remove the startup race but will not
eliminate that vendor assumption.

### Validate Cisco And Tailscale DNS Coexistence

Status: pending network test.

Cisco temporarily replaces `/etc/resolv.conf`, while Tailscale configures
split DNS through systemd-resolved. The repository's resolver watcher restores
resolved successfully after normal Cisco disconnects, but programs that read
`/etc/resolv.conf` directly may bypass Tailscale split DNS while Cisco is
connected.

Test matrix:

- Public DNS with neither tunnel active.
- Corporate DNS with Cisco only.
- Tailnet DNS with Tailscale only.
- Corporate, tailnet, and public DNS with both active.
- Recovery after disconnecting Cisco normally.
- Recovery after stopping or losing the Cisco tunnel unexpectedly.

Do not remove the NetworkManager rollback packages until this matrix and the
existing Wi-Fi soak test pass.

### Add An OpenCode Resource Envelope

Status: pending measurement.

`opencode-server.service` used approximately 2.4 GiB when inspected, reached a
7.3 GiB peak, and had 82 tasks. The host showed no current memory pressure or
OOM event, but a large OpenCode workload can compete with Android Studio,
DaVinci Resolve, browsers, and virtual machines on a 14 GiB system.

Proposed work:

- Measure representative large sessions before choosing limits.
- Add a soft `MemoryHigh` limit before introducing a hard `MemoryMax` limit.
- Set a conservative `TasksMax` that remains above observed workloads.
- Verify that an enforced limit restarts or fails the service predictably
  without corrupting session state.
- Consider `NoNewPrivileges=yes` if OpenCode must never invoke setuid helpers;
  validate tool workflows before enabling it.

### Improve OpenClaw OOM Recovery

Status: pending.

The tracked and deployed gateway units use `OOMPolicy=continue`. If a child is
OOM-killed, the remaining gateway can continue in a partially functional
state even though `Restart=always` is configured.

Proposed work:

- Change `OOMPolicy=continue` to `OOMPolicy=stop` in the portable unit.
- Apply the same setting to the deployed user unit.
- Verify that a controlled service failure triggers a complete restart and
  preserves gateway health.
- Review `NoNewPrivileges=yes` separately against Docker-backed sandbox and
  plugin workflows.

### Configure The Wireless Regulatory Domain

Status: pending location decision and Wi-Fi test.

The global regulatory domain is `00`, all choices in
`/etc/conf.d/wireless-regdom` are commented, and the regulatory helper exits
with status 1 during every boot. The Qualcomm radio currently reports a
self-managed US domain, but that does not configure the global domain.

Proposed work:

- Select the legal two-letter code for the country where the laptop is used.
- Configure that value instead of copying the radio's current value blindly.
- Reboot and verify `iw reg get` plus 2.4, 5, and 6 GHz connectivity as
  applicable.
- Confirm that the udev helper warning disappears.

Two isolated `ath11k` receive-descriptor warnings were observed. Monitor them
after kernel, firmware, microcode, and regulatory-domain maintenance; no Wi-Fi
outage was correlated with them.

## Priority 3

### Identify Portal Inhibit Noise

Status: monitor.

`xdg-desktop-portal` logged 419 unsupported non-idle inhibit requests in the
current boot, including 54 in the final audited hour. Current Wayland and
desktop environment variables are present in the user manager, and the old
GTK portal activation failures no longer occur.

Code and Slack currently hold direct sleep or shutdown inhibitors and are
reasonable candidates, but the journal does not identify the caller. Reproduce
the warning while closing one candidate at a time or capture D-Bus sender
metadata. Do not suppress portal warnings globally before identifying the
client.

### Investigate Waybar Tray Assertions

Status: monitor.

Waybar emitted paired GTK accelerator assertions while its tray module was
active. Four records appeared in the current boot. If tray menus or shortcuts
misbehave, update Waybar and GTK together, temporarily remove the tray module
to confirm the source, and report a reproducible issue upstream.

### Monitor WirePlumber And Bluetooth Profiles

Status: monitor.

WirePlumber emits one ACP device-creation warning per session. Isolated
Bluetooth profile and transport errors also occurred, but PipeWire,
WirePlumber, and Bluetooth remained active without restarts.

Only add a per-device WirePlumber rule if an audio card or profile is actually
missing. If Bluetooth audio glitches recur, reproduce with a narrow journal
window and re-pair the affected device before changing global audio policy.

### Recheck Historical Desktop Crashes

Status: monitor after upgrades.

Coredump metadata contains 29 user-process crashes from June and July 2026,
including old Hyprlock, Hypridle, Hyprsunset, portal, and WirePlumber failures.
No current coredumps were found, and all related components are currently
healthy.

Because lock reliability is important, test password and fingerprint unlock
after full-system upgrades. The latest Hyprsunset day and night timer runs both
completed successfully.

### Recheck Firmware And Clocksource Messages

Status: monitor.

One clocksource watchdog read timeout appeared in each audited boot without a
fallback, instability report, freeze, or timing error. Install AMD microcode
and check Lenovo firmware before treating this as a kernel defect.

### Decide Tailscale Startup Policy

Status: operator decision.

`tailscaled.service` is active but disabled and was started manually well after
boot. Leave it disabled if on-demand startup is intentional. Enable it only if
the tailnet must be available after every reboot, and retest DNS coexistence
with Cisco first.

### Decide Journal Retention

Status: no change recommended now.

Approximately two months and 157 boots consume 891 MiB. This is reasonable on
the current filesystem and was useful during diagnosis. If retention becomes a
space concern, add an explicit journald drop-in rather than vacuuming logs
ad hoc.

## Verify After The Next Reboot

- Confirm that the stale `nvidia_uvm` modules-load error is gone. Removing the
  unused NVIDIA packages rebuilt the initramfs during the current boot.
- Confirm that Greetd remains the active display manager.
- Check that no new failed system or user units appear.
- Recheck AMDGPU, NVMe, Wi-Fi, Bluetooth, and Cisco warning counts.
- Recheck OpenCode and OpenClaw health and memory peaks.

## Expected Noise

The following records do not currently justify configuration changes:

- VirtualBox DKMS kernel-taint and module mapping messages.
- Unsupported Intel TDX/VMX probes on this AMD host.
- Unsupported optional AMD x2AVIC capability messages.
- Goodix fingerprint-reader USB resets without fingerprint failures.
- One watchdog handoff message during an orderly shutdown.
- `man-db.service` runtime outside the boot critical path.
- Filesystem, package-hook, and service teardown messages that completed
  successfully.

## Read-Only Review Commands

Use these checks before implementing any backlog item:

```bash
systemctl --failed --no-pager
systemctl --user --failed --no-pager
journalctl -b -p warning..alert --no-pager
journalctl -k -b -p warning..alert --no-pager
journalctl --user -b -p warning..alert --no-pager
journalctl --disk-usage
systemd-analyze time
systemd-analyze critical-chain
pacman -Qqdt
```

Commands that install packages, enable system units, change `/etc`, rebuild an
initramfs, or update GRUB require root privileges. The operator must run those
commands directly in an interactive terminal after reviewing the transaction.
