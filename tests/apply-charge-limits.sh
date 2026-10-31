#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/repo/scripts" "$tmp/repo/lib" "$tmp/root" "$tmp/mocks"
cp -a "$repo/power" "$tmp/repo/"
cp "$repo/lib/log.sh" "$tmp/repo/lib/"
# Relocate all system destinations in the fixture, without a production root override.
sed -e "s@/etc/@$tmp/root/etc/@g" -e "s@/usr/local/@$tmp/root/usr/local/@g" \
  -e "s@/var/lib/@$tmp/root/var/lib/@g" "$repo/scripts/apply-charge-limits.sh" > "$tmp/repo/scripts/apply-charge-limits.sh"
printf '#!/bin/sh\nexit 0\n' > "$tmp/repo/power/bin/archcfg-charge-limit"
# shellcheck source=scripts/apply-charge-limits.sh
source "$tmp/repo/scripts/apply-charge-limits.sh"
require_root() { :; }
upower() { :; }
systemctl() {
  printf '%s\n' "$*" >> "$tmp/systemctl"
  [[ "$*" != 'is-active --quiet upower.service' && "$*" != "${FAIL_SYSTEMCTL:-never}" ]]
}
udevadm() { printf '%s\n' "$*" >> "$tmp/udevadm"; }
main > "$tmp/first"
cmp "$repo/power/systemd/archcfg-charge-limit.timer" "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer"
grep -qx 'enable --now archcfg-charge-limit.timer' "$tmp/systemctl"
grep -qx 'is-active --quiet archcfg-charge-limit.timer' "$tmp/systemctl"
[[ $(stat -c %a "$BACKUP_DIR") == 700 ]]
[[ $(stat -c %a "$BACKUP_DIR/absent-paths.txt") == 600 ]]
first=$BACKUP_DIR
main > "$tmp/second"
[[ -z "$BACKUP_DIR" ]]
printf 'local charge policy\n' > "$tmp/root/etc/archcfg/charge-limit.conf"
chmod 600 "$tmp/root/etc/archcfg/charge-limit.conf"
printf 'local critical policy\n' > "$tmp/root/etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf"
printf 'old timer\n' > "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer"
printf 'legacy timer\n' > "$tmp/root/etc/systemd/system/battery-thresholds.timer"
main > "$tmp/migration"
[[ -n "$BACKUP_DIR" && "$BACKUP_DIR" != "$first" ]]
[[ $(< "$BACKUP_DIR/files$tmp/root/etc/systemd/system/archcfg-charge-limit.timer") == 'old timer' ]]
[[ $(< "$BACKUP_DIR/files$tmp/root/etc/systemd/system/battery-thresholds.timer") == 'legacy timer' ]]
[[ ! -e "$tmp/root/etc/systemd/system/battery-thresholds.timer" ]]
[[ $(< "$tmp/root/etc/archcfg/charge-limit.conf") == 'local charge policy' ]]
[[ $(stat -c %a "$tmp/root/etc/archcfg/charge-limit.conf") == 600 ]]
[[ $(< "$tmp/root/etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf") == 'local critical policy' ]]
printf 'must survive failed backup\n' > "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer"
# shellcheck disable=SC2329 # Invoked indirectly by backup_path.
if (cp() { return 1; }; main) > "$tmp/backup-failure" 2>&1; then exit 1; fi
[[ $(< "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer") == 'must survive failed backup' ]]
main > "$tmp/recover"
if (FAIL_SYSTEMCTL='is-active --quiet archcfg-charge-limit.timer'; main) > "$tmp/inactive" 2>&1; then exit 1; fi
rm "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer"
ln -s "$tmp/outside" "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer"
if (main) > "$tmp/symlink" 2>&1; then exit 1; fi
[[ ! -e "$tmp/outside" ]]
rm "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer"
mv "$tmp/repo/power/systemd/archcfg-charge-limit.timer" "$tmp/timer-source"
if (main) > "$tmp/missing-source" 2>&1; then exit 1; fi
[[ ! -e "$tmp/root/etc/systemd/system/archcfg-charge-limit.timer" ]]
mv "$tmp/timer-source" "$tmp/repo/power/systemd/archcfg-charge-limit.timer"
mv "$tmp/root/etc/archcfg" "$tmp/local-policy"
ln -s "$tmp/local-policy" "$tmp/root/etc/archcfg"
if (main) > "$tmp/parent-symlink" 2>&1; then exit 1; fi
[[ $(< "$tmp/local-policy/charge-limit.conf") == 'local charge policy' ]]
if (main --unknown) > "$tmp/parser" 2>&1; then exit 1; fi
main --help > "$tmp/help"
printf 'PASS: charge deployment, timer activation, preservation, idempotency, private backups and failures (mocked system operations)\n'
