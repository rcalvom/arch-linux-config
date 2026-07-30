# Dock-Aware Charge Limits

`archcfg-charge-limit.service` sets battery charge thresholds through the kernel's standard `charge_control_*_threshold` sysfs interface. It is an event-driven system service, not a timer or a persistent daemon.

## Policy

- A dock is present when AC power is online and a USB device product contains the configured `DOCK_PRODUCT_PATTERN`.
- Docked systems use a 50% charge ceiling.
- Direct AC power and battery operation use a 90% charge ceiling.
- The start threshold is 0%, so charging resumes whenever capacity is below the selected ceiling.

The default pattern, `dock`, detects the connected Dell dock without hard-coding its USB bus number or connector name.

## Events

The udev rule requests the system service when:

- AC or battery power-supply state changes.
- A USB device is added or removed.
- The system reaches `multi-user.target` during boot.

No periodic polling or fixed startup delay is used.

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

For an existing system, install the charge-limit service, the 3% critical-battery policy, and remove the legacy one-minute `battery-thresholds.timer` with:

```bash
sudo ./scripts/apply-charge-limits.sh
```

Install `upower` first when applying this migration to a system that was not created from these profiles.

The migration stores replaced files under `/var/lib/arch-linux-config/charge-limit-backups/`.

Verify the selected policy without modifying thresholds:

```bash
sudo /usr/local/libexec/archcfg-charge-limit --dry-run
```

Check the service and the active hardware values:

```bash
systemctl status archcfg-charge-limit.service
cat /sys/class/power_supply/BAT0/charge_control_start_threshold
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

Inspect the effective UPower policy with:

```bash
upower -d
```
