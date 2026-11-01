#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
root="$test_dir/root"
mkdir -p "$root/etc" "$root/usr/bin"
copy() { install -Dm"${3:-644}" "$repo/$1" "$root/$2"; }
copy network/iwd/main.conf etc/iwd/main.conf
copy network/systemd/network/20-wired.network etc/systemd/network/20-wired.network
for unit in host-network-online.service archcfg-reset-resolved-if-stub.service archcfg-reset-resolved-if-stub.path; do
  copy "network/systemd/$unit" "etc/systemd/system/$unit"
done
for helper in archcfg-wait-network-online archcfg-reset-resolved-if-stub; do
  copy "network/bin/$helper" "usr/local/libexec/$helper" 755
done
ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
copy power/charge-limit.conf etc/archcfg/charge-limit.conf
copy power/bin/archcfg-charge-limit usr/local/libexec/archcfg-charge-limit 755
for unit in archcfg-charge-limit.service archcfg-charge-limit.timer; do
  copy "power/systemd/$unit" "etc/systemd/system/$unit"
done
copy power/udev/99-archcfg-charge-limit.rules etc/udev/rules.d/99-archcfg-charge-limit.rules
copy power/upower/90-archcfg-critical-battery.conf etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf
install -m755 /dev/null "$root/usr/bin/upower"
copy greetd/vtrgb etc/vtrgb
copy greetd/greetd-vtrgb.conf etc/systemd/system/greetd.service.d/10-vtrgb.conf
copy greetd/vconsole.conf etc/vconsole.conf
copy greetd/config.toml etc/greetd/config.toml
copy greetd/environments etc/greetd/environments
copy greetd/archcfg-xsession-wrapper usr/local/libexec/archcfg-xsession-wrapper 755
copy greetd/archcfg-wayland-session-wrapper usr/local/libexec/archcfg-wayland-session-wrapper 755
copy wayland/environment.desktop etc/environment
systemctl() {
  local unit=${!#}
  [[ "$*" == *is-enabled* ]] || return 99
  case "$unit" in
    NetworkManager.service|NetworkManager-wait-online.service|systemd-networkd-wait-online.service) return 1 ;;
    pipewire.service|pipewire-pulse.service) [[ "${AUDIO_MODE:-socket}" == service ]]; return ;;
    pipewire.socket|pipewire-pulse.socket) [[ "${AUDIO_MODE:-socket}" == socket ]]; return ;;
  esac
  [[ "$unit" != "${DISABLED_UNIT:-}" ]]
}
export -f systemctl
verify() {
  bash "$repo/scripts/verify-system-config.sh" --root "$root" --profile desktop --grub-profile none --diff > "$test_dir/output"
}
verify
AUDIO_MODE=service verify
if AUDIO_MODE=neither verify; then exit 1; fi
for unit in fstrim.timer systemd-timesyncd.service archcfg-charge-limit.timer; do
  if DISABLED_UNIT="$unit" verify; then exit 1; fi
  grep -q "DISABLED.*$unit" "$test_dir/output"
done
rm "$root/etc/resolv.conf"
printf 'nameserver PRIVATE_DNS_FIXTURE\nsearch PRIVATE_DOMAIN_FIXTURE\n' > "$root/etc/resolv.conf"
printf 'PRIVATE_BACKUP_FIXTURE\n' > "$root/etc/resolv.conf.vpnbackup"
verify
grep -q 'VPN resolver backup present' "$test_dir/output"
! grep -q 'PRIVATE_' "$test_dir/output"
rm "$root/etc/resolv.conf"
if verify; then exit 1; fi
rm "$root/etc/resolv.conf.vpnbackup"
printf 'PRIVATE_DNS_FIXTURE\n' > "$root/etc/resolv.conf"
if verify; then exit 1; fi
! grep -q 'PRIVATE_' "$test_dir/output"
# Exercise the postinstall policy with all service operations replaced by mocks.
source "$repo/scripts/services.sh"
enable_service_if_present() { printf 'system %s\n' "$1"; }
enable_user_service_globally_if_present() { printf 'user %s\n' "$1"; }
enable_core_services minimal > "$test_dir/services"
grep -qx 'system fstrim.timer' "$test_dir/services"
grep -qx 'system systemd-timesyncd.service' "$test_dir/services"
grep -qx 'user pipewire.socket' "$test_dir/services"
grep -qx 'user pipewire-pulse.socket' "$test_dir/services"
printf 'System policy fixtures passed\n'
