#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

require_file() {
  [[ -f "$1" ]] || die "Missing required file: $1"
}

main() {
  require_root
  require_file "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.service"
  require_file "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.path"
  require_file "$REPO_DIR/network/bin/archcfg-reset-resolved-if-stub"

  log_info "Installing the resolver reset watcher"
  install -Dm644 "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.service" /etc/systemd/system/archcfg-reset-resolved-if-stub.service
  install -Dm644 "$REPO_DIR/network/systemd/archcfg-reset-resolved-if-stub.path" /etc/systemd/system/archcfg-reset-resolved-if-stub.path
  install -Dm755 "$REPO_DIR/network/bin/archcfg-reset-resolved-if-stub" /usr/local/libexec/archcfg-reset-resolved-if-stub

  systemctl daemon-reload
  systemctl enable --now archcfg-reset-resolved-if-stub.path
  log_info "The watcher will reset stale VPN DNS after Cisco restores the resolver stub"
}

main "$@"
