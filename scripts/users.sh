#!/usr/bin/env bash
set -euo pipefail

configure_initial_user() {
  local username=$1
  local password_file="/root/.archcfg-user-password"

  log_info "Configuring user: $username"

  if id -u "$username" >/dev/null 2>&1; then
    usermod -aG wheel,video,audio,storage,input "$username"
  else
    useradd -m -G wheel,video,audio,storage,input "$username"
  fi

  if [[ -x /bin/zsh ]]; then
    chsh -s /bin/zsh "$username"
  fi

  install -dm755 /etc/sudoers.d
  printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
  chmod 0440 /etc/sudoers.d/10-wheel

  if [[ -f "$password_file" ]]; then
    chpasswd < "$password_file"
    rm -f "$password_file"
  else
    log_warn "No password file found for $username; set it with passwd $username after boot"
  fi
}
