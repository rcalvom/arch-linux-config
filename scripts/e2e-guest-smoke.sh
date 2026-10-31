#!/usr/bin/env bash
set -euo pipefail

MODE=
USERNAME=archcfg-e2e

usage() {
  cat <<'USAGE'
Usage: e2e-guest-smoke.sh --mode live|installed [--username NAME]

Runs deterministic runtime smoke checks in an Arch Linux live environment or
an installed VirtualBox guest.
USAGE
}

die() {
  printf 'smoke test failure: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

check_network_stack() {
  ip -4 route show default | grep -q '^default ' || die 'missing IPv4 default route'
  resolvectl --cache=no --type=A query archlinux.org >/dev/null
  wget --spider -q -T 10 https://archlinux.org/

  systemctl is-active --quiet iwd.service
  systemctl is-active --quiet systemd-networkd.service
  systemctl is-active --quiet systemd-resolved.service
  systemctl is-active --quiet host-network-online.service
  ! systemctl is-active --quiet NetworkManager.service
  ! systemctl is-enabled --quiet NetworkManager.service
  ! systemctl is-enabled --quiet systemd-networkd-wait-online.service
  ! pacman -Qq networkmanager >/dev/null 2>&1
  test "$(readlink -f /etc/resolv.conf)" = /run/systemd/resolve/stub-resolv.conf
}

check_desktop_commands() {
  local command

  for command in alacritty firefox Hyprland impala nvim rofi waybar yazi; do
    require_command "$command"
  done
}

check_live() {
  local command

  for command in archcfg-install git iwctl resolvectl wget; do
    require_command "$command"
  done
  archcfg-install --help >/dev/null
  check_network_stack
  check_desktop_commands
  systemctl is-active --quiet greetd.service
  runuser -u live -- env -u SUDO_USER XDG_RUNTIME_DIR=/run/user/1000 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    bash /opt/arch-linux-config/scripts/e2e-live-desktop.sh
}

check_installed() {
  local home_directory
  local command

  home_directory=$(getent passwd "$USERNAME" | cut -d: -f6)
  [[ -n "$home_directory" && -d "$home_directory" ]] || die "missing home directory for $USERNAME"

  for command in docker git nvim opencode; do
    require_command "$command"
  done
  docker --version >/dev/null
  nvim --clean --headless '+quitall'
  opencode --version >/dev/null
  check_network_stack
  check_desktop_commands

  test -d /sys/firmware/efi
  findmnt -no FSTYPE /boot | grep -qx vfat
  systemctl is-active --quiet docker.service
  systemctl is-active --quiet greetd.service
  systemctl is-active --quiet vboxservice.service
  test -f "$home_directory/.config/nvim/init.lua"
  test -f "$home_directory/.config/hypr/hyprland.lua"
  test -f "$home_directory/.config/waybar/config.jsonc"
  test -f "$home_directory/.zshrc"
  bash /opt/arch-linux-config/tests/apply-config-integration.sh
  test "$(systemctl --failed --no-legend --plain | wc -l)" = 0
  test "$(systemctl --user --failed --no-legend --plain | wc -l)" = 0
}

while (($#)); do
  case "$1" in
    --mode)
      (($# >= 2)) || die '--mode requires a value'
      MODE=$2
      shift 2
      ;;
    --username)
      (($# >= 2)) || die '--username requires a value'
      USERNAME=$2
      shift 2
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$MODE" in
  live)
    check_live
    ;;
  installed)
    check_installed
    ;;
  *)
    usage >&2
    die '--mode must be live or installed'
    ;;
esac
