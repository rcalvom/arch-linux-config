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
  require_file "$REPO_DIR/power/charge-limit.conf"
  require_file "$REPO_DIR/power/bin/archcfg-charge-limit"
  require_file "$REPO_DIR/power/systemd/archcfg-charge-limit.service"
  require_file "$REPO_DIR/power/udev/99-archcfg-charge-limit.rules"

  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S)"
  install -dm700 "$BACKUP_DIR"
  backup_path /etc/archcfg/charge-limit.conf
  backup_path /etc/systemd/system/battery-thresholds.service
  backup_path /etc/systemd/system/battery-thresholds.timer
  backup_path /usr/local/bin/battery_thresholds.sh

  log_info "Installing dock-aware charge limit service"
  install -Dm644 "$REPO_DIR/power/charge-limit.conf" /etc/archcfg/charge-limit.conf
  install -Dm755 "$REPO_DIR/power/bin/archcfg-charge-limit" /usr/local/libexec/archcfg-charge-limit
  install -Dm644 "$REPO_DIR/power/systemd/archcfg-charge-limit.service" /etc/systemd/system/archcfg-charge-limit.service
  install -Dm644 "$REPO_DIR/power/udev/99-archcfg-charge-limit.rules" /etc/udev/rules.d/99-archcfg-charge-limit.rules

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
  /usr/local/libexec/archcfg-charge-limit --dry-run

  log_info "Charge limit service installed; legacy timer backup: $BACKUP_DIR"
}

main "$@"
