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

aur_dependency_files_for_profile() {
  local profile=$1

  case "$profile" in
    developer | virtualbox)
      printf '%s\n' "packages/aur-deps.txt"
      ;;
  esac
}

aur_package_name_is_valid() {
  local package=$1

  [[ "$package" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]
}

aur_revision_is_valid() {
  local revision=$1

  [[ "$revision" =~ ^[[:xdigit:]]{40}$ ]]
}

load_aur_packages_from_files() {
  local -n package_names=$1
  local -n package_revisions=$2
  local file
  local line
  local package
  local revision
  local extra
  local -A seen=()

  shift 2
  package_names=()
  package_revisions=()

  for file in "$@"; do
    [[ -f "$file" ]] || die "AUR package file not found: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      IFS='|' read -r package revision extra <<< "$line"
      [[ -n "$package" && -n "$revision" && -z "$extra" ]] || die "Invalid AUR package entry in $file: $line"
      aur_package_name_is_valid "$package" || die "Invalid AUR package name: $package"
      aur_revision_is_valid "$revision" || die "Invalid AUR revision for $package: $revision"
      [[ -z "${seen[$package]+x}" ]] || die "Duplicate AUR package: $package"
      seen[$package]=1
      package_names+=("$package")
      package_revisions+=("${revision,,}")
    done < "$file"
  done
}

install_aur_dependencies_for_profile() {
  local profile=$1
  local repo_dir=$2
  local files=()
  local relative_file
  local packages=()

  while IFS= read -r relative_file; do
    files+=("$repo_dir/$relative_file")
  done < <(aur_dependency_files_for_profile "$profile")

  [[ "${#files[@]}" -gt 0 ]] || return 0
  load_packages_from_files packages "${files[@]}"
  [[ "${#packages[@]}" -gt 0 ]] || return 0

  log_info "Installing reviewed official AUR dependencies"
  pacman -S --needed --noconfirm "${packages[@]}"
}

build_aur_package() {
  local username=$1
  local build_root=$2
  local package=$3
  local revision=$4
  local build_home="$build_root/home"
  local package_dir="$build_root/$package"
  local checked_out_revision
  local built_packages=()
  local artifact

  log_info "Building pinned AUR package: $package@$revision"
  runuser -u "$username" -- env HOME="$build_home" XDG_CACHE_HOME="$build_root/cache" \
    git clone --no-checkout "https://aur.archlinux.org/$package.git" "$package_dir"
  runuser -u "$username" -- env HOME="$build_home" XDG_CACHE_HOME="$build_root/cache" \
    git -C "$package_dir" checkout --detach "$revision"
  checked_out_revision=$(runuser -u "$username" -- env HOME="$build_home" \
    git -C "$package_dir" rev-parse HEAD)
  [[ "$checked_out_revision" == "$revision" ]] || die "AUR revision mismatch for $package"

  runuser -u "$username" -- env HOME="$build_home" XDG_CACHE_HOME="$build_root/cache" \
    bash -c 'cd -- "$1" && makepkg --noconfirm --cleanbuild --nodeps' bash "$package_dir"

  while IFS= read -r -d '' artifact; do
    built_packages+=("$artifact")
  done < <(find "$package_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
  [[ "${#built_packages[@]}" -gt 0 ]] || die "No built package artifact found for AUR package: $package"

  pacman -U --needed --noconfirm "${built_packages[@]}"
}

install_aur_packages_for_profile() (
  local profile=$1
  local repo_dir=$2
  local username=$3
  local enabled=$4
  local files=()
  local relative_file
  local packages=()
  local revisions=()
  local build_root=
  local index

  while IFS= read -r relative_file; do
    files+=("$repo_dir/$relative_file")
  done < <(aur_package_files_for_profile "$profile")

  [[ "${#files[@]}" -gt 0 ]] || exit 0
  load_aur_packages_from_files packages revisions "${files[@]}"
  [[ "${#packages[@]}" -gt 0 ]] || exit 0

  if [[ "$enabled" -ne 1 ]]; then
    log_info "Skipping AUR packages; rerun with --aur to install: ${packages[*]}"
    exit 0
  fi

  require_command git
  require_command makepkg
  require_command pacman
  require_command runuser
  id -u "$username" >/dev/null 2>&1 || die "AUR build user does not exist: $username"

  install_aur_dependencies_for_profile "$profile" "$repo_dir"
  build_root=$(mktemp -d /var/tmp/archcfg-aur.XXXXXX)
  trap 'rm -rf -- "$build_root"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 131' QUIT
  trap 'exit 143' TERM
  chown "$username:$username" "$build_root"
  install -dm700 -o "$username" -g "$username" "$build_root/home" "$build_root/cache"

  for index in "${!packages[@]}"; do
    build_aur_package "$username" "$build_root" "${packages[index]}" "${revisions[index]}"
  done
)
