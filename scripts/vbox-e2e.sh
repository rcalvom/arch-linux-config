#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
MANIFEST=""
KEEP_ON_FAILURE=1
VM_CREATED=0
SUCCESS=0

# shellcheck source=../lib/vbox.sh
source "$REPO_ROOT/lib/vbox.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/vbox-e2e.sh --manifest <path> [options]

Boots an ISO produced by vbox-build.sh, installs it to a new disposable EFI
VirtualBox disk, then validates the installed configuration through Guest
SSH. The test never modifies pre-existing VMs.

Options:
  --manifest <path>      Artifact manifest emitted by scripts/vbox-build.sh.
  --discard-on-failure   Delete the test VM instead of retaining it for diagnosis.
  --help                 Print this help.
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
  rm -f -- "${LIVE_SSH_KEY:-}" "${LIVE_SSH_KEY:-}.pub" "${TARGET_PASSWORD_FILE:-}"

  if [[ "$VM_CREATED" -eq 1 ]]; then
    vbox_power_off_vm "$VM_NAME" || true
    vbox_collect_vm_evidence "$VM_NAME" "$E2E_DIR/vm-evidence"
    if [[ "$SUCCESS" -eq 1 || "$KEEP_ON_FAILURE" -eq 0 ]]; then
      vbox_remove_managed_vm "$VM_NAME" || true
    else
      install -dm700 "$ARCHCFG_VBOX_STATE_ROOT/failures/$RUN_ID"
      cp -a "$E2E_DIR/." "$ARCHCFG_VBOX_STATE_ROOT/failures/$RUN_ID/"
      vbox_log_warn "Test VM retained for diagnosis: $VM_NAME"
    fi
  fi

  exit "$exit_code"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --manifest)
        require_value "$1" "${2-}"
        MANIFEST=$2
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

run_install() {
  run_logged "$E2E_DIR/installer.log" \
    vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      sudo install -dm700 -o root -g root /run/archcfg-e2e
      sudo install -m600 -o root -g root /home/live/target-password /run/archcfg-e2e/user-password
      rm -f -- /home/live/target-password
      archcfg-install \
        --vm \
        --disk /dev/sda \
        --yes \
        --profile virtualbox \
        --wifi-interface none \
        --hostname archcfg-e2e \
        --username archcfg-e2e \
        --timezone UTC \
        --user-password-file /run/archcfg-e2e/user-password
    '
}

prepare_target_ssh() {
  run_logged "$E2E_DIR/target-ssh.log" \
    vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      target=/mnt
      sudo mount /dev/sda2 "$target"
      sudo mount /dev/sda1 "$target/boot"
      cleanup_target_mount() {
        sudo umount -R "$target" || true
      }
      trap cleanup_target_mount EXIT
      IFS=: read -r _ _ target_uid target_gid _ < <(grep "^archcfg-e2e:" "$target/etc/passwd")
      [[ -n "$target_uid" && -n "$target_gid" ]]
      sudo install -dm700 -o "$target_uid" -g "$target_gid" "$target/home/archcfg-e2e/.ssh"
      sudo install -m600 -o "$target_uid" -g "$target_gid" /home/live/.ssh/authorized_keys "$target/home/archcfg-e2e/.ssh/authorized_keys"
      sudo systemctl enable --root "$target" sshd.service
    '
}

wait_for_target_services() {
  local deadline=$((SECONDS + 180))

  while ((SECONDS < deadline)); do
    if vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      ping -c 1 -W 3 archlinux.org >/dev/null
      systemctl is-active --quiet NetworkManager.service
      systemctl is-active --quiet greetd.service
      systemctl is-active --quiet vboxservice.service
    ' >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done

  vbox_die "Installed VM services did not become ready within 180 seconds"
}

run_postboot_checks() {
  run_logged "$E2E_DIR/verify-system.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      exec /opt/arch-linux-config/scripts/verify-system-config.sh \
        --repo /opt/arch-linux-config \
        --root / \
        --profile virtualbox \
        --wifi-interface none \
        --grub-profile graphical
    '

  run_logged "$E2E_DIR/verify-dotfiles.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      exec /opt/arch-linux-config/scripts/verify-dotfiles.sh \
        --repo /opt/arch-linux-config \
        --home /home/archcfg-e2e
    '

  run_logged "$E2E_DIR/runtime.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      test -d /sys/firmware/efi
      findmnt -no FSTYPE /boot | grep -qx vfat
      getent passwd archcfg-e2e >/dev/null
      ping -c 1 -W 3 archlinux.org >/dev/null
      systemctl is-active --quiet NetworkManager.service
      systemctl is-active --quiet greetd.service
      systemctl is-active --quiet vboxservice.service
    '
}

