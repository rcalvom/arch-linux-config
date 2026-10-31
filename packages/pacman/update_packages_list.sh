#!/usr/bin/env bash
set -euo pipefail

inventory_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Query both sets before replacing either inventory. Foreign does not imply AUR.
foreign=$(pacman -Qqem)
official=$(pacman -Qqen)
printf '%s\n' \
  '# Inventory only: explicitly installed foreign packages, not verified AUR sources.' \
  '# Installer selections are maintained separately in packages/aur.txt and packages/recipes/.' \
  "$foreign" > "$inventory_dir/arch-aur-packages.txt"
printf '%s\n' \
  '# Inventory only: explicitly installed official packages; not an installer profile.' \
  "$official" > "$inventory_dir/arch-official-packages.txt"
