#!/usr/bin/env bash
set -euo pipefail

install_base_system() {
  local target=$1
  local repo_dir=$2
  local packages=()

  log_info "Installing base system"
  load_packages_from_files packages "$repo_dir/packages/base.txt"
  pacstrap -K "$target" "${packages[@]}"
}

generate_fstab() {
  local target=$1

  log_info "Generating fstab"
  genfstab -U "$target" > "$target/etc/fstab"
}

copy_repo_to_target() {
  local source_dir=$1
  local target=$2
  local repo_dest=$3
  local host_dest="$target$repo_dest"

  log_info "Copying repository to target: $repo_dest"
  rm -rf "$host_dest"
  install -dm755 "$target/opt"
  cp -a "$source_dir" "$host_dest"
}

write_user_password_file() {
  local target=$1
  local username=$2
  local password
  local password_confirm
  local password_file="$target/root/.archcfg-user-password"
  local old_umask

  if [[ ! -t 0 ]]; then
    log_warn "No interactive terminal detected; password for $username will not be set"
    return 0
  fi

  while true; do
    printf 'Password for %s: ' "$username"
    read -r -s password
    printf '\n'
    printf 'Confirm password for %s: ' "$username"
    read -r -s password_confirm
    printf '\n'

    if [[ -z "$password" ]]; then
      log_warn "Password cannot be empty"
      continue
    fi

    if [[ "$password" != "$password_confirm" ]]; then
      log_warn "Passwords do not match"
      continue
    fi

    break
  done

  install -dm700 "$target/root"
  old_umask=$(umask)
  umask 077
  printf '%s:%s\n' "$username" "$password" > "$password_file"
  umask "$old_umask"
  unset password password_confirm
}

run_postinstall() {
  local target=$1
  local repo_dest=$2
  local profile=$3
  local hostname=$4
  local username=$5
  local timezone=$6

  log_info "Entering chroot"
  arch-chroot "$target" "$repo_dest/postinstall.sh" \
    --profile "$profile" \
    --hostname "$hostname" \
    --username "$username" \
    --timezone "$timezone" \
    --repo-dir "$repo_dest"
}
