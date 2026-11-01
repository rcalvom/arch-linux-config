#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/installed" "$tmp/live" "$tmp/user"
die() { printf '%s\n' "$*" >&2; exit 1; }
log_info() { :; }
log_warn() { :; }
# Installation logic is exercised without ownership changes or host services.
chown() { :; }
systemctl() { die 'Unexpected service operation'; }
sudo() { die 'Unexpected privilege escalation'; }
pacman() { die 'Unexpected package operation'; }
# shellcheck source=scripts/dotfiles.sh
source "$repo/scripts/dotfiles.sh"
user_home_dir() { printf '%s\n' "$tmp/installed"; }
install_wayland_dotfiles "$repo" "$(id -un)"
bash "$repo/scripts/verify-dotfiles.sh" --repo "$repo" --home "$tmp/installed" > "$tmp/verify-installed"

# shellcheck source=live/airootfs/usr/local/bin/archcfg-live-session
source "$repo/live/airootfs/usr/local/bin/archcfg-live-session"
REPO_DIR=$repo
LIVE_HOME="$tmp/live"
initialize_live_browser_profile() { :; }
create_xdg_user_dirs() { :; }
install_live_configs
[[ -f "$LIVE_HOME/.local/bin/hypr-share-picker" ]] || die 'Live picker missing'
[[ -f "$LIVE_HOME/.config/systemd/user/waybar.service" ]] || die 'Live waybar unit missing'
[[ ! -e "$LIVE_HOME/.config/systemd/user/timers.target.wants/archcfg-calcurse-google-refresh.timer" ]] || die 'Live calendar enabled without credentials'
[[ -L "$LIVE_HOME/.config/systemd/user/timers.target.wants/hyprsunset-day.timer" ]] || die 'Live sunset timer missing'

HOME="$tmp/user" bash "$repo/apply-config.sh" --module all --apply > "$tmp/apply-user"
bash "$repo/scripts/verify-dotfiles.sh" --repo "$repo" --home "$tmp/user" --context user > "$tmp/verify-user"
[[ ! -e "$tmp/user/.config/systemd/user/timers.target.wants" ]] || die 'User apply enabled timers'

# Compare all mapped desktop files across deployment contexts, except the live overlay.
while IFS= read -r -d '' file; do
  relative=${file#"$tmp/user"/}
  [[ "$relative" != .local/state/* ]] || continue
  cmp "$file" "$tmp/installed/$relative"
  [[ "$relative" != .config/hypr/hyprland.lua ]] || continue
  cmp "$file" "$tmp/live/$relative"
done < <(find "$tmp/user" -type f -print0)
install_wayland_dotfiles "$repo" "$(id -un)" ricardo
cmp "$repo/hardware/ricardo/display-profiles.json" "$tmp/installed/.config/archcfg/display-profiles.json"
cmp "$repo/hardware/ricardo/hardware.lua" "$tmp/installed/.config/archcfg/hardware.lua"
printf 'PASS: installed/live/user mappings, verification and timer exceptions\n'
