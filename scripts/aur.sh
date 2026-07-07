#!/usr/bin/env bash
set -euo pipefail

aur_package_files_for_profile() {
  local profile=$1

  case "$profile" in
    developer | virtualbox)
      printf '%s\n' "packages/aur.txt"
      ;;
  esac
}

build_aur_package() {
  local username=$1
  local package=$2
  local build_root=/var/tmp/archcfg-aur
  local package_dir="$build_root/$package"
  local built_packages=()

  log_info "Building AUR package: $package"
  install -dm755 "$build_root"
  chown "$username:$username" "$build_root"
  rm -rf "$package_dir"

  sudo -u "$username" -- git clone "https://aur.archlinux.org/$package.git" "$package_dir"
  sudo -u "$username" -- bash -c 'cd "$1" && makepkg --noconfirm' bash "$package_dir"

  mapfile -t built_packages < <(compgen -G "$package_dir/*.pkg.tar.*")
  [[ "${#built_packages[@]}" -gt 0 ]] || die "No built package artifact found for AUR package: $package"

  pacman -U --needed --noconfirm "${built_packages[@]}"
}

ensure_yay() {
  local username=$1

  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  build_aur_package "$username" yay-bin
}

grant_temporary_aur_sudo() {
  local username=$1

  install -dm755 /etc/sudoers.d
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$username" > /etc/sudoers.d/90-archcfg-aur
  chmod 0440 /etc/sudoers.d/90-archcfg-aur
}

revoke_temporary_aur_sudo() {
  rm -f /etc/sudoers.d/90-archcfg-aur
}

install_aur_packages_for_profile() {
  local profile=$1
  local repo_dir=$2
  local username=$3
  local enabled=$4
  local files=()
  local relative_file
  local packages=()

  while IFS= read -r relative_file; do
    files+=("$repo_dir/$relative_file")
  done < <(aur_package_files_for_profile "$profile")

  if [[ "${#files[@]}" -eq 0 ]]; then
    return 0
  fi

  load_packages_from_files packages "${files[@]}"
  if [[ "${#packages[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ "$enabled" -ne 1 ]]; then
    log_info "Skipping AUR packages; rerun with --aur to install: ${packages[*]}"
    return 0
  fi

  require_command git
  require_command makepkg
  require_command sudo

  ensure_yay "$username"
  grant_temporary_aur_sudo "$username"

  if ! sudo -u "$username" -- yay -S --needed --noconfirm "${packages[@]}"; then
    revoke_temporary_aur_sudo
    die "AUR package installation failed"
  fi

  revoke_temporary_aur_sudo
}
