#!/usr/bin/env bash
set -euo pipefail

configure_wayland_desktop() {
  log_info "Configuring Wayland desktop"

  if ! id -u greeter >/dev/null 2>&1; then
    useradd -M -r -s /usr/bin/nologin greeter
  fi
  usermod -aG video,input greeter

  install -dm755 /etc/greetd
  cat > /etc/greetd/config.toml <<'GREETD'
[terminal]
vt = 1

[default_session]
command = "cage -s -- regreet"
user = "greeter"
GREETD

  cat > /etc/greetd/environments <<'ENVIRONMENTS'
Hyprland
bash
ENVIRONMENTS

  cat > /etc/greetd/regreet.toml <<'REGREET'
[GTK]
application_prefer_dark_theme = true
font_name = "Ubuntu 11"
theme_name = "Adwaita-dark"

[commands]
reboot = ["systemctl", "reboot"]
poweroff = ["systemctl", "poweroff"]
REGREET

  install -Dm644 /dev/stdin /etc/environment <<'ENVIRONMENT'
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland;xcb
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
ENVIRONMENT
}
