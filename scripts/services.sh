#!/usr/bin/env bash
set -euo pipefail

enable_service_if_present() {
  local service=$1

  if [[ -f "/usr/lib/systemd/system/$service" || -f "/etc/systemd/system/$service" ]]; then
    log_info "Enabling $service"
    systemctl enable "$service"
  fi
}

enable_user_service_globally_if_present() {
  local service=$1

  if [[ -f "/usr/lib/systemd/user/$service" || -f "/etc/systemd/user/$service" ]]; then
    log_info "Enabling user service globally: $service"
    systemctl --global enable "$service"
  fi
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
