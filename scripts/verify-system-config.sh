#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
root_dir=/
root_prefix=
profile=developer
wifi_interface=auto
grub_profile=auto
show_diff=false
failures=0
warnings=0

usage() {
  cat <<'USAGE'
Usage: verify-system-config.sh [options]

Options:
  --repo PATH             Repository path. Default: repository containing this script.
  --root PATH             Installed system root. Default: /.
  --profile NAME          minimal, desktop, developer, or virtualbox. Default: developer.
  --wifi-interface VALUE  auto, none, or an interface name. Default: auto.
  --grub-profile VALUE    auto, graphical, classic, or none. Default: auto.
  --diff                  Show content differences.
  --help                  Print this help.
USAGE
}

report() {
  printf '[%s] %s\n' "$1" "$2"
}

compare_file() {
  local source=$1
  local destination=$2
  local expected_mode=${3:-}
  local actual_mode

  if [[ -n "$expected_mode" ]]; then
    printf -v expected_mode '%o' "$((8#$expected_mode))"
  fi

  if [[ ! -f "$source" ]]; then
    report ERROR "missing source: $source"
    ((failures += 1))
    return
  fi

  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    report MISSING "$destination"
    ((failures += 1))
    return
  fi

  if [[ ! -f "$destination" || -L "$destination" ]]; then
    report TYPE "$destination is not a regular file"
    ((failures += 1))
    return
  fi

  if ! cmp -s "$source" "$destination"; then
    report DIFFERENT "$destination"
    ((failures += 1))
    if "$show_diff"; then
      diff -u --label "$source" --label "$destination" "$source" "$destination" || true
    fi
  fi

  if [[ -n "$expected_mode" ]]; then
    actual_mode=$(stat -c '%a' "$destination")
    if [[ "$actual_mode" != "$expected_mode" ]]; then
      report MODE "$destination has mode $actual_mode; expected $expected_mode"
      ((failures += 1))
    fi
  fi
}

compare_content() {
  local content=$1
  local destination=$2
  local expected_mode=${3:-}
  local actual_mode

  if [[ -n "$expected_mode" ]]; then
    printf -v expected_mode '%o' "$((8#$expected_mode))"
  fi

  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    report MISSING "$destination"
    ((failures += 1))
    return
  fi

  if [[ ! -f "$destination" || -L "$destination" ]]; then
    report TYPE "$destination is not a regular file"
    ((failures += 1))
    return
  fi

  if ! cmp -s <(printf '%s\n' "$content") "$destination"; then
    report DIFFERENT "$destination"
    ((failures += 1))
    if "$show_diff"; then
      diff -u --label expected --label "$destination" <(printf '%s\n' "$content") "$destination" || true
    fi
  fi

  if [[ -n "$expected_mode" ]]; then
    actual_mode=$(stat -c '%a' "$destination")
    if [[ "$actual_mode" != "$expected_mode" ]]; then
      report MODE "$destination has mode $actual_mode; expected $expected_mode"
      ((failures += 1))
    fi
  fi
}

