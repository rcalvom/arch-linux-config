#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
ROLLBACK_DELAY=10m

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die 'Run this script as root.'
}

backup_path() {
  local source=$1
  local destination=$2

  if [[ -e "$source" || -L "$source" ]]; then
    install -dm700 "$(dirname -- "$destination")"
    cp -a --no-dereference "$source" "$destination"
  else
    : >"$destination.absent"
  fi
}

write_personal_profile() {
  local connection=$1
  local ssid
  local passphrase
  local profile_path
  local safe_ssid_pattern='^[[:alnum:]_ -]+$'

  ssid=$(nmcli -g 802-11-wireless.ssid connection show "$connection")
  passphrase=$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show "$connection")
  [[ -n "$ssid" && -n "$passphrase" ]] || die "NetworkManager profile $connection has no usable Wi-Fi passphrase"
  [[ "$ssid" =~ $safe_ssid_pattern ]] || die "SSID $ssid needs an explicitly encoded IWD filename"
  profile_path="/var/lib/iwd/$ssid.psk"
  umask 077
  printf '[Settings]\nAutoConnect=true\n\n[Security]\nPassphrase=%s\n' "$passphrase" >"$profile_path"
  chown root:root "$profile_path"
  chmod 600 "$profile_path"
  unset passphrase
}

