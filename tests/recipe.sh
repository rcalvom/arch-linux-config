#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$repo/postinstall.sh"
parse_postinstall_args --recipe ricardo --gpu software --aur --defer-manual --dry-run
[[ "$RECIPE" == ricardo && "$HARDWARE_PROFILE" == none ]]
plan=$(print_package_plan "$repo")
for package in docker-buildx openai-codex python-openai-whisper python-huggingface-hub aws-cli-v2 texlive-fontsextra virtualbox-host-dkms pipewire-alsa chafa python-openpyxl python-pillow uv; do
  grep -Fx "official $package" <<< "$plan" >/dev/null
done
for package in rnote khal imv lazydocker ruby python-pipx lua51 lua51-luarocks jupyterlab pamixer wireless_tools gutenprint foomatic-db hyprlauncher; do
  if grep -Fx "official $package" <<< "$plan" >/dev/null; then die "Excluded selection: $package"; fi
done
[[ $(grep -c '^aur ' <<< "$plan") == 13 && $(grep -c '^manual ' <<< "$plan") == 3 ]]
for package in opencode-notifier slack-desktop xdg-desktop-portal-termfilechooser-hunkyburrito-git; do
  if grep -q "^aur $package " <<< "$plan"; then die "Excluded or deferred AUR selection: $package"; fi
done
for profile in developer virtualbox; do
  bash "$repo/install.sh" --profile "$profile" --recipe ricardo --dry-run >/dev/null
done
for args in '--recipe unknown' '--recipe ricardo --profile minimal' '--recipe ricardo --extra amd' '--gpu amd' '--defer-manual' '--recipe ricardo --gpu nvidia'; do
  read -r -a argv <<< "$args"
  if bash "$repo/install.sh" "${argv[@]}" --dry-run >/dev/null 2>&1; then die "Accepted invalid arguments: $args"; fi
done
for gpu in amd intel software; do
  selection=$(recipe_gpu_packages "$gpu")
  [[ "$selection" == *lib32-mesa* ]]
done
[[ $(recipe_gpu_packages amd) == *vulkan-radeon* ]]
[[ $(recipe_gpu_packages intel) == *intel-media-driver* ]]
systemd-detect-virt() { return 0; }
[[ $(recipe_gpu_packages auto) == *vulkan-swrast* ]]
DEFER_MANUAL=0
if (validate_recipe_installation) >/dev/null 2>&1; then die 'Manual AUR packages were silently omitted'; fi
DEFER_MANUAL=1
validate_recipe_installation
source "$repo/lib/install.sh"
arch-chroot() { printf '%s\n' "$*"; }
forwarded=$(run_postinstall /mnt /opt/arch-linux-config developer fixture fixture UTC 1 none none)
[[ "$forwarded" == *'--recipe ricardo --gpu software --defer-manual'* ]]
# Mock target transaction: neither pacman nor system configuration may run here.
calls=()
pacman() { calls+=("$*"); }
enable_recipe_multilib() { calls+=(multilib); }
install_packages_for_profile developer "$repo"
[[ "${calls[*]}" == *multilib* && "${calls[*]}" == *lib32-vulkan-swrast* ]]
[[ " ${calls[*]} " != *' rnote '* && " ${calls[*]} " != *' lazydocker '* ]]
printf 'PASS: recipe selection, exclusions, validation, GPU and chroot propagation\n'
