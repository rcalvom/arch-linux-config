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
  [[ -f "$REPO_DIR/greetd/config.toml" ]] || die "Missing greetd configuration"
  [[ -f "$REPO_DIR/greetd/archcfg-xsession-wrapper" ]] || die "Missing greetd X11 session wrapper"
  [[ -f "$REPO_DIR/greetd/archcfg-wayland-session-wrapper" ]] || die "Missing greetd Wayland session wrapper"

  log_info "Installing quiet X11 and Wayland session wrappers"
  install -Dm755 "$REPO_DIR/greetd/archcfg-xsession-wrapper" /usr/local/libexec/archcfg-xsession-wrapper
  install -Dm755 "$REPO_DIR/greetd/archcfg-wayland-session-wrapper" /usr/local/libexec/archcfg-wayland-session-wrapper
  install -Dm644 "$REPO_DIR/greetd/config.toml" /etc/greetd/config.toml
  log_info "The wrappers will be used the next time greetd starts"
}

main "$@"
