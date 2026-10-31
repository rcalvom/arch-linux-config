#!/usr/bin/env bash
set -euo pipefail

refresh_mirrors_if_available() {
  local mirrorlist=${1:-/etc/pacman.d/mirrorlist}
  local refreshed_mirrorlist
  local line
  local official_mirror='Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch'

  if ! command -v reflector >/dev/null 2>&1; then
    return 0
  fi

  log_info "Refreshing pacman mirrorlist"
  refreshed_mirrorlist=$(mktemp)
  if ! reflector --latest 20 --protocol https --sort rate --save "$refreshed_mirrorlist"; then
    rm -f -- "$refreshed_mirrorlist"
    log_warn "Could not refresh mirrorlist; continuing with existing mirrors"
    return 0
  fi

  # Prefer measured mirrors; a slow geo endpoint must not override Reflector's order.
  : > "$mirrorlist"
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s\n' "$line"
  done < "$refreshed_mirrorlist" >> "$mirrorlist"
  printf '%s\n' "$official_mirror" >> "$mirrorlist"
  rm -f -- "$refreshed_mirrorlist"
}

unmount_installer_target() {
  local target=$1

  if umount -R "$target"; then
    return 0
  fi

  log_warn "Target has busy mounts; syncing and detaching them"
  sync
  umount -R -l "$target"
}

configure_target_resolv_conf() {
  local target=$1
  local resolv_conf="$target/etc/resolv.conf"

  [[ -d "$target/etc" ]] || die "Target etc directory does not exist: $target/etc"
  rm -f "$resolv_conf"
  ln -s /run/systemd/resolve/stub-resolv.conf "$resolv_conf"
}

install_base_system() {
  local target=$1
  local repo_dir=$2
  local packages=()
  local live_keyring_dir=/etc/pacman.d/gnupg
  local keyring_dir="$target/etc/pacman.d/gnupg"

  log_info "Installing base system"
  load_packages_from_files packages "$repo_dir/packages/base.txt"
  if [[ ! -f "$live_keyring_dir/pubring.kbx" && ! -f "$live_keyring_dir/pubring.gpg" ]]; then
    log_info "Initializing live pacman keyring"
    pacman-key --init
    pacman-key --populate
  fi
  install -dm700 "$keyring_dir"
  pacman-key --gpgdir "$keyring_dir" --init
  pacman-key --gpgdir "$keyring_dir" --populate
  pacstrap -K "$target" "${packages[@]}"
}

generate_fstab() {
  local target=$1

  log_info "Generating fstab"
  genfstab -U "$target" > "$target/etc/fstab"
}

validate_user_password_file() {
  local password_file=$1
  local runtime_dir=/run/archcfg-e2e
  local owner
  local group
  local mode
  local size
  local password_lines=()

  [[ -n "$password_file" ]] || return 0
  [[ "${password_file%/*}" == "$runtime_dir" ]] || die "--user-password-file must be directly under $runtime_dir"
  [[ -d "$runtime_dir" && ! -L "$runtime_dir" ]] || die "Password runtime directory must be a regular directory: $runtime_dir"
  [[ -f "$password_file" && ! -L "$password_file" ]] || die "Password file must be a regular file: $password_file"

  IFS=: read -r owner group mode <<<"$(stat -c '%u:%g:%a' -- "$runtime_dir")"
  [[ "$owner" == 0 && "$group" == 0 && "$mode" == 700 ]] || die "Password runtime directory must be root:root mode 0700"

  IFS=: read -r owner group mode <<<"$(stat -c '%u:%g:%a' -- "$password_file")"
  [[ "$owner" == 0 && "$group" == 0 && "$mode" == 600 ]] || die "Password file must be root:root mode 0600"

  size=$(stat -c '%s' -- "$password_file")
  [[ "$size" =~ ^[0-9]+$ && "$size" -gt 0 && "$size" -le 4096 ]] || die "Password file must contain between 1 and 4096 bytes"

  mapfile -t password_lines < "$password_file"
  [[ "${#password_lines[@]}" -eq 1 && -n "${password_lines[0]}" ]] || die "Password file must contain exactly one nonempty line"
  [[ "${password_lines[0]}" != *:* && "${password_lines[0]}" != *$'\r'* ]] || die "Password file must not contain colons or carriage returns"
}

