#!/usr/bin/env bash
set -euo pipefail

theme_dir="/usr/share/grub/themes/arch"
grub_defaults="/etc/default/grub"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo rm -rf "$theme_dir"
sudo cp -r "$script_dir" "$theme_dir"

if sudo grep -q '^GRUB_THEME=' "$grub_defaults"; then
  sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${theme_dir}/theme.txt\"|" "$grub_defaults"
else
  echo "GRUB_THEME=\"${theme_dir}/theme.txt\"" | sudo tee -a "$grub_defaults" >/dev/null
fi
