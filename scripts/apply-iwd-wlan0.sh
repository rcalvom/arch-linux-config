#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/network-backups

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
  else
    printf '%s\n' "$path" >> "$BACKUP_DIR/absent-paths"
  fi
}

save_enabled_state() {
  local unit=$1

  if systemctl is-enabled --quiet "$unit"; then
    touch "$BACKUP_DIR/enabled-$unit"
  fi
}

main() {
  local confirmation

  require_root
  require_file "$REPO_DIR/network/NetworkManager/10-iwd-wlan0.conf"
  require_file "$REPO_DIR/network/iwd/main.conf"
  require_file "$REPO_DIR/network/systemd/host-network-online.service"
  require_file "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.service"
  require_file "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.path"
  require_file "$REPO_DIR/network/bin/archcfg-wait-network-online"
  require_file "$REPO_DIR/network/bin/archcfg-reset-resolved-if-stub"
  command -v iwctl >/dev/null 2>&1 || die "Install iwd before migration"
  command -v impala >/dev/null 2>&1 || die "Install impala before migration"
  command -v resolvectl >/dev/null 2>&1 || die "systemd-resolved is required"
  ip link show wlan0 >/dev/null 2>&1 || die "Wi-Fi interface wlan0 was not found"

  if ip link show cscotun0 >/dev/null 2>&1 && ip link show cscotun0 | grep -q '<.*UP'; then
    die "Disconnect the Cisco VPN before migrating Wi-Fi"
  fi

  log_warn "This will disconnect NetworkManager from wlan0 and hand it to IWD/Impala."
  log_warn "Keep this terminal open and have your Wi-Fi passphrase available."
  printf 'Type MIGRATE to continue: '
  read -r confirmation
  [[ "$confirmation" == "MIGRATE" ]] || die "Migration cancelled"

  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S)"
  install -dm700 "$BACKUP_DIR"
  : > "$BACKUP_DIR/absent-paths"

  backup_path /etc/NetworkManager/conf.d/10-iwd-wlan0.conf
  backup_path /etc/iwd/main.conf
  backup_path /etc/systemd/system/host-network-online.service
  backup_path /etc/systemd/system/archcfg-reset-resolved-if-stub.service
  backup_path /etc/systemd/system/archcfg-reset-resolved-if-stub.path
  backup_path /usr/local/libexec/archcfg-wait-network-online
  backup_path /usr/local/libexec/archcfg-reset-resolved-if-stub
  backup_path /etc/resolv.conf
  save_enabled_state NetworkManager-wait-online.service
  save_enabled_state systemd-resolved.service
  save_enabled_state archcfg-reset-resolved-if-stub.path

  log_info "Installing IWD network configuration"
  install -Dm644 "$REPO_DIR/network/NetworkManager/10-iwd-wlan0.conf" /etc/NetworkManager/conf.d/10-iwd-wlan0.conf
  install -Dm644 "$REPO_DIR/network/iwd/main.conf" /etc/iwd/main.conf
  install -Dm644 "$REPO_DIR/network/systemd/host-network-online.service" /etc/systemd/system/host-network-online.service
  install -Dm644 "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.service" /etc/systemd/system/archcfg-reset-resolved-if-stub.service
  install -Dm644 "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.path" /etc/systemd/system/archcfg-reset-resolved-if-stub.path
  install -Dm755 "$REPO_DIR/network/bin/archcfg-wait-network-online" /usr/local/libexec/archcfg-wait-network-online
  install -Dm755 "$REPO_DIR/network/bin/archcfg-reset-resolved-if-stub" /usr/local/libexec/archcfg-reset-resolved-if-stub
  ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  systemctl daemon-reload
  systemctl disable --now NetworkManager-wait-online.service
  systemctl stop iwd.service
  systemctl restart NetworkManager.service
  systemctl stop wpa_supplicant.service
  systemctl enable --now systemd-resolved.service
  systemctl enable iwd.service
  systemctl start iwd.service
  systemctl enable host-network-online.service
  systemctl enable --now archcfg-reset-resolved-if-stub.path

  systemctl is-active --quiet NetworkManager.service || die "NetworkManager did not restart"
  systemctl is-active --quiet iwd.service || die "IWD did not start"

  log_info "IWD now owns wlan0. Connect using Impala."
  log_info "If connectivity fails, run: sudo $REPO_DIR/scripts/rollback-iwd-wlan0.sh --backup $BACKUP_DIR"
}

main "$@"
