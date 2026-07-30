#!/usr/bin/env bash
set -euo pipefail

systemd-sysusers /usr/lib/sysusers.d/greetd.conf
install -d -o greeter -g greeter -m 0755 /var/lib/greetd

getent group live >/dev/null || groupadd --gid 1000 live
if ! id -u live >/dev/null 2>&1; then
  useradd --uid 1000 --gid live --groups wheel,audio,video,input --create-home \
    --shell /usr/bin/zsh --comment "Live User" live
fi

usermod --append --groups wheel,audio,video,input live
printf '%s\n' 'live:live' | chpasswd
