#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/network-backups
WIFI_INTERFACE="auto"

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"
# shellcheck source=lib/network.sh
source "$REPO_DIR/lib/network.sh"

usage() {
  printf '%s\n' "Usage: apply-iwd-wlan0.sh [--wifi-interface <auto|name>]"
}

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
  local wifi_interface
  local selection_status

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wifi-interface)
        [[ -n "${2-}" ]] || die "--wifi-interface requires a value"
        WIFI_INTERFACE=$2
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  require_root
  require_file "$REPO_DIR/network/iwd/main.conf"
  require_file "$REPO_DIR/network/systemd/host-network-online.service"
  require_file "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.service"
  require_file "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.path"
  require_file "$REPO_DIR/network/bin/archcfg-wait-network-online"
  require_file "$REPO_DIR/network/bin/archcfg-reset-resolved-if-stub"
  command -v iwctl >/dev/null 2>&1 || die "Install iwd before migration"
  command -v impala >/dev/null 2>&1 || die "Install impala before migration"
  command -v resolvectl >/dev/null 2>&1 || die "systemd-resolved is required"
  if wifi_interface=$(select_wifi_interface "$WIFI_INTERFACE"); then
    :
  else
    selection_status=$?
    case "$selection_status" in
      1) die "No Wi-Fi interface was detected" ;;
      2) die "Multiple Wi-Fi interfaces were detected; pass --wifi-interface <name>" ;;
      4) die "Wi-Fi interface $WIFI_INTERFACE is not wireless" ;;
      *) die "Invalid Wi-Fi interface: $WIFI_INTERFACE" ;;
    esac
  fi
  [[ "$wifi_interface" != "none" ]] || die "--wifi-interface none cannot migrate Wi-Fi"
  wifi_interface_is_wireless "$wifi_interface" || die "Wi-Fi interface $wifi_interface was not found"

  if ip link show cscotun0 >/dev/null 2>&1 && ip link show cscotun0 | grep -q '<.*UP'; then
    die "Disconnect the Cisco VPN before migrating Wi-Fi"
  fi

  log_warn "This will disconnect NetworkManager from $wifi_interface and hand it to IWD/Impala."
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
  write_iwd_networkmanager_config "$wifi_interface" /etc/NetworkManager/conf.d/10-iwd-wlan0.conf || die "Could not write NetworkManager IWD configuration"
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

  log_info "IWD now owns $wifi_interface. Connect using Impala."
  log_info "If connectivity fails, run: sudo $REPO_DIR/scripts/rollback-iwd-wlan0.sh --backup $BACKUP_DIR"
}

main "$@"
