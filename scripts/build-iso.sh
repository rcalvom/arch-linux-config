#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
PROFILE_SOURCE="$REPO_ROOT/live"
OUT_DIR="$REPO_ROOT/out"
WORK_DIR="$REPO_ROOT/work/archiso"
CLEAN=0
FAST=0
FAST_JOBS=""
TEMP_DIR=""
LIVE_AUTHORIZED_KEY_FILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/build-iso.sh [options]

Options:
  --out-dir <path>      ISO output directory. Default: ./out.
  --work-dir <path>     mkarchiso work directory. Default: ./work/archiso.
  --clean               Remove work/output directories before building.
  --fast                Use faster rootfs compression for local test builds.
  --jobs <count>        Limit --fast compression workers. Default: detected CPUs.
  --live-authorized-key-file <path>
                        One-use live SSH public key for VirtualBox E2E automation.
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
      --jobs)
        require_value "$1" "${2-}"
        FAST_JOBS=$2
        shift 2
        ;;
      --live-authorized-key-file)
        require_value "$1" "${2-}"
        LIVE_AUTHORIZED_KEY_FILE=$2
        shift 2
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

  if [[ -n "$FAST_JOBS" && "$FAST" -ne 1 ]]; then
    die "--jobs is only valid with --fast"
  fi

  if [[ -n "$FAST_JOBS" && ( ! "$FAST_JOBS" =~ ^[0-9]+$ || "$FAST_JOBS" -lt 1 ) ]]; then
    die "--jobs must be a positive integer"
  fi

  if [[ -n "$LIVE_AUTHORIZED_KEY_FILE" ]]; then
    local key_lines=()

    [[ -f "$LIVE_AUTHORIZED_KEY_FILE" && ! -L "$LIVE_AUTHORIZED_KEY_FILE" ]] || die "Live authorized key file must be a regular file: $LIVE_AUTHORIZED_KEY_FILE"
    mapfile -t key_lines < "$LIVE_AUTHORIZED_KEY_FILE"
    [[ "${#key_lines[@]}" -eq 1 && "${key_lines[0]}" =~ ^ssh-ed25519[[:space:]][A-Za-z0-9+/=]+[[:space:]]archcfg-e2e$ ]] || die "Live authorized key file must contain one archcfg-ed25519 key"
  fi
}

detect_worker_count() {
  local workers

  if [[ -n "$FAST_JOBS" ]]; then
    workers=$FAST_JOBS
  elif command -v nproc >/dev/null 2>&1; then
    workers=$(nproc 2>/dev/null || printf '1')
  else
    workers=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
  fi

  if [[ ! "$workers" =~ ^[0-9]+$ || "$workers" -lt 1 ]]; then
    workers=1
  fi

  printf '%s\n' "$workers"
}

cleanup_temp_dir() {
  if [[ -n "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
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

disable_system_service_in_profile() {
  local profile_dir=$1
  local service=$2
  local service_path="$profile_dir/airootfs/etc/systemd/system/$service"

  install -dm755 "$(dirname -- "$service_path")"
  ln -sfn /dev/null "$service_path"
}

enable_system_service_in_profile() {
  local profile_dir=$1
  local service=$2
  local wants_dir="$profile_dir/airootfs/etc/systemd/system/multi-user.target.wants"

  install -dm755 "$wants_dir"
  ln -sfn "/usr/lib/systemd/system/$service" "$wants_dir/$service"
}

install_live_authorized_key() {
  local profile_dir=$1
  local ssh_dir="$profile_dir/airootfs/home/live/.ssh"

  [[ -n "$LIVE_AUTHORIZED_KEY_FILE" ]] || return 0
  install -dm700 "$ssh_dir"
  install -m600 "$LIVE_AUTHORIZED_KEY_FILE" "$ssh_dir/authorized_keys"
  chown -R 1000:1000 "$ssh_dir"
  enable_system_service_in_profile "$profile_dir" sshd.service
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
  install_live_authorized_key "$profile_copy"

  rm -rf "$bundled_repo"
  copy_committed_repo_tree "$bundled_repo"
  chmod +x \
    "$bundled_repo/install.sh" \
    "$bundled_repo/postinstall.sh" \
    "$bundled_repo/installation/archlinux.sh" \
    "$bundled_repo/scripts/build-iso.sh"

  enable_system_service_in_profile "$profile_copy" NetworkManager.service
  enable_system_service_in_profile "$profile_copy" bluetooth.service
  enable_system_service_in_profile "$profile_copy" greetd.service
  enable_system_service_in_profile "$profile_copy" vboxservice.service
  disable_system_service_in_profile "$profile_copy" getty@tty1.service
}

main() {
  local profile_copy

  parse_args "$@"

  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run this script as root"
  require_command mkarchiso
  require_command git
  require_command tar

  TEMP_DIR=$(mktemp -d)
  trap cleanup_temp_dir EXIT
  profile_copy="$TEMP_DIR/profile"
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