write_result() {
  {
    printf 'result=passed\n'
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'manifest=%s\n' "$MANIFEST"
    printf 'completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$E2E_DIR/result"
  chmod 600 "$E2E_DIR/result"
}

main() {
  local artifact_commit
  local artifact_directory
  local artifact_size
  local current_commit
  local manifest_directory
  local schema
  local iso_path
  local iso_directory
  local expected_live_ssh_key
  local expected_checksum
  local actual_checksum

  parse_args "$@"
  [[ -n "$MANIFEST" && -f "$MANIFEST" ]] || vbox_die "--manifest must name an existing file"

  "$SCRIPT_DIR/vbox-preflight.sh"

  RUN_ID=$(vbox_manifest_value "$MANIFEST" run_id) || vbox_die "Manifest is missing a valid run_id"
  vbox_run_id_is_valid "$RUN_ID" || vbox_die "Manifest contains an invalid run ID: $RUN_ID"
  schema=$(vbox_manifest_value "$MANIFEST" schema) || vbox_die "Manifest is missing a schema version"
  [[ "$schema" == 1 ]] || vbox_die "Unsupported artifact manifest schema: $schema"
  artifact_commit=$(vbox_manifest_value "$MANIFEST" commit) || vbox_die "Manifest is missing a commit"
  [[ "$artifact_commit" =~ ^[[:xdigit:]]{40}$ ]] || vbox_die "Manifest contains an invalid commit"
  current_commit=$(git -C "$REPO_ROOT" rev-parse HEAD)
  [[ "$artifact_commit" == "$current_commit" ]] || vbox_die "Manifest commit does not match the current checkout"

  artifact_directory="$ARCHCFG_VBOX_STATE_ROOT/artifacts/$RUN_ID"
  [[ -d "$artifact_directory" ]] || vbox_die "Artifact directory does not exist for run: $RUN_ID"
  artifact_directory=$(cd -- "$artifact_directory" && pwd -P)
  manifest_directory=$(cd -- "$(dirname -- "$MANIFEST")" && pwd -P)
  [[ "$manifest_directory" == "$artifact_directory" && "${MANIFEST##*/}" == manifest ]] || vbox_die "Manifest is outside the managed artifact directory"
  MANIFEST="$manifest_directory/manifest"

  iso_path=$(vbox_manifest_value "$MANIFEST" iso) || vbox_die "Manifest is missing an ISO path"
  expected_checksum=$(vbox_manifest_value "$MANIFEST" iso_sha256) || vbox_die "Manifest is missing an ISO checksum"
  artifact_size=$(vbox_manifest_value "$MANIFEST" iso_size) || vbox_die "Manifest is missing an ISO size"
  [[ "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]] || vbox_die "Manifest contains an invalid ISO checksum"
  [[ "$artifact_size" =~ ^[0-9]+$ ]] || vbox_die "Manifest contains an invalid ISO size"
  [[ -r "$iso_path" && -f "$iso_path" && ! -L "$iso_path" ]] || vbox_die "ISO artifact is not a readable regular file: $iso_path"
  iso_directory=$(cd -- "$(dirname -- "$iso_path")" && pwd -P)
  iso_path="$iso_directory/${iso_path##*/}"
  [[ "$iso_path" == "$artifact_directory/"* ]] || vbox_die "ISO artifact is outside the managed artifact directory"
  [[ "$(stat -c '%s' -- "$iso_path")" == "$artifact_size" ]] || vbox_die "ISO size does not match its manifest"
  actual_checksum=$(vbox_file_sha256 "$iso_path")
  [[ "$actual_checksum" == "$expected_checksum" ]] || vbox_die "ISO checksum does not match its manifest"

  LIVE_SSH_KEY=$(vbox_manifest_value "$MANIFEST" live_ssh_key) || vbox_die "Manifest is missing the live SSH key path"
  expected_live_ssh_key="$ARCHCFG_VBOX_STATE_ROOT/runs/$RUN_ID/live-ssh-key"
  [[ "$LIVE_SSH_KEY" == "$expected_live_ssh_key" && -f "$LIVE_SSH_KEY" && ! -L "$LIVE_SSH_KEY" ]] || vbox_die "Live SSH key is outside the managed run state"
  [[ "$(stat -c '%a' -- "$LIVE_SSH_KEY")" == 600 ]] || vbox_die "Live SSH key must have mode 0600"

  E2E_DIR="$ARCHCFG_VBOX_STATE_ROOT/runs/$RUN_ID/e2e"
  VM_NAME="archcfg-e2e-test-$RUN_ID"
  TARGET_PASSWORD_FILE="$E2E_DIR/target-password"
  [[ ! -e "$E2E_DIR" ]] || vbox_die "E2E results already exist for run: $RUN_ID"
  vbox_prepare_directory "$E2E_DIR"
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  vbox_generate_password_file "$TARGET_PASSWORD_FILE"

  vbox_log_info "Creating disposable installation VM: $VM_NAME"
  vbox_create_efi_vm "$VM_NAME" 2048 2 24576 "$iso_path"
  VM_CREATED=1
  SSH_PORT=$(vbox_find_ssh_port) || vbox_die "Could not allocate a localhost SSH port"
  vbox_configure_nat_ssh "$VM_NAME" "$SSH_PORT"
  vbox_start_vm "$VM_NAME"
  vbox_wait_for_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" 300 || vbox_die "Live ISO SSH did not become ready"
  vbox_wait_for_ssh_network live "$LIVE_SSH_KEY" "$SSH_PORT" 180 || vbox_die "Live ISO network did not become ready"
  vbox_scp_to live "$LIVE_SSH_KEY" "$SSH_PORT" "$TARGET_PASSWORD_FILE" /home/live/target-password
  run_install
  prepare_target_ssh

  vbox_power_off_vm "$VM_NAME"
  vbox_eject_iso "$VM_NAME"
  vbox_start_vm "$VM_NAME"
  vbox_wait_for_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" 300 || vbox_die "Installed system SSH did not become ready"
  wait_for_target_services
  run_postboot_checks
  write_result

  SUCCESS=1
  vbox_log_info "VirtualBox E2E validation passed: $E2E_DIR/result"
}

main "$@"
