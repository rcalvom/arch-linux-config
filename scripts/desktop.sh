#!/usr/bin/env bash
set -euo pipefail

configure_wayland_desktop() {
  local profile=${1:-developer}
  local repo_dir=${2:-/opt/arch-linux-config}
  local greeter_theme="border=lightblue;text=white;prompt=cyan;time=lightblue;action=blue;button=lightcyan;container=black;input=lightcyan;greet=lightblue;title=lightcyan"
  local greeter_command="tuigreet --time --time-format '%d/%m/%Y - %I:%M %p' --greeting 'Arch Linux' --theme '$greeter_theme' --width 72 --window-padding 2 --container-padding 2 --prompt-padding 1 --greet-align center --remember --remember-session --asterisks --user-menu --user-menu-min-uid 1000 --sessions /usr/share/wayland-sessions --xsessions /usr/share/xsessions --cmd Hyprland"

  log_info "Configuring Wayland desktop"

  if ! id -u greeter >/dev/null 2>&1; then
    useradd -M -r -s /usr/bin/nologin greeter
  fi
  usermod -aG video,input greeter
  install -dm755 -o greeter -g greeter /var/cache/tuigreet

  [[ -f "$repo_dir/greetd/vtrgb" ]] || die "Missing greetd console palette: $repo_dir/greetd/vtrgb"
  [[ -f "$repo_dir/greetd/greetd-vtrgb.conf" ]] || die "Missing greetd systemd drop-in: $repo_dir/greetd/greetd-vtrgb.conf"
  install -Dm644 "$repo_dir/greetd/vtrgb" /etc/vtrgb
  install -Dm644 "$repo_dir/greetd/greetd-vtrgb.conf" /etc/systemd/system/greetd.service.d/10-vtrgb.conf

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

    if [[ "$profile" == "virtualbox" ]]; then
      printf 'WLR_RENDERER_ALLOW_SOFTWARE=1\n'
      printf 'LIBGL_ALWAYS_SOFTWARE=1\n'
      printf 'GSK_RENDERER=cairo\n'
    fi
  } > /etc/environment
}
