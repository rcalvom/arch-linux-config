#!/usr/bin/env bash
set -euo pipefail

configure_wayland_desktop() {
  local profile=${1:-developer}
  local greeter_command="cage -s -- regreet"

  log_info "Configuring Wayland desktop"

  if [[ "$profile" == "virtualbox" ]]; then
    greeter_command="env WLR_RENDERER_ALLOW_SOFTWARE=1 LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo cage -s -- regreet"
  fi

  if ! id -u greeter >/dev/null 2>&1; then
    useradd -M -r -s /usr/bin/nologin greeter
  fi
  usermod -aG video,input greeter

  install -dm755 /etc/greetd
  cat > /etc/greetd/config.toml <<'GREETD'
[terminal]
vt = 1

[default_session]
GREETD
  printf 'command = "%s"\n' "$greeter_command" >> /etc/greetd/config.toml
  cat >> /etc/greetd/config.toml <<'GREETD'
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

  {
    printf 'MOZ_ENABLE_WAYLAND=1\n'
    printf 'QT_QPA_PLATFORM=wayland;xcb\n'
    printf 'XDG_CURRENT_DESKTOP=Hyprland\n'
    printf 'XDG_SESSION_TYPE=wayland\n'

    if [[ "$profile" == "virtualbox" ]]; then
      printf 'WLR_RENDERER_ALLOW_SOFTWARE=1\n'
      printf 'LIBGL_ALWAYS_SOFTWARE=1\n'
      printf 'GSK_RENDERER=cairo\n'
    fi
  } > /etc/environment
}