compare_tree() {
  local source_root=$1
  local destination_root=$2
  local file
  local relative

  if [[ ! -d "$source_root" ]]; then
    report ERROR "missing source directory: $source_root"
    ((failures += 1))
    return
  fi

  if [[ ! -d "$destination_root" ]]; then
    report MISSING "$destination_root"
    ((failures += 1))
    return
  fi

  source_root=$(cd -- "$source_root" && pwd -P)
  while IFS= read -r -d '' file; do
    relative=${file#"$source_root"/}
    compare_file "$file" "$destination_root/$relative"
  done < <(find "$source_root" -type f -print0)
}

compare_link() {
  local expected_target=$1
  local destination=$2
  local actual_target

  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    report MISSING "$destination"
    ((failures += 1))
    return
  fi

  if [[ ! -L "$destination" ]]; then
    report TYPE "$destination is not a symbolic link"
    ((failures += 1))
    return
  fi

  actual_target=$(readlink -- "$destination")
  if [[ "$actual_target" != "$expected_target" ]]; then
    report DIFFERENT "$destination"
    ((failures += 1))
  fi
}

check_absent() {
  local path=$1

  if [[ -e "$path" || -L "$path" ]]; then
    report PRESENT "expected absent: $path"
    ((failures += 1))
  fi
}

check_executable() {
  local path=$1

  if [[ ! -x "$path" ]]; then
    report MISSING "executable: $path"
    ((failures += 1))
  fi
}

unit_is_enabled() {
  local unit=$1

  if [[ "$root_dir" == / ]]; then
    systemctl is-enabled --quiet "$unit"
  else
    systemctl --root="$root_dir" is-enabled --quiet "$unit"
  fi
}

global_user_unit_is_enabled() {
  local unit=$1

  if [[ "$root_dir" == / ]]; then
    systemctl --global is-enabled --quiet "$unit"
  else
    systemctl --root="$root_dir" --global is-enabled --quiet "$unit"
  fi
}

check_enabled_unit() {
  local unit=$1

  if ! unit_is_enabled "$unit"; then
    report DISABLED "$unit"
    ((failures += 1))
  fi
}

check_disabled_unit() {
  local unit=$1

  if unit_is_enabled "$unit"; then
    report ENABLED "$unit"
    ((failures += 1))
  fi
}

check_enabled_global_user_unit() {
  local unit=$1

  if ! global_user_unit_is_enabled "$unit"; then
    report DISABLED "global user unit: $unit"
    ((failures += 1))
  fi
}

profile_has_desktop() {
  case "$profile" in
    desktop | developer | virtualbox)
      return 0
      ;;
  esac
  return 1
}

resolve_wifi_interface() {
  local selection_status

  if selected_wifi_interface=$(select_wifi_interface "$wifi_interface"); then
    return 0
  fi

  selection_status=$?
  case "$selection_status" in
    1)
      report WARN "no Wi-Fi interface detected; skipping IWD ownership checks"
      ((warnings += 1))
      ;;
    2)
      report WARN "multiple Wi-Fi interfaces detected; rerun with --wifi-interface <name>"
      ((warnings += 1))
      ;;
    *)
      report ERROR "invalid Wi-Fi interface: $wifi_interface"
      ((failures += 1))
      ;;
  esac
  selected_wifi_interface=
  return 1
}

verify_networking() {
  local expected_config

  if [[ -z "$selected_wifi_interface" ]]; then
    return 0
  fi

  if [[ "$selected_wifi_interface" == none ]]; then
    check_absent "$root_prefix/etc/NetworkManager/conf.d/10-iwd-wlan0.conf"
    check_absent "$root_prefix/etc/systemd/system/host-network-online.service"
    check_absent "$root_prefix/etc/systemd/system/archcfg-reset-resolved-if-stub.service"
    check_absent "$root_prefix/etc/systemd/system/archcfg-reset-resolved-if-stub.path"
    check_absent "$root_prefix/usr/local/libexec/archcfg-wait-network-online"
    check_absent "$root_prefix/usr/local/libexec/archcfg-reset-resolved-if-stub"
    check_disabled_unit iwd.service
    check_disabled_unit host-network-online.service
    check_disabled_unit archcfg-reset-resolved-if-stub.path
    check_enabled_unit NetworkManager-wait-online.service
    return 0
  fi

  expected_config=$(iwd_networkmanager_config "$selected_wifi_interface")
  compare_content "$expected_config" "$root_prefix/etc/NetworkManager/conf.d/10-iwd-wlan0.conf" 0644
  compare_file "$repo_dir/network/iwd/main.conf" "$root_prefix/etc/iwd/main.conf" 0644
  compare_file "$repo_dir/network/systemd/host-network-online.service" "$root_prefix/etc/systemd/system/host-network-online.service" 0644
  compare_file "$repo_dir/network/systemd/archcfg-reset-resolved-if-stub.service" "$root_prefix/etc/systemd/system/archcfg-reset-resolved-if-stub.service" 0644
  compare_file "$repo_dir/network/systemd/archcfg-reset-resolved-if-stub.path" "$root_prefix/etc/systemd/system/archcfg-reset-resolved-if-stub.path" 0644
  compare_file "$repo_dir/network/bin/archcfg-wait-network-online" "$root_prefix/usr/local/libexec/archcfg-wait-network-online" 0755
  compare_file "$repo_dir/network/bin/archcfg-reset-resolved-if-stub" "$root_prefix/usr/local/libexec/archcfg-reset-resolved-if-stub" 0755
  compare_link /run/systemd/resolve/stub-resolv.conf "$root_prefix/etc/resolv.conf"
  check_enabled_unit iwd.service
  check_enabled_unit systemd-resolved.service
  check_enabled_unit host-network-online.service
  check_enabled_unit archcfg-reset-resolved-if-stub.path
  check_disabled_unit NetworkManager-wait-online.service
}

