#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/charge-limit-backups

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

require_file() {
  [[ -f "$1" ]] || die "Missing required file: $1"
}

backup_path() {
  local path=$1
  local destination="$BACKUP_DIR/files$path"

  if [[ -e "$path" || -L "$path" ]]; then
    install -dm700 "$(dirname -- "$destination")"
    cp -a -- "$path" "$destination"
  fi
}

main() {
  require_root
  command -v upower >/dev/null 2>&1 || die "Install upower before applying the critical battery policy"
  require_file "$REPO_DIR/power/charge-limit.conf"
  require_file "$REPO_DIR/power/bin/archcfg-charge-limit"
  require_file "$REPO_DIR/power/systemd/archcfg-charge-limit.service"
  require_file "$REPO_DIR/power/udev/99-archcfg-charge-limit.rules"
  require_file "$REPO_DIR/power/upower/90-archcfg-critical-battery.conf"

  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S)"
  install -dm700 "$BACKUP_DIR"
  backup_path /etc/archcfg/charge-limit.conf
  backup_path /etc/systemd/system/battery-thresholds.service
  backup_path /etc/systemd/system/battery-thresholds.timer
  backup_path /usr/local/bin/battery_thresholds.sh
  backup_path /etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf

  log_info "Installing battery charge and critical-power policies"
  install -Dm644 "$REPO_DIR/power/charge-limit.conf" /etc/archcfg/charge-limit.conf
  install -Dm755 "$REPO_DIR/power/bin/archcfg-charge-limit" /usr/local/libexec/archcfg-charge-limit
  install -Dm644 "$REPO_DIR/power/systemd/archcfg-charge-limit.service" /etc/systemd/system/archcfg-charge-limit.service
  install -Dm644 "$REPO_DIR/power/udev/99-archcfg-charge-limit.rules" /etc/udev/rules.d/99-archcfg-charge-limit.rules
  install -Dm644 "$REPO_DIR/power/upower/90-archcfg-critical-battery.conf" /etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf

  if [[ -f /etc/systemd/system/battery-thresholds.timer ]]; then
    systemctl disable --now battery-thresholds.timer
  fi
  if [[ -f /etc/systemd/system/battery-thresholds.service ]]; then
    systemctl stop battery-thresholds.service
  fi
  rm -f /etc/systemd/system/battery-thresholds.service
  rm -f /etc/systemd/system/battery-thresholds.timer
  rm -f /usr/local/bin/battery_thresholds.sh

  systemctl daemon-reload
  udevadm control --reload-rules
  systemctl enable --now archcfg-charge-limit.service
  systemctl is-enabled --quiet archcfg-charge-limit.service || die "Charge limit service was not enabled"
  if systemctl is-active --quiet upower.service; then
    systemctl restart upower.service
  fi
  /usr/local/libexec/archcfg-charge-limit --dry-run

  log_info "Battery policies installed; legacy timer backup: $BACKUP_DIR"
}

main "$@"
