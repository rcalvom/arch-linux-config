#!/usr/bin/env bash
set -euo pipefail

package_files_for_profile() {
  local profile=$1

  case "$profile" in
    minimal)
      printf '%s\n' "packages/base.txt"
      ;;
    desktop)
      printf '%s\n' "packages/base.txt" "packages/desktop.txt"
      ;;
    developer)
      printf '%s\n' "packages/base.txt" "packages/desktop.txt" "packages/dev.txt"
      ;;
    virtualbox)
      printf '%s\n' "packages/base.txt" "packages/desktop.txt" "packages/dev.txt" "packages/vm.txt"
      ;;
    *)
      die "Invalid profile: $profile"
      ;;
  esac
}

load_packages_from_files() {
  local -n output=$1
  local file
  local line

  shift
  output=()

  for file in "$@"; do
    [[ -f "$file" ]] || die "Package file not found: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      output+=("$line")
    done < "$file"
  done
}

install_packages_for_profile() {
  local profile=$1
  local repo_dir=$2
  local files=()
  local relative_file
  local packages=()

  while IFS= read -r relative_file; do
    files+=("$repo_dir/$relative_file")
  done < <(package_files_for_profile "$profile")

  load_packages_from_files packages "${files[@]}"

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_warn "No packages selected for profile: $profile"
    return 0
  fi

  log_info "Installing profile packages: $profile"
  pacman -Syu --needed --noconfirm "${packages[@]}"
}