verify_charge_limits() {
  check_executable "$root_prefix/usr/bin/upower"
  compare_file "$repo_dir/power/charge-limit.conf" "$root_prefix/etc/archcfg/charge-limit.conf" 0644
  compare_file "$repo_dir/power/bin/archcfg-charge-limit" "$root_prefix/usr/local/libexec/archcfg-charge-limit" 0755
  compare_file "$repo_dir/power/systemd/archcfg-charge-limit.service" "$root_prefix/etc/systemd/system/archcfg-charge-limit.service" 0644
  compare_file "$repo_dir/power/udev/99-archcfg-charge-limit.rules" "$root_prefix/etc/udev/rules.d/99-archcfg-charge-limit.rules" 0644
  compare_file "$repo_dir/power/upower/90-archcfg-critical-battery.conf" "$root_prefix/etc/UPower/UPower.conf.d/90-archcfg-critical-battery.conf" 0644
  check_enabled_unit archcfg-charge-limit.service
  check_absent "$root_prefix/etc/systemd/system/battery-thresholds.service"
  check_absent "$root_prefix/etc/systemd/system/battery-thresholds.timer"
  check_absent "$root_prefix/usr/local/bin/battery_thresholds.sh"
}

verify_desktop() {
  local environment_source

  case "$profile" in
    virtualbox)
      environment_source="$repo_dir/wayland/environment.virtualbox"
      ;;
    desktop | developer)
      environment_source="$repo_dir/wayland/environment.desktop"
      ;;
    *)
      return
      ;;
  esac

  compare_file "$repo_dir/greetd/vtrgb" "$root_prefix/etc/vtrgb" 0644
  compare_file "$repo_dir/greetd/greetd-vtrgb.conf" "$root_prefix/etc/systemd/system/greetd.service.d/10-vtrgb.conf" 0644
  compare_file "$repo_dir/greetd/vconsole.conf" "$root_prefix/etc/vconsole.conf" 0644
  compare_file "$repo_dir/greetd/config.toml" "$root_prefix/etc/greetd/config.toml" 0644
  compare_file "$repo_dir/greetd/environments" "$root_prefix/etc/greetd/environments" 0644
  compare_file "$repo_dir/greetd/archcfg-xsession-wrapper" "$root_prefix/usr/local/libexec/archcfg-xsession-wrapper" 0755
  compare_file "$repo_dir/greetd/archcfg-wayland-session-wrapper" "$root_prefix/usr/local/libexec/archcfg-wayland-session-wrapper" 0755
  compare_file "$environment_source" "$root_prefix/etc/environment" 0644
  check_absent "$root_prefix/etc/greetd/regreet.toml"
  check_enabled_unit bluetooth.service
  check_enabled_unit greetd.service
  check_enabled_global_user_unit pipewire.service
  check_enabled_global_user_unit pipewire-pulse.service
  check_enabled_global_user_unit wireplumber.service

  if [[ "$profile" == developer || "$profile" == virtualbox ]]; then
    check_enabled_unit docker.service
  fi

  if [[ -e "$root_prefix/etc/modules-load.d/nvidia-utils.conf" ]]; then
    compare_file "$repo_dir/modules-load.d/nvidia-utils.conf" "$root_prefix/etc/modules-load.d/nvidia-utils.conf" 0644
  fi

  if [[ "$profile" == virtualbox ]]; then
    check_enabled_unit vboxservice.service
  fi
}

