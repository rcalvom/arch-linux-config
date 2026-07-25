#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BOOTSTRAP_ISO=""
RUN_ID=""
KEEP_ON_FAILURE=1
VM_CREATED=0
SUCCESS=0

# shellcheck source=../lib/vbox.sh
source "$REPO_ROOT/lib/vbox.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/vbox-build.sh --bootstrap-iso <path> [options]

Builds the live ISO inside a disposable local VirtualBox VM. The bootstrap ISO
must be an official Arch ISO with its automatic root console login.

Options:
  --bootstrap-iso <path>  Official Arch ISO used only as the builder environment.
  --run-id <id>           Safe lowercase run identifier. Default: generated.
  --discard-on-failure    Delete the builder VM instead of retaining it for diagnosis.
  --help                  Print this help.
USAGE
}

require_value() {
  local flag=$1
  local value=${2-}

  [[ -n "$value" && "$value" != --* ]] || vbox_die "$flag requires a value"
}

run_logged() {
  local log_file=$1

  shift
  "$@" > >(tee "$log_file") 2> >(tee -a "$log_file" >&2)
}

cleanup() {
  local exit_code=$?

  trap - EXIT HUP INT TERM
  set +e
  rm -f -- "${BUILDER_SSH_KEY:-}" "${BUILDER_SSH_KEY:-}.pub" "${LIVE_AUTHORIZED_KEY_FILE:-}"
  if [[ "$SUCCESS" -ne 1 ]]; then
    rm -f -- "${LIVE_SSH_KEY:-}" "${LIVE_SSH_KEY:-}.pub"
  fi

  if [[ "$VM_CREATED" -eq 1 ]]; then
    vbox_power_off_vm "$VM_NAME" || true
    vbox_collect_vm_evidence "$VM_NAME" "$RUN_DIR/vm-evidence"
    if [[ "$SUCCESS" -eq 1 || "$KEEP_ON_FAILURE" -eq 0 ]]; then
      vbox_remove_managed_vm "$VM_NAME" || true
    else
      install -dm700 "$ARCHCFG_VBOX_STATE_ROOT/failures/$RUN_ID"
      cp -a "$RUN_DIR/." "$ARCHCFG_VBOX_STATE_ROOT/failures/$RUN_ID/"
      vbox_log_warn "Builder VM retained for diagnosis: $VM_NAME"
    fi
  fi

  if [[ "$SUCCESS" -eq 1 ]]; then
    rm -f -- "$SOURCE_ARCHIVE"
  fi

  exit "$exit_code"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bootstrap-iso)
        require_value "$1" "${2-}"
        BOOTSTRAP_ISO=$2
        shift 2
        ;;
      --run-id)
        require_value "$1" "${2-}"
        RUN_ID=$2
        shift 2
        ;;
      --discard-on-failure)
        KEEP_ON_FAILURE=0
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        vbox_die "Unknown argument: $1"
        ;;
    esac
  done
}

prepare_builder_disk() {
  run_logged "$RUN_DIR/builder-prepare.log" \
    vbox_ssh root "$BUILDER_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      wipefs -a /dev/sda
      sgdisk --zap-all /dev/sda
      sgdisk -n 1:0:0 -t 1:8300 -c 1:archcfg-builder /dev/sda
      partprobe /dev/sda
      udevadm settle
      mkfs.ext4 -F /dev/sda1
      install -dm755 /mnt/archcfg-builder
      mount /dev/sda1 /mnt/archcfg-builder
      install -dm755 /mnt/archcfg-builder/root
      fallocate -l 4G /mnt/archcfg-builder/swapfile
      chmod 600 /mnt/archcfg-builder/swapfile
      mkswap /mnt/archcfg-builder/swapfile
      swapon /mnt/archcfg-builder/swapfile
      pacman-key --init
      pacman-key --populate
      reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
      grep -q "^Server" /etc/pacman.d/mirrorlist
      install -dm700 /mnt/archcfg-builder/root/etc/pacman.d/gnupg
      pacman-key --gpgdir /mnt/archcfg-builder/root/etc/pacman.d/gnupg --init
      pacman-key --gpgdir /mnt/archcfg-builder/root/etc/pacman.d/gnupg --populate
      pacstrap -K /mnt/archcfg-builder/root base archiso grub git
    '
}

build_iso_in_guest() {
  run_logged "$RUN_DIR/builder-build.log" \
    vbox_ssh root "$BUILDER_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      install -dm755 /mnt/archcfg-builder/root/opt/archcfg-source
      tar -xf /mnt/archcfg-builder/source.tar -C /mnt/archcfg-builder/root/opt/archcfg-source
      cleanup_builder_root() {
        swapoff /mnt/archcfg-builder/swapfile || true
        umount /mnt/archcfg-builder/root || true
      }
      trap cleanup_builder_root EXIT
      mount --bind /mnt/archcfg-builder/root /mnt/archcfg-builder/root
      arch-chroot /mnt/archcfg-builder/root /usr/bin/bash /opt/archcfg-source/scripts/build-iso.sh \
        --clean \
        --fast \
        --jobs 1 \
        --live-authorized-key-file /opt/live-authorized-key.pub \
        --work-dir /var/lib/archcfg-builder/work \
        --out-dir /var/lib/archcfg-builder/out
    '
}

