#!/usr/bin/env bash
set -euo pipefail

configure_wayland_desktop() {
  local profile=${1:-developer}
  local repo_dir=${2:-/opt/arch-linux-config}
  local environment_source

  log_info "Configuring Wayland desktop"

  if ! id -u greeter >/dev/null 2>&1; then
    useradd -M -r -s /usr/bin/nologin greeter
  fi
  usermod -aG video,input greeter
  install -dm755 -o greeter -g greeter /var/cache/tuigreet

  [[ -f "$repo_dir/greetd/vtrgb" ]] || die "Missing greetd console palette: $repo_dir/greetd/vtrgb"
  [[ -f "$repo_dir/greetd/greetd-vtrgb.conf" ]] || die "Missing greetd systemd drop-in: $repo_dir/greetd/greetd-vtrgb.conf"
  [[ -f "$repo_dir/greetd/vconsole.conf" ]] || die "Missing greetd console configuration: $repo_dir/greetd/vconsole.conf"
  [[ -f "$repo_dir/greetd/config.toml" ]] || die "Missing greetd configuration: $repo_dir/greetd/config.toml"
  [[ -f "$repo_dir/greetd/environments" ]] || die "Missing greetd environment list: $repo_dir/greetd/environments"
  [[ -f "$repo_dir/greetd/archcfg-xsession-wrapper" ]] || die "Missing greetd X11 session wrapper"
  [[ -f "$repo_dir/greetd/archcfg-wayland-session-wrapper" ]] || die "Missing greetd Wayland session wrapper"
  [[ -f "$repo_dir/modules-load.d/nvidia-utils.conf" ]] || die "Missing NVIDIA modules-load override"

  case "$profile" in
    virtualbox)
      environment_source="$repo_dir/wayland/environment.virtualbox"
      ;;
    desktop | developer)
      environment_source="$repo_dir/wayland/environment.desktop"
      ;;
    *)
      die "Desktop configuration is unavailable for profile: $profile"
      ;;
  esac
  [[ -f "$environment_source" ]] || die "Missing desktop environment configuration: $environment_source"

  install -Dm644 "$repo_dir/greetd/vtrgb" /etc/vtrgb
  install -Dm644 "$repo_dir/greetd/greetd-vtrgb.conf" /etc/systemd/system/greetd.service.d/10-vtrgb.conf
  install -Dm644 "$repo_dir/greetd/vconsole.conf" /etc/vconsole.conf
  install -Dm644 "$repo_dir/greetd/config.toml" /etc/greetd/config.toml
  install -Dm644 "$repo_dir/greetd/environments" /etc/greetd/environments
  install -Dm755 "$repo_dir/greetd/archcfg-xsession-wrapper" /usr/local/libexec/archcfg-xsession-wrapper
  install -Dm755 "$repo_dir/greetd/archcfg-wayland-session-wrapper" /usr/local/libexec/archcfg-wayland-session-wrapper
  install -Dm644 "$environment_source" /etc/environment

  if ! lspci -nn | grep -qi nvidia; then
    install -Dm644 "$repo_dir/modules-load.d/nvidia-utils.conf" /etc/modules-load.d/nvidia-utils.conf
  fi
  log_info "Rebuilding initramfs with greeter console font"
  mkinitcpio -P

  rm -f /etc/greetd/regreet.toml
}
