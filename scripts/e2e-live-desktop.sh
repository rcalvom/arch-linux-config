#!/usr/bin/env bash
set -euo pipefail

[[ $(systemd-detect-virt) == oracle && $USER == live ]] || exit 1
instances=$(hyprctl -j instances)
[[ $(jq length <<< "$instances") == 1 ]]
export HYPRLAND_INSTANCE_SIGNATURE
export WAYLAND_DISPLAY
HYPRLAND_INSTANCE_SIGNATURE=$(jq -r '.[0].instance' <<< "$instances")
WAYLAND_DISPLAY=$(jq -r '.[0].wl_socket' <<< "$instances")
hyprctl -j monitors | jq -e 'length > 0 and all(.[]; .width > 0 and .height > 0)'
# Hyprland 0.56 reports an empty error string rather than an empty array.
hyprctl -j configerrors | jq -e 'type == "array" and all(.[]; . == "")'
[[ $(systemctl --user show waybar.service -p FragmentPath --value) == "$HOME/.config/systemd/user/waybar.service" ]]
systemctl --user is-active --quiet waybar.service
test -x "$HOME/.local/bin/hypr-share-picker"
test -f "$HOME/.config/rofi/share-picker.rasi"
test -f "$HOME/.config/rofi/share-picker-icons/screen.svg"
# Exercise the actual picker and compositor; cancel only our own process group.
setsid "$HOME/.local/bin/hypr-share-picker" > /tmp/archcfg-picker-result &
picker=$!
trap 'kill -- -"$picker" 2>/dev/null || true; wait "$picker" 2>/dev/null || true' EXIT
for ((attempt=0; attempt<30; attempt++)); do
  if pgrep -P "$picker" >/dev/null && hyprctl -j layers | jq -e '.. | objects | select(.namespace? == "rofi")' >/dev/null; then
    printf 'PASS: live monitor IPC, zero config errors, custom Waybar active, real picker layer visible\n'
    exit 0
  fi
  sleep 1
done
printf 'Picker did not create a visible compositor layer\n' >&2
exit 1
