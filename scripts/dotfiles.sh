#!/usr/bin/env bash
set -euo pipefail

user_home_dir() {
  local username=$1
  local home_dir

  home_dir=$(getent passwd "$username" | cut -d: -f6)
  [[ -n "$home_dir" ]] || die "Cannot determine home directory for $username"
  printf '%s\n' "$home_dir"
}

install_user_file() {
  local src=$1
  local dest=$2
  local owner=$3
  local mode=$4

  [[ -f "$src" ]] || die "Missing dotfile source: $src"
  install -Dm"$mode" "$src" "$dest"
  chown "$owner:$owner" "$dest"
}

install_user_tree() {
  local src_dir=$1
  local dest_dir=$2
  local owner=$3
  local mode=$4
  local file
  local relative

  [[ -d "$src_dir" ]] || die "Missing dotfile source directory: $src_dir"
  src_dir=$(cd -- "$src_dir" && pwd -P)

  while IFS= read -r -d '' file; do
    [[ "$(basename -- "$file")" == "files.conf" ]] && continue
    relative=${file#"$src_dir"/}
    install -Dm"$mode" "$file" "$dest_dir/$relative"
  done < <(find "$src_dir" -name __pycache__ -prune -o -type f ! -name '*.py[co]' -print0)

  chown -R "$owner:$owner" "$dest_dir"
}

apply_user_package_config_manifest() {
  local manifest=$1
  local username=$2
  local home_dir=$3
  local package_dir
  local kind
  local mode
  local source
  local destination

  package_dir=$(cd -- "$(dirname -- "$manifest")" && pwd -P)

  while IFS='|' read -r kind mode source destination || [[ -n "$kind" ]]; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    [[ -n "$mode" && -n "$source" && -n "$destination" ]] || die "Invalid config manifest line in $manifest"

    case "$kind" in
      user_file)
        install_user_file "$package_dir/$source" "$home_dir/$destination" "$username" "$mode"
        ;;
      user_tree)
        install_user_tree "$package_dir/$source" "$home_dir/$destination" "$username" "$mode"
        ;;
      root_file | root_tree)
        log_warn "Ignoring root config entry in user install phase: $manifest"
        ;;
      *)
        die "Unknown config manifest kind '$kind' in $manifest"
        ;;
    esac
  done < "$manifest"
}

install_package_dotfiles() {
  local repo_dir=$1
  local username=$2
  local home_dir=$3
  local manifests=("$repo_dir"/packages/*/files.conf)
  local manifest

  [[ -e "${manifests[0]}" ]] || return 0

  log_info "Installing package config manifests for $username"
  for manifest in "${manifests[@]}"; do
    apply_user_package_config_manifest "$manifest" "$username" "$home_dir"
  done
}

install_wayland_dotfiles() {
  local repo_dir=$1
  local username=$2
  local hardware_profile=${3:-none}
  local home_dir

  home_dir=$(user_home_dir "$username")
  log_info "Installing Wayland dotfiles for $username"

  apply_user_package_config_manifest "$repo_dir/wayland/files.conf" "$username" "$home_dir"
  install_package_dotfiles "$repo_dir" "$username" "$home_dir"
  if [[ "$hardware_profile" != none ]]; then
    [[ "$hardware_profile" == ricardo ]] || die "Invalid hardware profile: $hardware_profile"
    apply_user_package_config_manifest "$repo_dir/hardware/$hardware_profile/files.conf" "$username" "$home_dir"
  fi

  install -dm755 "$home_dir/.config/systemd/user/timers.target.wants"
  ln -sfn ../hyprsunset-day.timer "$home_dir/.config/systemd/user/timers.target.wants/hyprsunset-day.timer"
  ln -sfn ../hyprsunset-night.timer "$home_dir/.config/systemd/user/timers.target.wants/hyprsunset-night.timer"
  ln -sfn ../archcfg-calcurse-google-refresh.timer "$home_dir/.config/systemd/user/timers.target.wants/archcfg-calcurse-google-refresh.timer"
  chown -R "$username:$username" "$home_dir/.config" "$home_dir/.local" "$home_dir/Pictures"
}