copy_repo_to_target() (
  local source_dir=$1
  local target=$2
  local repo_dest=$3
  local host_dest="$target$repo_dest"
  local stage
  local snapshot_lib

  [[ "$repo_dest" == /opt/* && "$repo_dest" != *..* ]] || die "Repository destination must be below /opt"
  target=$(realpath -e -- "$target")
  [[ "$target" != / ]] || die "Refusing repository installation into the live root"
  host_dest="$target$repo_dest"
  [[ "$(realpath -m -- "$host_dest")" == "$host_dest" ]] || die "Repository destination must not traverse symlinks"
  snapshot_lib="$(dirname -- "${BASH_SOURCE[0]}")/source-snapshot.sh"
  # shellcheck source=source-snapshot.sh
  source "$snapshot_lib"
  stage=$(mktemp -d)
  trap 'rm -rf -- "$stage"' EXIT
  mkdir "$stage/tree"
  log_info "Creating safe repository snapshot for target: $repo_dest"
  if [[ -e "$source_dir/.archcfg-source.sha256" ]]; then
    source_tree_verify "$source_dir" || die "Source snapshot checksum mismatch"
    tar --no-recursion -C "$source_dir" --null -T "$source_dir/.archcfg-source.files" \
      -cf "$stage/source.tar" -- .archcfg-source.files .archcfg-source.sha256 || die "Could not archive verified source"
  elif git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # A separate shell preserves the helper's errexit even for conditional callers.
    bash -e -c 'source "$1"; source_snapshot_create "$2" "$3" worktree "$4"' \
      bash "$snapshot_lib" "$source_dir" "$stage/source.tar" "$stage" || die "Could not create safe source snapshot"
  else
    die "Source must be a Git checkout or verified ISO snapshot"
  fi
  tar -xpf "$stage/source.tar" -C "$stage/tree" || die "Could not extract source snapshot"
  source_tree_verify "$stage/tree" || die "Target snapshot checksum mismatch"
  rm -rf -- "$host_dest"
  install -dm755 "$host_dest"
  cp -a "$stage/tree/." "$host_dest/"
  chown -R root:root "$host_dest"
)

write_user_password_file() {
  local target=$1
  local username=$2
  local source_password_file=${3:-}
  local password
  local password_confirm
  local password_file="$target/root/.archcfg-user-password"

  if [[ -n "$source_password_file" ]]; then
    if ! IFS= read -r password < "$source_password_file"; then
      [[ -n "$password" ]] || die "Could not read the initial-user password"
    fi

    install -dm700 "$target/root"
    install -m600 /dev/null "$password_file"
    PASSWORD_FILE_STAGED=1
    printf '%s:%s\n' "$username" "$password" > "$password_file"
    unset password
    rm -f -- "$source_password_file"
    return 0
  fi

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
  install -m600 /dev/null "$password_file"
  PASSWORD_FILE_STAGED=1
  printf '%s:%s\n' "$username" "$password" > "$password_file"
  unset password password_confirm
}

run_postinstall() {
  local target=$1
  local repo_dest=$2
  local profile=$3
  local hostname=$4
  local username=$5
  local timezone=$6
  local enable_aur=$7
  local microcode=$8 hardware_profile=$9 extra
  shift 9
  local postinstall_args=(
    /usr/bin/bash "$repo_dest/postinstall.sh"
    --profile "$profile"
    --hostname "$hostname"
    --username "$username"
    --timezone "$timezone"
    --repo-dir "$repo_dest"
    --microcode "$microcode"
    --hardware-profile "$hardware_profile"
  )
  if [[ "${RECIPE:-none}" != none ]]; then
    postinstall_args+=(--recipe "$RECIPE" --gpu "$GPU_POLICY")
    [[ "${DEFER_MANUAL:-0}" != 1 ]] || postinstall_args+=(--defer-manual)
  fi
  for extra in "$@"; do
    postinstall_args+=(--extra "$extra")
  done

  if [[ "$enable_aur" -eq 1 ]]; then
    postinstall_args+=(--aur)
  fi

  log_info "Entering chroot"
  arch-chroot "$target" "${postinstall_args[@]}"
}