write_eduroam_profile() {
  local connection=$1
  local identity
  local password
  local ca_path
  local domain

  identity=$(nmcli -g 802-1x.identity connection show "$connection")
  password=$(nmcli --show-secrets -g 802-1x.password connection show "$connection")
  ca_path=$(nmcli -g 802-1x.ca-cert connection show "$connection")
  domain=$(nmcli -g 802-1x.domain-suffix-match connection show "$connection")
  ca_path=${ca_path#file://}
  [[ -n "$identity" && -n "$password" && -n "$ca_path" && -f "$ca_path" && -n "$domain" ]] || die 'The eduroam NetworkManager profile is missing identity, password, CA, or domain validation'
  install -Dm644 "$ca_path" /etc/iwd/eduroam-ca.pem
  umask 077
  cat > /var/lib/iwd/eduroam.8021x <<EOF
[Settings]
AutoConnect=true

[Security]
EAP-Method=PEAP
EAP-Identity=$identity
EAP-PEAP-CACert=/etc/iwd/eduroam-ca.pem
EAP-PEAP-ServerDomainMask=$domain
EAP-PEAP-Phase2-Method=MSCHAPV2
EAP-PEAP-Phase2-Identity=$identity
EAP-PEAP-Phase2-Password=$password
EOF
  chown root:root /var/lib/iwd/eduroam.8021x
  chmod 600 /var/lib/iwd/eduroam.8021x
  unset password
}

find_eduroam_connection() {
  local connection

  while IFS= read -r connection; do
    [[ $(nmcli -g 802-11-wireless.ssid connection show "$connection") == eduroam ]] && {
      printf '%s\n' "$connection"
      return 0
    }
  done < <(nmcli -t -f NAME,TYPE connection show | while IFS=: read -r name type; do
    [[ "$type" == 802-11-wireless ]] && printf '%s\n' "$name"
  done)
  return 1
}

main() {
  local wifi_interface
  local active_connection
  local eduroam_connection
  local backup_dir

  while (($#)); do
    case "$1" in
      --rollback-delay)
        [[ -n ${2-} ]] || die '--rollback-delay requires a value'
        ROLLBACK_DELAY=$2
        shift 2
        ;;
      --help)
        printf 'Usage: %s [--rollback-delay SYSTEMD-TIME]\n' "${0##*/}"
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  require_root
  [[ ! -e /sys/class/net/cscotun0 ]] || die 'Disconnect Cisco Secure Client before migrating.'
  wifi_interface=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')
  [[ -n "$wifi_interface" ]] || die 'No NetworkManager-connected Wi-Fi interface was found.'
  active_connection=$(nmcli -g GENERAL.CONNECTION device show "$wifi_interface")
  [[ -n "$active_connection" && "$active_connection" != '--' ]] || die 'Could not identify the active NetworkManager Wi-Fi profile.'

  backup_dir="/var/lib/arch-linux-config/network-backups/$(date +%Y%m%d-%H%M%S)-iwd-only"
  install -dm700 "$backup_dir"
  backup_path /etc/resolv.conf "$backup_dir/resolv.conf"
  backup_path /etc/iwd "$backup_dir/iwd"
  backup_path /etc/systemd/network "$backup_dir/network"
  backup_path /etc/systemd/system/iwd.service "$backup_dir/iwd.service"
  backup_path /etc/systemd/system/host-network-online.service "$backup_dir/host-network-online.service"
  backup_path /etc/systemd/system/archcfg-reset-resolved-if-stub.service "$backup_dir/archcfg-reset-resolved-if-stub.service"
  backup_path /etc/systemd/system/archcfg-reset-resolved-if-stub.path "$backup_dir/archcfg-reset-resolved-if-stub.path"
  backup_path /usr/local/libexec/archcfg-wait-network-online "$backup_dir/archcfg-wait-network-online"
  backup_path /usr/local/libexec/archcfg-reset-resolved-if-stub "$backup_dir/archcfg-reset-resolved-if-stub"
  systemctl is-enabled NetworkManager.service >"$backup_dir/networkmanager.enabled" 2>&1 || true
  systemctl is-enabled iwd.service >"$backup_dir/iwd.enabled" 2>&1 || true
  cp -a /etc/NetworkManager/system-connections "$backup_dir/networkmanager-connections"

  install -Dm644 "$REPO_DIR/network/iwd/main.conf" /etc/iwd/main.conf
  install -Dm644 "$REPO_DIR/network/systemd/network/20-wired.network" /etc/systemd/network/20-wired.network
  install -Dm644 "$REPO_DIR/network/systemd/host-network-online.service" /etc/systemd/system/host-network-online.service
  install -Dm644 "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.service" /etc/systemd/system/archcfg-reset-resolved-if-stub.service
  install -Dm644 "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.path" /etc/systemd/system/archcfg-reset-resolved-if-stub.path
  install -Dm755 "$REPO_DIR/network/bin/archcfg-wait-network-online" /usr/local/libexec/archcfg-wait-network-online
  install -Dm755 "$REPO_DIR/network/bin/archcfg-reset-resolved-if-stub" /usr/local/libexec/archcfg-reset-resolved-if-stub
  install -Dm755 "$REPO_DIR/scripts/rollback-iwd-wlan0.sh" /usr/local/libexec/archcfg-rollback-iwd-network
  write_personal_profile "$active_connection"
  if eduroam_connection=$(find_eduroam_connection); then
    write_eduroam_profile "$eduroam_connection"
  else
    die 'No eduroam NetworkManager profile was found.'
  fi
  ln -sfn "$backup_dir" /var/lib/arch-linux-config/network-backups/current-iwd-only
  install -dm700 /var/lib/arch-linux-config/network-cutover
  : >/var/lib/arch-linux-config/network-cutover/armed

  systemctl daemon-reload
  systemctl unmask iwd.service
  systemctl enable systemd-resolved.service systemd-networkd.service iwd.service host-network-online.service archcfg-reset-resolved-if-stub.path
  systemctl disable systemd-networkd-wait-online.service NetworkManager-wait-online.service
  systemd-run --unit=archcfg-network-rollback --on-active="$ROLLBACK_DELAY" /usr/local/libexec/archcfg-rollback-iwd-network "$backup_dir"

  rm -f /etc/resolv.conf
  ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  systemctl start systemd-resolved.service systemd-networkd.service
  systemctl start host-network-online.service archcfg-reset-resolved-if-stub.path
  systemctl stop NetworkManager.service
  systemctl stop wpa_supplicant.service || true
  systemctl mask NetworkManager.service NetworkManager-wait-online.service NetworkManager-dispatcher.service wpa_supplicant.service
  systemctl start iwd.service

  printf '[INFO] IWD cutover started for %s. Rollback is armed for %s.\n' "$wifi_interface" "$ROLLBACK_DELAY"
  printf '[INFO] Validate Wi-Fi and DNS, then run: sudo rm /var/lib/arch-linux-config/network-cutover/armed && sudo systemctl stop archcfg-network-rollback.timer\n'
}

main "$@"
