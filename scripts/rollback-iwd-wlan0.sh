#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

restore_path() {
  local destination=$1
  local backup=$2

  rm -rf -- "$destination"
  if [[ ! -e "$backup.absent" ]]; then
    cp -a --no-dereference "$backup" "$destination"
  fi
}

main() {
  local force=false
  local backup_dir=/var/lib/arch-linux-config/network-backups/current-iwd-only

  if [[ ${1-} == --help ]]; then
    printf 'Usage: %s [--force] [BACKUP-DIRECTORY]\n' "${0##*/}"
    exit 0
  fi
  if [[ ${1-} == --force ]]; then
    force=true
    shift
  fi
  if [[ -n ${1-} ]]; then
    backup_dir=$1
  fi

  [[ ${EUID:-$(id -u)} -eq 0 ]] || die 'Run this script as root.'
  [[ -d "$backup_dir" ]] || die "Missing network backup: $backup_dir"
  [[ "$force" == true || -e /var/lib/arch-linux-config/network-cutover/armed ]] || exit 0

  systemctl stop iwd.service systemd-networkd.service || true
  systemctl unmask NetworkManager.service NetworkManager-wait-online.service NetworkManager-dispatcher.service wpa_supplicant.service || true
  restore_path /etc/resolv.conf "$backup_dir/resolv.conf"
  restore_path /etc/iwd "$backup_dir/iwd"
  restore_path /etc/systemd/network "$backup_dir/network"
  restore_path /etc/systemd/system/iwd.service "$backup_dir/iwd.service"
  restore_path /etc/systemd/system/host-network-online.service "$backup_dir/host-network-online.service"
  restore_path /etc/systemd/system/archcfg-reset-resolved-if-stub.service "$backup_dir/archcfg-reset-resolved-if-stub.service"
  restore_path /etc/systemd/system/archcfg-reset-resolved-if-stub.path "$backup_dir/archcfg-reset-resolved-if-stub.path"
  restore_path /usr/local/libexec/archcfg-wait-network-online "$backup_dir/archcfg-wait-network-online"
  restore_path /usr/local/libexec/archcfg-reset-resolved-if-stub "$backup_dir/archcfg-reset-resolved-if-stub"
  systemctl daemon-reload
  systemctl disable iwd.service systemd-networkd.service systemd-resolved.service host-network-online.service archcfg-reset-resolved-if-stub.path || true
  systemctl enable NetworkManager.service
  if grep -qx 'enabled' "$backup_dir/networkmanager.enabled"; then
    systemctl enable NetworkManager-wait-online.service
  fi
  systemctl start NetworkManager.service
  rm -f /var/lib/arch-linux-config/network-cutover/armed
  printf '[INFO] NetworkManager rollback completed.\n'
}

main "$@"
