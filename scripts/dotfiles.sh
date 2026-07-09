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
  done < <(find "$src_dir" -type f -print0)

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
  local home_dir
  local unit

  home_dir=$(user_home_dir "$username")
  log_info "Installing Wayland dotfiles for $username"

  install_user_file "$repo_dir/wayland/hypr/hyprland.conf" "$home_dir/.config/hypr/hyprland.conf" "$username" 0644
  install_user_file "$repo_dir/wayland/hypr/hyprland.lua" "$home_dir/.config/hypr/hyprland.lua" "$username" 0644
  install_user_file "$repo_dir/wayland/hypr/hyprtoolkit.conf" "$home_dir/.config/hypr/hyprtoolkit.conf" "$username" 0644
  install_user_file "$repo_dir/wayland/hypr/hyprlock.conf" "$home_dir/.config/hypr/hyprlock.conf" "$username" 0644
  install_user_file "$repo_dir/wayland/hypr/hyprpaper.conf" "$home_dir/.config/hypr/hyprpaper.conf" "$username" 0644
  install_user_file "$repo_dir/wayland/wallpapers/wallpaper.png" "$home_dir/Pictures/wallpaper2.png" "$username" 0644
  install_user_file "$repo_dir/wayland/waybar/config.jsonc" "$home_dir/.config/waybar/config.jsonc" "$username" 0644
  install_user_file "$repo_dir/wayland/waybar/style.css" "$home_dir/.config/waybar/style.css" "$username" 0644
  install_user_file "$repo_dir/wayland/rofi/config.rasi" "$home_dir/.config/rofi/config.rasi" "$username" 0644
  install_user_file "$repo_dir/wayland/wofi/config" "$home_dir/.config/wofi/config" "$username" 0644
  install_user_file "$repo_dir/wayland/wofi/style.css" "$home_dir/.config/wofi/style.css" "$username" 0644
  install_user_file "$repo_dir/wayland/mako/config" "$home_dir/.config/mako/config" "$username" 0644
  install_user_file "$repo_dir/wayland/fontconfig/conf.d/99-ubuntu-fallback.conf" "$home_dir/.config/fontconfig/conf.d/99-ubuntu-fallback.conf" "$username" 0644
  install_package_dotfiles "$repo_dir" "$username" "$home_dir"
  install_user_file "$repo_dir/wayland/bin/hyprsunset-set" "$home_dir/.local/bin/hyprsunset-set" "$username" 0755
  install_user_file "$repo_dir/wayland/bin/hyprsunset-apply-current" "$home_dir/.local/bin/hyprsunset-apply-current" "$username" 0755

  for unit in hyprsunset-day.service hyprsunset-day.timer hyprsunset-night.service hyprsunset-night.timer; do
    install_user_file "$repo_dir/wayland/systemd/user/$unit" "$home_dir/.config/systemd/user/$unit" "$username" 0644
  done

  install -dm755 "$home_dir/.config/systemd/user/timers.target.wants"
  ln -sfn ../hyprsunset-day.timer "$home_dir/.config/systemd/user/timers.target.wants/hyprsunset-day.timer"
  ln -sfn ../hyprsunset-night.timer "$home_dir/.config/systemd/user/timers.target.wants/hyprsunset-night.timer"
  chown -R "$username:$username" "$home_dir/.config" "$home_dir/.local" "$home_dir/Pictures"
}