write_manifest() {
  local manifest="$ARTIFACT_DIR/manifest"
  local commit
  local source_checksum
  local iso_checksum
  local iso_size

  commit=$(git -C "$REPO_ROOT" rev-parse HEAD)
  source_checksum=$(vbox_file_sha256 "$SOURCE_ARCHIVE")
  iso_checksum=$(vbox_file_sha256 "$ISO_PATH")
  iso_size=$(stat -c '%s' -- "$ISO_PATH")

  {
    printf 'schema=1\n'
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'commit=%s\n' "$commit"
    printf 'source_sha256=%s\n' "$source_checksum"
    printf 'iso=%s\n' "$ISO_PATH"
    printf 'iso_sha256=%s\n' "$iso_checksum"
    printf 'iso_size=%s\n' "$iso_size"
    printf 'live_ssh_key=%s\n' "$LIVE_SSH_KEY"
    printf 'created_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$manifest"
  chmod 600 "$manifest"
}

main() {
  local iso_files=()

  parse_args "$@"
  [[ -n "$BOOTSTRAP_ISO" ]] || vbox_die "--bootstrap-iso is required"
  [[ -r "$BOOTSTRAP_ISO" && -f "$BOOTSTRAP_ISO" ]] || vbox_die "Bootstrap ISO is not readable: $BOOTSTRAP_ISO"

  "$SCRIPT_DIR/vbox-preflight.sh"

  [[ -n "$RUN_ID" ]] || RUN_ID=$(vbox_new_run_id)
  vbox_run_id_is_valid "$RUN_ID" || vbox_die "Invalid run ID: $RUN_ID"

  RUN_DIR="$ARCHCFG_VBOX_STATE_ROOT/runs/$RUN_ID"
  ARTIFACT_DIR="$ARCHCFG_VBOX_STATE_ROOT/artifacts/$RUN_ID"
  VM_NAME="archcfg-e2e-build-$RUN_ID"
  SOURCE_ARCHIVE="$RUN_DIR/source.tar"
  BUILDER_SSH_KEY="$RUN_DIR/builder-ssh-key"
  LIVE_SSH_KEY="$RUN_DIR/live-ssh-key"
  LIVE_AUTHORIZED_KEY_FILE="$RUN_DIR/live-authorized-key.pub"

  [[ ! -e "$RUN_DIR" && ! -e "$ARTIFACT_DIR" ]] || vbox_die "Run ID already exists: $RUN_ID"
  vbox_prepare_directory "$RUN_DIR"
  vbox_prepare_directory "$ARTIFACT_DIR"
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  git -C "$REPO_ROOT" archive --format=tar HEAD > "$SOURCE_ARCHIVE"
  chmod 600 "$SOURCE_ARCHIVE"
  vbox_generate_ssh_key "$BUILDER_SSH_KEY"
  vbox_generate_ssh_key "$LIVE_SSH_KEY"
  install -m600 "$LIVE_SSH_KEY.pub" "$LIVE_AUTHORIZED_KEY_FILE"

  vbox_log_info "Creating disposable builder VM: $VM_NAME"
  vbox_create_efi_vm "$VM_NAME" 3072 2 51200 "$BOOTSTRAP_ISO"
  VM_CREATED=1
  SSH_PORT=$(vbox_find_ssh_port) || vbox_die "Could not allocate a localhost SSH port"
  vbox_configure_nat_ssh "$VM_NAME" "$SSH_PORT"
  vbox_start_vm "$VM_NAME"
  vbox_bootstrap_official_ssh "$VM_NAME" "$BUILDER_SSH_KEY" "$SSH_PORT" 300 || vbox_die "Official ISO SSH bootstrap did not become ready"
  vbox_wait_for_ssh_network root "$BUILDER_SSH_KEY" "$SSH_PORT" 180 || vbox_die "Official ISO network did not become ready"

  prepare_builder_disk
  vbox_scp_to root "$BUILDER_SSH_KEY" "$SSH_PORT" "$SOURCE_ARCHIVE" /mnt/archcfg-builder/source.tar
  vbox_scp_to root "$BUILDER_SSH_KEY" "$SSH_PORT" "$LIVE_AUTHORIZED_KEY_FILE" /mnt/archcfg-builder/root/opt/live-authorized-key.pub
  build_iso_in_guest
  vbox_scp_from root "$BUILDER_SSH_KEY" "$SSH_PORT" /mnt/archcfg-builder/root/var/lib/archcfg-builder/out "$ARTIFACT_DIR/out"

  shopt -s globstar nullglob
  iso_files=("$ARTIFACT_DIR"/**/*.iso)
  shopt -u globstar nullglob
  [[ "${#iso_files[@]}" -eq 1 ]] || vbox_die "Expected exactly one ISO artifact, found ${#iso_files[@]}"
  ISO_PATH=${iso_files[0]}
  write_manifest

  SUCCESS=1
  vbox_log_info "ISO artifact: $ISO_PATH"
  vbox_log_info "Manifest: $ARTIFACT_DIR/manifest"
}

main "$@"
