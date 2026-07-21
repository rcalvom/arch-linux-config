#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/network-backups
BACKUP_DIR=

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

usage() {
  printf '%s\n' "Usage: rollback-iwd-wlan0.sh --backup <directory>"
}

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

restore_path() {
  local path=$1
  local source="$BACKUP_DIR/files$path"

  if [[ -e "$source" || -L "$source" ]]; then
    install -dm755 "$(dirname -- "$path")"
    rm -f -- "$path"
    cp -a -- "$source" "$path"
    return
  fi

  if grep -qxF "$path" "$BACKUP_DIR/absent-paths"; then
    rm -f -- "$path"
    return
  fi

  die "Backup is incomplete for $path"
}

restore_new_path() {
  local path=$1
  local source="$BACKUP_DIR/files$path"

  if [[ -e "$source" || -L "$source" ]] || grep -qxF "$path" "$BACKUP_DIR/absent-paths"; then
    restore_path "$path"
  else
    rm -f -- "$path"
  fi
}

was_enabled() {
  [[ -e "$BACKUP_DIR/enabled-$1" ]]
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backup)
        [[ -n "${2-}" ]] || die "--backup requires a directory"
        BACKUP_DIR=$(realpath -e "$2")
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
  [[ -n "$BACKUP_DIR" ]] || die "--backup is required"
  [[ "$BACKUP_DIR" == "$BACKUP_ROOT"/* ]] || die "Backup must be under $BACKUP_ROOT"
  [[ -f "$BACKUP_DIR/absent-paths" ]] || die "Invalid backup directory: $BACKUP_DIR"

  log_info "Restoring NetworkManager ownership of wlan0"
  systemctl disable --now host-network-online.service
  if [[ -f /etc/systemd/system/archcfg-reset-resolved-if-stub.path || -f /usr/lib/systemd/system/archcfg-reset-resolved-if-stub.path ]]; then
    systemctl disable --now archcfg-reset-resolved-if-stub.path
  fi
  systemctl disable --now iwd.service

  restore_path /etc/NetworkManager/conf.d/10-iwd-wlan0.conf
  restore_path /etc/iwd/main.conf
  restore_path /etc/systemd/system/host-network-online.service
  restore_new_path /etc/systemd/system/archcfg-reset-resolved-if-stub.service
  restore_new_path /etc/systemd/system/archcfg-reset-resolved-if-stub.path
  restore_path /usr/local/libexec/archcfg-wait-network-online
  restore_new_path /usr/local/libexec/archcfg-reset-resolved-if-stub
  restore_path /etc/resolv.conf

  systemctl daemon-reload
  if was_enabled systemd-resolved.service; then
    systemctl enable --now systemd-resolved.service
  else
    systemctl disable --now systemd-resolved.service
  fi

  if was_enabled archcfg-reset-resolved-if-stub.path; then
    systemctl enable archcfg-reset-resolved-if-stub.path
  fi

  systemctl enable NetworkManager.service
  systemctl restart NetworkManager.service
  if was_enabled NetworkManager-wait-online.service; then
    systemctl enable NetworkManager-wait-online.service
  else
    systemctl disable NetworkManager-wait-online.service
  fi

  log_info "NetworkManager has been restored. It will reactivate wpa_supplicant for wlan0."
}

main "$@"
