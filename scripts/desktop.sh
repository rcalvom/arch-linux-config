#!/usr/bin/env bash
set -euo pipefail

configure_wayland_desktop() {
  local profile=${1:-developer}
  local greeter_command="tuigreet --time --remember --asterisks --cmd Hyprland"

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
GREETD
  printf 'command = "%s"\n' "$greeter_command" >> /etc/greetd/config.toml
  cat >> /etc/greetd/config.toml <<'GREETD'
user = "greeter"
GREETD

  cat > /etc/greetd/environments <<'ENVIRONMENTS'
Hyprland
bash
ENVIRONMENTS
  rm -f /etc/greetd/regreet.toml

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
