#!/usr/bin/env bash
set -euo pipefail

configure_wayland_desktop() {
  log_info "Configuring Wayland desktop"

  if ! id -u greeter >/dev/null 2>&1; then
    useradd -M -r -s /usr/bin/nologin greeter
  fi

  install -dm755 /etc/greetd
  cat > /etc/greetd/config.toml <<'GREETD'
[terminal]
vt = 1

[default_session]
command = "agreety --cmd Hyprland"
user = "greeter"
GREETD

  install -Dm644 /dev/stdin /etc/environment <<'ENVIRONMENT'
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland;xcb
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
ENVIRONMENT
}
