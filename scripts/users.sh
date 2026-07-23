#!/usr/bin/env bash
set -euo pipefail

configure_initial_user() {
  local username=$1
  local profile=${2:-}
  local password_file="/root/.archcfg-user-password"
  local home_dir
  local zsh_path
  local supplementary_groups=wheel,video,audio,storage,input
  local user_exists=0

  log_info "Configuring user: $username"

  if id -u "$username" >/dev/null 2>&1; then
    user_exists=1
  fi

  # Docker membership is root-equivalent, so only developer profiles receive it.
  if [[ "$profile" == developer || "$profile" == virtualbox ]] && getent group docker >/dev/null; then
    supplementary_groups+=",docker"
  elif (( user_exists )) && getent group docker >/dev/null && [[ " $(id -nG "$username") " == *" docker "* ]]; then
    gpasswd -d "$username" docker
  fi

  if (( user_exists )); then
    usermod -aG "$supplementary_groups" "$username"
  else
    useradd -m -G "$supplementary_groups" "$username"
  fi

  zsh_path=$(command -v zsh || true)
  if [[ -n "$zsh_path" ]]; then
    chsh -s "$zsh_path" "$username"
  fi

  home_dir=$(getent passwd "$username" | cut -d: -f6)
  if [[ -n "$home_dir" && -x /usr/bin/xdg-user-dirs-update ]]; then
    runuser -u "$username" -- env HOME="$home_dir" XDG_CONFIG_HOME="$home_dir/.config" xdg-user-dirs-update
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