verify_grub() {
  local selected_profile=$grub_profile
  local config_source
  local theme_source
  local theme_destination

  if [[ "$selected_profile" == none ]]; then
    return 0
  fi

  if [[ "$selected_profile" == auto ]]; then
    if cmp -s "$repo_dir/grub/grub" "$root_prefix/etc/default/grub"; then
      selected_profile=graphical
    elif cmp -s "$repo_dir/grub/classic/grub" "$root_prefix/etc/default/grub"; then
      selected_profile=classic
    else
      report DIFFERENT "$root_prefix/etc/default/grub does not match a tracked GRUB profile"
      ((failures += 1))
      return
    fi
  fi

  case "$selected_profile" in
    graphical)
      config_source="$repo_dir/grub/grub"
      theme_source="$repo_dir/grub/theme"
      theme_destination="$root_prefix/usr/share/grub/themes/arch"
      ;;
    classic)
      config_source="$repo_dir/grub/classic/grub"
      theme_source="$repo_dir/grub/classic/theme"
      theme_destination="$root_prefix/usr/share/grub/themes/arch-classic"
      ;;
    *)
      report ERROR "invalid GRUB profile: $selected_profile"
      ((failures += 1))
      return
      ;;
  esac

  compare_file "$config_source" "$root_prefix/etc/default/grub" 0644
  compare_tree "$theme_source" "$theme_destination"
  if [[ ! -f "$root_prefix/boot/grub/grub.cfg" ]]; then
    report MISSING "$root_prefix/boot/grub/grub.cfg"
    ((failures += 1))
  fi
}

while (($#)); do
  case "$1" in
    --repo)
      (($# >= 2)) || { usage >&2; exit 2; }
      repo_dir=$2
      shift 2
      ;;
    --root)
      (($# >= 2)) || { usage >&2; exit 2; }
      root_dir=$2
      shift 2
      ;;
    --profile)
      (($# >= 2)) || { usage >&2; exit 2; }
      profile=$2
      shift 2
      ;;
    --wifi-interface)
      (($# >= 2)) || { usage >&2; exit 2; }
      wifi_interface=$2
      shift 2
      ;;
    --grub-profile)
      (($# >= 2)) || { usage >&2; exit 2; }
      grub_profile=$2
      shift 2
      ;;
    --diff)
      show_diff=true
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

repo_dir=$(cd -- "$repo_dir" && pwd -P)
root_dir=$(cd -- "$root_dir" && pwd -P)
if [[ "$root_dir" != / ]]; then
  root_prefix=$root_dir
fi
# shellcheck source=lib/network.sh
source "$repo_dir/lib/network.sh"

case "$profile" in
  minimal | desktop | developer | virtualbox)
    ;;
  *)
    report ERROR "invalid profile: $profile"
    exit 2
    ;;
esac

wifi_interface_name_is_valid "$wifi_interface" || [[ "$wifi_interface" == auto || "$wifi_interface" == none ]] || {
  report ERROR "invalid Wi-Fi interface: $wifi_interface"
  exit 2
}

case "$grub_profile" in
  auto | graphical | classic | none)
    ;;
  *)
    report ERROR "invalid GRUB profile: $grub_profile"
    exit 2
    ;;
esac

selected_wifi_interface=
if profile_has_desktop; then
  resolve_wifi_interface || true
fi

check_enabled_unit NetworkManager.service
verify_networking
verify_charge_limits
if profile_has_desktop; then
  verify_desktop
fi
verify_grub

if ((failures)); then
  report FAIL "$failures managed system configuration difference(s) found"
  exit 1
fi

if ((warnings)); then
  report WARN "verification completed with $warnings environment warning(s)"
else
  report OK "all managed system configuration matches the repository"
fi
