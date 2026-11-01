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
  if [[ -z ${BACKUP_DIR:-} ]]; then
    install -dm700 "$BACKUP_ROOT"
    BACKUP_DIR=$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S).XXXXXXXX")
  fi
  local destination="$BACKUP_DIR/files$path"

  if [[ -e "$path" || -L "$path" ]]; then
    install -dm700 "$(dirname -- "$destination")"
    cp -a -- "$path" "$destination" || die "Backup failed: $path"
  else
    printf '%s\n' "$path" >> "$BACKUP_DIR/absent-paths.txt" || die "Cannot record absence: $path"
  fi
}

install_policy_file() {
  local source=$1 destination=$2 mode=$3 preserve=${4:-false}
  if [[ -e "$destination" ]]; then
    if "$preserve"; then
      log_info "Preserving local policy: $destination"
      return
    fi
    if cmp -s -- "$source" "$destination" && [[ $(stat -c %a -- "$destination") == "$mode" ]]; then
      return
    fi
  fi
  backup_path "$destination"
  install -Dm"$mode" -- "$source" "$destination"
}

main() {
  case "${1:-}" in
    --help | -h) printf 'Usage: bash scripts/apply-charge-limits.sh\nDeploy system battery policies as root; existing policy configuration is preserved.\n'; return ;;
  esac
  (($# == 0)) || die "Unknown argument: $1"
  require_root
  umask 077
  command -v upower >/dev/null 2>&1 || die "Install upower before applying the critical battery policy"
  require_file "$REPO_DIR/power/charge-limit.conf"
  require_file "$REPO_DIR/power/bin/archcfg-charge-limit"
  require_file "$REPO_DIR/power/systemd/archcfg-charge-limit.service"
  require_file "$REPO_DIR/power/systemd/archcfg-charge-limit.timer"
  require_file "$REPO_DIR/power/udev/99-archcfg-charge-limit.rules"
  require_file "$REPO_DIR/power/upower/90-archcfg-critical-battery.conf"

  BACKUP_DIR=
  local path parent
  local -a destinations=(
    /etc/archcfg/charge-limit.conf
    /usr/local/libexec/archcfg-charge-limit
    /etc/systemd/system/archcfg-charge-limit.service
    /etc/systemd/system/archcfg-charge-limit.timer
    /etc/udev/rules.d/99-archcfg-charge-limit.rules
    /etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf
    /etc/systemd/system/battery-thresholds.service
    /etc/systemd/system/battery-thresholds.timer
    /usr/local/bin/battery_thresholds.sh
  )
  # Refuse redirected paths before backing up, replacing or removing any file.
  for path in "${destinations[@]}" "$BACKUP_ROOT"; do
    [[ ! -L "$path" ]] || die "Symlink rejected: $path"
    [[ "$path" == "$BACKUP_ROOT" || ! -e "$path" || -f "$path" ]] || die "Not a regular file: $path"
    [[ ! -f "$path" || $(stat -c %h -- "$path") == 1 ]] || die "Hard-linked file rejected: $path"
    parent=${path%/*}
    while [[ "$parent" != / ]]; do
      [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] || die "Unsafe parent: $parent"
      parent=$(dirname -- "$parent")
    done
  done
  for path in /etc/systemd/system/battery-thresholds.service /etc/systemd/system/battery-thresholds.timer /usr/local/bin/battery_thresholds.sh; do
    if [[ -e "$path" ]]; then backup_path "$path"; fi
  done

  log_info "Installing battery charge and critical-power policies"
  install_policy_file "$REPO_DIR/power/charge-limit.conf" /etc/archcfg/charge-limit.conf 644 true
  install_policy_file "$REPO_DIR/power/bin/archcfg-charge-limit" /usr/local/libexec/archcfg-charge-limit 755
  install_policy_file "$REPO_DIR/power/systemd/archcfg-charge-limit.service" /etc/systemd/system/archcfg-charge-limit.service 644
  install_policy_file "$REPO_DIR/power/systemd/archcfg-charge-limit.timer" /etc/systemd/system/archcfg-charge-limit.timer 644
  install_policy_file "$REPO_DIR/power/udev/99-archcfg-charge-limit.rules" /etc/udev/rules.d/99-archcfg-charge-limit.rules 644
  install_policy_file "$REPO_DIR/power/upower/90-archcfg-critical-battery.conf" /etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf 644 true

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
  systemctl enable --now archcfg-charge-limit.timer
  systemctl is-enabled --quiet archcfg-charge-limit.service || die "Charge limit service was not enabled"
  systemctl is-enabled --quiet archcfg-charge-limit.timer || die "Charge limit timer was not enabled"
  systemctl is-active --quiet archcfg-charge-limit.timer || die "Charge limit timer is not active"
  if systemctl is-active --quiet upower.service; then
    systemctl restart upower.service
  fi
  /usr/local/libexec/archcfg-charge-limit --dry-run

  log_info "Battery policies installed; file backup: ${BACKUP_DIR:-none (unchanged)}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
