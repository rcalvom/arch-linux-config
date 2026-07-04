if [[ -d /opt/arch-linux-config ]]; then
  cd /opt/arch-linux-config || true
fi

if [[ -z "${WAYLAND_DISPLAY:-}" && "$(tty)" == "/dev/tty1" ]]; then
  /usr/local/bin/archcfg-live-session || {
    printf '\n[WARN] Wayland live session failed; returning to shell.\n' >&2
  }
fi
