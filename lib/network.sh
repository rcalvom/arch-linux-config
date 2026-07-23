#!/usr/bin/env bash
set -euo pipefail

wifi_interface_name_is_valid() {
  local interface=$1

  [[ "$interface" =~ ^[[:alnum:]_.-]{1,15}$ ]]
}

network_interface_exists() {
  local interface=$1
  local net_root=${ARCHCFG_SYS_CLASS_NET:-/sys/class/net}

  [[ -e "$net_root/$interface" || -L "$net_root/$interface" ]]
}

wifi_interface_is_wireless() {
  local interface=$1
  local net_root=${ARCHCFG_SYS_CLASS_NET:-/sys/class/net}

  [[ -d "$net_root/$interface/wireless" ]]
}

list_wireless_interfaces() {
  local net_root=${ARCHCFG_SYS_CLASS_NET:-/sys/class/net}
  local path
  local interface

  for path in "$net_root"/*; do
    [[ -e "$path" || -L "$path" ]] || continue
    interface=${path##*/}
    wifi_interface_name_is_valid "$interface" || continue
    wifi_interface_is_wireless "$interface" || continue
    printf '%s\n' "$interface"
  done
}

select_wifi_interface() {
  local requested=$1
  local interfaces=()

  case "$requested" in
    none)
      printf '%s\n' none
      return 0
      ;;
    auto)
      mapfile -t interfaces < <(list_wireless_interfaces)
      case "${#interfaces[@]}" in
        1)
          printf '%s\n' "${interfaces[0]}"
          return 0
          ;;
        0)
          return 1
          ;;
        *)
          return 2
          ;;
      esac
      ;;
    *)
      wifi_interface_name_is_valid "$requested" || return 3
      if network_interface_exists "$requested" && ! wifi_interface_is_wireless "$requested"; then
        return 4
      fi
      printf '%s\n' "$requested"
      ;;
  esac
}

iwd_networkmanager_config() {
  local interface=$1

  wifi_interface_name_is_valid "$interface" || return 1
  printf '[keyfile]\nunmanaged-devices=interface-name:%s\n' "$interface"
}

write_iwd_networkmanager_config() {
  local interface=$1
  local destination=$2
  local temporary

  install -dm755 "$(dirname -- "$destination")"
  temporary=$(mktemp "${destination}.XXXXXX")

  if ! {
    iwd_networkmanager_config "$interface" > "$temporary"
    chmod 0644 "$temporary"
    chown root:root "$temporary"
    mv -f -- "$temporary" "$destination"
  }; then
    rm -f -- "$temporary"
    return 1
  fi
}
