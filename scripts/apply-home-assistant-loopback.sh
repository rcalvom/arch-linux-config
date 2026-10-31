#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

require_regular_file() {
  [[ -f "$1" && ! -L "$1" ]] || die "Required regular file is missing: $1"
}

main() {
  case "${1:-}" in
    --help | -h)
      printf '%s\n' 'Usage: sudo bash scripts/apply-home-assistant-loopback.sh'
      printf '%s\n' 'Deploy the Home Assistant loopback-only firewall policy.'
      return
      ;;
  esac
  (($# == 0)) || die "Unknown argument: $1"

  require_root
  command -v nft >/dev/null 2>&1 || die "nft is required"
  require_regular_file "$REPO_DIR/home-assistant/nftables/home-assistant-loopback.nft"
  require_regular_file "$REPO_DIR/home-assistant/systemd/home-assistant-loopback.service"

  if systemctl is-active --quiet home-assistant-loopback.service; then
    die "home-assistant-loopback.service is already active; review and apply policy changes in a separate approved maintenance window"
  fi

  install -Dm644 "$REPO_DIR/home-assistant/nftables/home-assistant-loopback.nft" /etc/nftables.d/home-assistant-loopback.nft
  install -Dm644 "$REPO_DIR/home-assistant/systemd/home-assistant-loopback.service" /etc/systemd/system/home-assistant-loopback.service

  systemctl daemon-reload
  systemctl enable --now home-assistant-loopback.service
  systemctl is-enabled --quiet home-assistant-loopback.service || die "Firewall policy was not enabled"
  systemctl is-active --quiet home-assistant-loopback.service || die "Firewall policy is not active"
  nft list table inet home_assistant_loopback >/dev/null || die "Firewall table is missing"

  log_info "Home Assistant TCP/8123 is restricted to loopback"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
