#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
home_dir=$HOME
show_diff=false
failures=0
warnings=0

usage() {
  printf 'Usage: %s [--repo PATH] [--home PATH] [--diff]\n' "${0##*/}"
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

warn_file() {
  local source=$1
  local destination=$2

  [[ -f "$source" ]] || return
  if [[ ! -e "$destination" ]]; then
    report WARN "missing local-state file: $destination"
    ((warnings += 1))
  elif ! cmp -s "$source" "$destination"; then
    report WARN "local-state file differs: $destination"
    ((warnings += 1))
    if "$show_diff"; then
      diff -u --label "$source" --label "$destination" "$source" "$destination" || true
    fi
  fi
}

is_ignored_extra() {
  local destination_root=$1
  local relative=$2

  case "$destination_root:$relative" in
    "$home_dir/.config/nvim":.backup-source | "$home_dir/.config/nvim":init.lua.orig)
      return 0
      ;;
    "$home_dir/.config/yazi":flavors/modus-vivendi.yazi/*)
      return 0
      ;;
  esac

  return 1
}

compare_tree() {
  local source_root=$1
  local destination_root=$2
  local expected_mode=${3:-}
  local file relative destination

  [[ -d "$source_root" ]] || {
    report ERROR "missing source directory: $source_root"
    ((failures += 1))
    return
  }

  source_root=$(cd -- "$source_root" && pwd -P)
  if [[ ! -d "$destination_root" ]]; then
    report MISSING "$destination_root"
    ((failures += 1))
    return
  fi

  while IFS= read -r -d '' file; do
    relative=${file#"$source_root"/}
    [[ "${relative##*/}" == "files.conf" ]] && continue
    compare_file "$file" "$destination_root/$relative" "$expected_mode"
  done < <(find "$source_root" -type f -print0)

  while IFS= read -r -d '' file; do
    relative=${file#"$destination_root"/}
    [[ "${relative##*/}" == "files.conf" || -f "$source_root/$relative" ]] && continue
    is_ignored_extra "$destination_root" "$relative" && continue
    report WARN "extra local file: $file"
    ((warnings += 1))
  done < <(find "$destination_root" -type f -print0)
}

check_manifest() {
  local manifest=$1
  local package_dir kind mode source destination

  package_dir=$(cd -- "$(dirname -- "$manifest")" && pwd -P)
  while IFS='|' read -r kind mode source destination || [[ -n "$kind" ]]; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue

    case "$kind" in
      user_file)
        compare_file "$package_dir/$source" "$home_dir/$destination" "$mode"
        ;;
      user_tree)
        compare_tree "$package_dir/$source" "$home_dir/$destination" "$mode"
        ;;
      root_file | root_tree)
        ;;
      *)
        report ERROR "unknown manifest kind in $manifest: $kind"
        ((failures += 1))
        ;;
    esac
  done < "$manifest"
}

while (($#)); do
  case "$1" in
    --repo)
      (($# >= 2)) || { usage >&2; exit 2; }
      repo_dir=$2
      shift 2
      ;;
    --home)
      (($# >= 2)) || { usage >&2; exit 2; }
      home_dir=$2
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
home_dir=$(cd -- "$home_dir" && pwd -P)

for manifest in "$repo_dir"/packages/*/files.conf; do
  [[ -f "$manifest" ]] || continue
  check_manifest "$manifest"
done

while IFS='|' read -r source destination mode; do
  compare_file "$repo_dir/$source" "$home_dir/$destination" "$mode"
done <<'EOF'
wayland/hypr/hyprland.lua|.config/hypr/hyprland.lua|0644
wayland/hypr/xdph.conf|.config/hypr/xdph.conf|0644
wayland/hypr/hyprtoolkit.conf|.config/hypr/hyprtoolkit.conf|0644
wayland/hypr/hypridle.conf|.config/hypr/hypridle.conf|0644
wayland/hypr/hyprlock.conf|.config/hypr/hyprlock.conf|0644
wayland/hypr/hyprpaper.conf|.config/hypr/hyprpaper.conf|0644
wayland/wallpapers/wallpaper.png|Pictures/wallpaper2.png|0644
wayland/waybar/config.jsonc|.config/waybar/config.jsonc|0644
wayland/waybar/style.css|.config/waybar/style.css|0644
wayland/rofi/config.rasi|.config/rofi/config.rasi|0644
wayland/rofi/share-picker.rasi|.config/rofi/share-picker.rasi|0644
wayland/mako/config|.config/mako/config|0644
wayland/fontconfig/conf.d/99-ubuntu-fallback.conf|.config/fontconfig/conf.d/99-ubuntu-fallback.conf|0644
EOF

compare_tree "$repo_dir/wayland/rofi/share-picker-icons" "$home_dir/.config/rofi/share-picker-icons"

for source in "$repo_dir"/wayland/bin/*; do
  [[ -f "$source" ]] || continue
  compare_file "$source" "$home_dir/.local/bin/${source##*/}" 0755
done

for source in "$repo_dir"/wayland/systemd/user/*; do
  [[ -f "$source" ]] || continue
  compare_file "$source" "$home_dir/.config/systemd/user/${source##*/}" 0644
done

compare_file "$repo_dir/wayland/systemd/user/xdg-desktop-portal-hyprland.service.d/share-picker.conf" "$home_dir/.config/systemd/user/xdg-desktop-portal-hyprland.service.d/share-picker.conf" 0644

for timer in hyprsunset-day.timer hyprsunset-night.timer; do
  destination="$home_dir/.config/systemd/user/timers.target.wants/$timer"
  expected="$home_dir/.config/systemd/user/$timer"
  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    report MISSING "$destination"
    ((failures += 1))
  elif [[ ! -L "$destination" ]]; then
    report TYPE "$destination is not a symbolic link"
    ((failures += 1))
  elif [[ $(readlink -f -- "$destination") != "$expected" ]]; then
    report DIFFERENT "$destination"
    ((failures += 1))
  fi
done

# Desktop MIME handlers are expanded by installed applications and are local state.
warn_file "$repo_dir/wayland/mimeapps.list" "$home_dir/.config/mimeapps.list"

if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && [[ -n $(git -C "$repo_dir" status --porcelain) ]]; then
  report WARN "working tree has uncommitted changes; HEAD is not a complete reconstruction snapshot"
  ((warnings += 1))
fi

if ((failures)); then
  report FAIL "$failures managed configuration difference(s) found"
  exit 1
fi

if ((warnings)); then
  report WARN "verification completed with $warnings local-state warning(s)"
else
  report OK "all managed user configuration matches the repository"
fi
