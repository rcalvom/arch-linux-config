if [[ -f /etc/motd ]]; then
  cat /etc/motd
fi

if [[ -d /opt/arch-linux-config ]]; then
  cd /opt/arch-linux-config || true
fi
