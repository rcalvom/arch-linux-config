#!/usr/bin/env bash
set -euo pipefail

enable_service_if_present() {
  local service=$1

  if [[ -f "/usr/lib/systemd/system/$service" || -f "/etc/systemd/system/$service" ]]; then
    log_info "Enabling $service"
    systemctl enable "$service"
  fi
}

disable_service_if_present() {
  local service=$1

  if [[ -f "/usr/lib/systemd/system/$service" || -f "/etc/systemd/system/$service" ]]; then
    log_info "Disabling $service"
    systemctl disable "$service"
  fi
}

enable_user_service_globally_if_present() {
  local service=$1

  if [[ -f "/usr/lib/systemd/user/$service" || -f "/etc/systemd/user/$service" ]]; then
    log_info "Enabling user service globally: $service"
    systemctl --global enable "$service"
  fi
}

configure_iwd_networking() {
  local profile=$1
  local repo_dir=$2

  case "$profile" in
    desktop | developer | virtualbox)
      ;;
    *)
      return 0
      ;;
  esac

  [[ -f "$repo_dir/network/NetworkManager/10-iwd-wlan0.conf" ]] || die "Missing NetworkManager IWD configuration"
  [[ -f "$repo_dir/network/iwd/main.conf" ]] || die "Missing IWD configuration"
  [[ -f "$repo_dir/network/systemd/host-network-online.service" ]] || die "Missing network-online service"
  [[ -f "$repo_dir/network/systemd/archcfg-reset-resolved-if-stub.service" ]] || die "Missing resolver reset service"
  [[ -f "$repo_dir/network/systemd/archcfg-reset-resolved-if-stub.path" ]] || die "Missing resolver reset path"
  [[ -f "$repo_dir/network/bin/archcfg-wait-network-online" ]] || die "Missing network-online helper"
  [[ -f "$repo_dir/network/bin/archcfg-reset-resolved-if-stub" ]] || die "Missing resolver reset helper"

  log_info "Configuring IWD-owned Wi-Fi"
  install -Dm644 "$repo_dir/network/NetworkManager/10-iwd-wlan0.conf" /etc/NetworkManager/conf.d/10-iwd-wlan0.conf
  install -Dm644 "$repo_dir/network/iwd/main.conf" /etc/iwd/main.conf
  install -Dm644 "$repo_dir/network/systemd/host-network-online.service" /etc/systemd/system/host-network-online.service
  install -Dm644 "$repo_dir/network/systemd/archcfg-reset-resolved-if-stub.service" /etc/systemd/system/archcfg-reset-resolved-if-stub.service
  install -Dm644 "$repo_dir/network/systemd/archcfg-reset-resolved-if-stub.path" /etc/systemd/system/archcfg-reset-resolved-if-stub.path
  install -Dm755 "$repo_dir/network/bin/archcfg-wait-network-online" /usr/local/libexec/archcfg-wait-network-online
  install -Dm755 "$repo_dir/network/bin/archcfg-reset-resolved-if-stub" /usr/local/libexec/archcfg-reset-resolved-if-stub
  ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  disable_service_if_present NetworkManager-wait-online.service
  enable_service_if_present iwd.service
  enable_service_if_present systemd-resolved.service
  enable_service_if_present host-network-online.service
  enable_service_if_present archcfg-reset-resolved-if-stub.path
}

configure_charge_limits() {
  local repo_dir=$1

  [[ -f "$repo_dir/power/charge-limit.conf" ]] || die "Missing charge limit configuration"
  [[ -f "$repo_dir/power/bin/archcfg-charge-limit" ]] || die "Missing charge limit helper"
  [[ -f "$repo_dir/power/systemd/archcfg-charge-limit.service" ]] || die "Missing charge limit service"
  [[ -f "$repo_dir/power/udev/99-archcfg-charge-limit.rules" ]] || die "Missing charge limit udev rule"

  log_info "Installing dock-aware charge limit service"
  install -Dm644 "$repo_dir/power/charge-limit.conf" /etc/archcfg/charge-limit.conf
  install -Dm755 "$repo_dir/power/bin/archcfg-charge-limit" /usr/local/libexec/archcfg-charge-limit
  install -Dm644 "$repo_dir/power/systemd/archcfg-charge-limit.service" /etc/systemd/system/archcfg-charge-limit.service
  install -Dm644 "$repo_dir/power/udev/99-archcfg-charge-limit.rules" /etc/udev/rules.d/99-archcfg-charge-limit.rules

  disable_service_if_present battery-thresholds.timer
  systemctl daemon-reload
  enable_service_if_present archcfg-charge-limit.service
}

enable_core_services() {
  local profile=$1

  enable_service_if_present NetworkManager.service
  enable_service_if_present bluetooth.service
  enable_user_service_globally_if_present pipewire.service
  enable_user_service_globally_if_present pipewire-pulse.service
  enable_user_service_globally_if_present wireplumber.service

  case "$profile" in
    desktop | developer | virtualbox)
      enable_service_if_present greetd.service
      ;;
  esac

  if [[ "$profile" == "virtualbox" ]]; then
    enable_service_if_present vboxservice.service
  fi
}
