#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
PROFILE_SOURCE="$REPO_ROOT/live"
OUT_DIR="$REPO_ROOT/out"
WORK_DIR="$REPO_ROOT/work/archiso"
CLEAN=0
FAST=0

usage() {
  cat <<'USAGE'
Usage: scripts/build-iso.sh [options]

Options:
  --out-dir <path>      ISO output directory. Default: ./out.
  --work-dir <path>     mkarchiso work directory. Default: ./work/archiso.
  --clean               Remove work/output directories before building.
  --fast                Use faster rootfs compression for local test builds.
  --help                Print this help.

The ISO includes the committed repository tree at /opt/arch-linux-config and
adds archcfg-install as a shortcut for /opt/arch-linux-config/install.sh.
USAGE
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

log_info() {
  printf '[INFO] %s\n' "$*"
}

require_command() {
  local command_name=$1

  command -v "$command_name" >/dev/null 2>&1 || die "Missing required command: $command_name"
}

require_value() {
  local flag=$1
  local value=${2-}

  if [[ -z "$value" || "$value" == --* ]]; then
    die "$flag requires a value"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out-dir)
        require_value "$1" "${2-}"
        OUT_DIR=$2
        shift 2
        ;;
      --work-dir)
        require_value "$1" "${2-}"
        WORK_DIR=$2
        shift 2
        ;;
      --clean)
        CLEAN=1
        shift
        ;;
      --fast)
        FAST=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

detect_worker_count() {
  local workers

  if command -v nproc >/dev/null 2>&1; then
    workers=$(nproc 2>/dev/null || printf '1')
  else
    workers=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
  fi

  if [[ ! "$workers" =~ ^[0-9]+$ || "$workers" -lt 1 ]]; then
    workers=1
  fi

  printf '%s\n' "$workers"
}

apply_fast_build_options() {
  local profile_dir=$1
  local profiledef="$profile_dir/profiledef.sh"
  local workers

  workers=$(detect_worker_count)
  log_info "Using fast rootfs compression: erofs zstd level 3 with $workers workers"

  {
    printf '\n# Added by scripts/build-iso.sh --fast for iterative local builds.\n'
    printf "airootfs_image_tool_options=('-zzstd,level=3' '--workers=%s' -E 'ztailpacking,fragments,dedupe')\n" "$workers"
  } >>"$profiledef"
}

enable_system_service_in_profile() {
  local profile_dir=$1
  local service=$2
  local wants_dir="$profile_dir/airootfs/etc/systemd/system/multi-user.target.wants"

  install -dm755 "$wants_dir"
  ln -sfn "/usr/lib/systemd/system/$service" "$wants_dir/$service"
}

copy_grub_theme_to_profile() {
  local profile_dir=$1
  local theme_dest="$profile_dir/grub/themes/arch"

  rm -rf "$theme_dest"
  install -dm755 "$theme_dest"
  cp -a "$REPO_ROOT/grub/theme/." "$theme_dest/"
}

copy_committed_repo_tree() {
  local destination=$1

  install -dm755 "$destination"

  if git -C "$REPO_ROOT" -c safe.directory="$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$REPO_ROOT" -c safe.directory="$REPO_ROOT" archive --format=tar HEAD | tar -C "$destination" -xf -
  else
    tar \
      --exclude='.git' \
      --exclude='./out' \
      --exclude='./work' \
      -C "$REPO_ROOT" \
      -cf - . | tar -C "$destination" -xf -
  fi
}

prepare_profile() {
  local profile_copy=$1
  local bundled_repo="$profile_copy/airootfs/opt/arch-linux-config"

  log_info "Preparing temporary archiso profile"
  cp -a "$PROFILE_SOURCE/." "$profile_copy"
  if [[ "$FAST" -eq 1 ]]; then
    apply_fast_build_options "$profile_copy"
  fi
  copy_grub_theme_to_profile "$profile_copy"

  rm -rf "$bundled_repo"
  copy_committed_repo_tree "$bundled_repo"
  chmod +x \
    "$bundled_repo/install.sh" \
    "$bundled_repo/postinstall.sh" \
    "$bundled_repo/installation/archlinux.sh" \
    "$bundled_repo/scripts/build-iso.sh"

  enable_system_service_in_profile "$profile_copy" NetworkManager.service
}

main() {
  local temp_dir
  local profile_copy

  parse_args "$@"

  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run this script as root"
  require_command mkarchiso
  require_command git
  require_command tar

  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT
  profile_copy="$temp_dir/profile"
  install -dm755 "$profile_copy"

  if [[ "$CLEAN" -eq 1 ]]; then
    log_info "Cleaning $WORK_DIR and $OUT_DIR"
    rm -rf "$WORK_DIR" "$OUT_DIR"
  fi

  install -dm755 "$WORK_DIR" "$OUT_DIR"
  prepare_profile "$profile_copy"

  log_info "Building ISO"
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$profile_copy"
  log_info "ISO output directory: $OUT_DIR"
}

main "$@"
