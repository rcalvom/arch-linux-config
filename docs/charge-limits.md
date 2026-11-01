# Dock-Aware Charge Limits

`archcfg-charge-limit.service` sets battery charge thresholds through the kernel's standard `charge_control_*_threshold` sysfs interface. It is a oneshot service reconciled by `archcfg-charge-limit.timer`, with udev activation hints; it is not a persistent daemon.

## Policy

- A dock is present when AC power is online and a USB device product contains the configured `DOCK_PRODUCT_PATTERN`.
- Docked systems use a 50% charge ceiling.
- Direct AC power and battery operation use a 90% charge ceiling.
- The start threshold is 0%, so charging resumes whenever capacity is below the selected ceiling.

The default pattern, `dock`, matches USB product strings case-insensitively without hard-coding a bus number or connector name. A matching USB device plus an online `Mains` supply selects the dock policy; this does not prove that the dock supplies the power. A separate charger with a USB-connected dock can select the same policy.

## Events

Activation and reconciliation use:

- Power-supply and USB udev activation hints.
- Service enablement at `multi-user.target` during boot.
- A timer scheduled 10 seconds after the previous service invocation finishes, with 1-second accuracy.

The helper samples the dock/AC policy twice, 2 seconds apart. If the samples disagree, it leaves thresholds unchanged until a later invocation. Udev alone does not reliably retrigger an already active device dependency on change or removal; the timer handles missed events and repeated transitions. See [system policies](system-policies.md) for timing and unsupported-hardware limits.

The service runs after UPower so it overrides any static UPower hardware default with the selected dock-aware value.

## Critical Battery Safeguard

All install profiles include UPower and install `/etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf`. While discharging, UPower requests a system suspend at 3% battery. Hypridle receives the sleep request and locks the Wayland session before suspension on the Wayland desktop profiles.

`Suspend` is explicitly enabled because UPower classifies it as risky at critical power. Hibernate is intentionally not selected: resume from swap is not configured or validated yet. Save work after the 20% and 10% Waybar warnings, and connect power before resuming from a 3% suspension.

## Configuration

The installed configuration is `/etc/archcfg/charge-limit.conf`:

```bash
CHARGE_START_THRESHOLD=0
DOCK_CHARGE_END_THRESHOLD=50
DOCK_PRODUCT_PATTERN=dock
AC_CHARGE_END_THRESHOLD=90
```

Change the pattern only if the dock reports a different USB product string. Inspect connected USB products with:

```bash
for product in /sys/bus/usb/devices/*/product; do
  printf '%s: %s\n' "$product" "$(<"$product")"
done
```

## Installation And Verification

Fresh target installation deploys the service and timer through the system configuration flow. For an explicitly approved existing-system migration, `sudo bash scripts/apply-charge-limits.sh` installs and enables both units, reloads udev rules and removes the legacy one-minute `battery-thresholds.timer`. This source fix does not mean the physical host has been migrated.

The helper requires an already installed `upower`; it does not install packages. Existing charge-limit and UPower policy files are preserved, including local values and permissions. Missing policies receive repository defaults. Changed managed helpers, units and rules, and removed legacy files, are backed up before mutation in a unique private directory under `/var/lib/arch-linux-config/charge-limit-backups/`; original absence is recorded. Identical files are not rewritten and a no-change rerun creates no backup, but service and udev reconciliation still runs. Redirected destinations are rejected.

This is a system-changing helper, not a dry-run command. It enables the timer and service, restarts an already active UPower service and can set real battery thresholds. Its backups cover files only: there is no automatic rollback or restoration of previous service enablement/runtime state. Review preserved policies and unit overrides separately. `apply-config.sh` does not invoke this helper or deploy system policies.

Verify the selected policy without modifying thresholds:

```bash
sudo /usr/local/libexec/archcfg-charge-limit --dry-run
```

Check the service and the active hardware values:

```bash
systemctl status archcfg-charge-limit.service
systemctl status archcfg-charge-limit.timer
cat /sys/class/power_supply/BAT0/charge_control_start_threshold
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

Inspect the effective UPower policy with:

```bash
upower -d
```

These are repository defaults, not a statement of current host state. See the dated [deployment matrix](host-deployment.md) before treating pending timer work as complete.
