#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

main() {
  require_root
  [[ -f "$REPO_DIR/greetd/vconsole.conf" ]] || die "Missing greeter console configuration"

  log_info "Installing the greeter console font"
  install -Dm644 "$REPO_DIR/greetd/vconsole.conf" /etc/vconsole.conf
  log_info "Rebuilding initramfs with the greeter console font"
  mkinitcpio -P
  log_info "Reboot to load the new font in tuigreet"
}

main "$@"
