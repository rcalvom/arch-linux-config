#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export ARCHCFG_POWER_SYS_ROOT="$test_dir/sys"
export ARCHCFG_CHARGE_LIMIT_CONFIG="$repo/power/charge-limit.conf"
export ARCHCFG_POWER_DEBOUNCE_SECONDS=0
battery="$ARCHCFG_POWER_SYS_ROOT/class/power_supply/BAT0"
ac="$ARCHCFG_POWER_SYS_ROOT/class/power_supply/AC"
dock="$ARCHCFG_POWER_SYS_ROOT/bus/usb/devices/1-1"
mkdir -p "$battery" "$ac" "$dock"
printf 'Mains\n' > "$ac/type"
printf '1\n' > "$ac/online"
printf '0\n' > "$battery/charge_control_start_threshold"
printf '100\n' > "$battery/charge_control_end_threshold"
check_limit() {
  bash "$repo/power/bin/archcfg-charge-limit" > "$test_dir/output"
  [[ "$(<"$battery/charge_control_end_threshold")" == "$1" ]]
}
check_limit 90
printf 'Mock Dock\n' > "$dock/product"
check_limit 50
printf '0\n' > "$ac/online"
check_limit 90
printf '1\n' > "$ac/online"
check_limit 50
rm "$dock/product"
check_limit 90
printf 'Mock Dock\n' > "$dock/product"
check_limit 50
check_limit 50
! grep -q '^Set ' "$test_dir/output"
# Change topology between the two samples; do not apply the stale first sample.
sleep() { rm -f "$ARCHCFG_POWER_SYS_ROOT/bus/usb/devices/1-1/product"; }
export -f sleep
check_limit 50
unset -f sleep
check_limit 90
printf 'Mock Dock\n' > "$dock/product"
bash "$repo/power/bin/archcfg-charge-limit" --dry-run > "$test_dir/output"
[[ "$(<"$battery/charge_control_end_threshold")" == 90 ]]
rm "$battery/charge_control_start_threshold" "$battery/charge_control_end_threshold"
bash "$repo/power/bin/archcfg-charge-limit" > "$test_dir/output"
grep -q 'nothing to apply' "$test_dir/output"
grep -qx 'OnUnitInactiveSec=10s' "$repo/power/systemd/archcfg-charge-limit.timer"
printf 'Power transition fixtures passed\n'
