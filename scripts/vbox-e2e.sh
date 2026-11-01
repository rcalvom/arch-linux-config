#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
MANIFEST=""
KEEP_ON_FAILURE=1
VM_CREATED=0
SUCCESS=0
SNAPSHOT_WORKTREE=0
INSTALL_MODE=vm

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
  --snapshot-worktree    Accept a worktree snapshot instead of requiring clean HEAD.
  --safe                 Test installation on manually prepared virtual partitions.
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
  if [[ "$SUCCESS" -ne 1 ]]; then
    printf 'result=failed\nexit_code=%s\ninstall_mode=%s\n' "$exit_code" "$INSTALL_MODE" > "$E2E_DIR/result"
  fi
  rm -f -- "${TARGET_PASSWORD_FILE:-}"

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
      --snapshot-worktree)
        SNAPSHOT_WORKTREE=1
        shift
        ;;
      --safe)
        INSTALL_MODE=safe
        shift
        ;;
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
  run_logged "$E2E_DIR/recipe-metadata.log" \
    vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" \
    'sudo bash /opt/arch-linux-config/scripts/verify-recipe-metadata.sh'
  if [[ "$INSTALL_MODE" == safe ]]; then
    run_logged "$E2E_DIR/safe-prepare.log" \
      vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" \
      'sudo bash /opt/arch-linux-config/scripts/e2e-prepare-safe.sh --vm --disk /dev/sda'
    run_logged "$E2E_DIR/installer.log" \
      vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
        set -euo pipefail
        archcfg-install --target /mnt --profile virtualbox --hostname archcfg-e2e --username archcfg-e2e --timezone UTC </dev/null
        sudo bash -c '\''set -euo pipefail
          sfdisk --dump /dev/sda > /run/archcfg-safe-after
          cmp /run/archcfg-safe-before /run/archcfg-safe-after
          sha256sum -c /run/archcfg-safe-witnesses
          { printf "archcfg-e2e:"; cat /home/live/target-password; } | arch-chroot /mnt chpasswd
          rm /home/live/target-password
        '\''
      '
    return
  fi
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
        --hostname archcfg-e2e \
        --username archcfg-e2e \
        --timezone UTC \
        --user-password-file /run/archcfg-e2e/user-password
    '
}

capture_live_screen() {
  VBoxManage controlvm "$VM_NAME" screenshotpng "$E2E_DIR/live-screen.png"
  [[ -s "$E2E_DIR/live-screen.png" ]] || vbox_die "Live ISO screenshot was not captured"
}

wait_for_live_services() {
  local deadline=$((SECONDS + 90))

  while ((SECONDS < deadline)); do
    if vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      systemctl is-active --quiet iwd.service
      systemctl is-active --quiet systemd-networkd.service
      systemctl is-active --quiet systemd-resolved.service
      systemctl is-active --quiet host-network-online.service
      systemctl is-active --quiet greetd.service
    ' >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done

  collect_live_network_diagnostics
  vbox_die "Live ISO network services did not become ready within 90 seconds"
}

collect_live_network_diagnostics() {
  run_logged "$E2E_DIR/live-network-diagnostics.log" \
    vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
      systemctl --no-pager --full status iwd.service systemd-networkd.service systemd-resolved.service host-network-online.service greetd.service || true
      journalctl --no-pager -b -u host-network-online.service || true
      ip -4 address show || true
      ip -4 route show || true
      resolvectl status || true
      resolvectl --cache=no --type=A query archlinux.org || true
    ' || true
}

run_live_checks() {
  run_logged "$E2E_DIR/live-runtime.log" \
    vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      exec sudo /usr/bin/bash /opt/arch-linux-config/scripts/e2e-guest-smoke.sh --mode live
    '
}

login_live_desktop() {
  local deadline=$((SECONDS + 120))
  # The shipped greeter preselects live. Its public ISO password is also live.
  VBoxManage controlvm "$VM_NAME" keyboardputstring live
  vbox_console_press_enter "$VM_NAME"
  while ((SECONDS < deadline)); do
    if vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" \
      'pgrep -u live -x Hyprland >/dev/null && systemctl --user is-active --quiet waybar.service && hyprctl -j instances | jq -e "length == 1" >/dev/null' >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  capture_live_screen
  vbox_die 'Live graphical login did not become ready within 120 seconds'
}

prepare_target_ssh() {
  # shellcheck disable=SC2016 # Expressions are evaluated only inside the guest.
  run_logged "$E2E_DIR/target-ssh.log" \
    vbox_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      target=/mnt
      mountpoint -q "$target" || sudo mount /dev/sda2 "$target"
      mountpoint -q "$target/boot" || sudo mount /dev/sda1 "$target/boot"
      cleanup_target_mount() {
        sudo sync
        if ! sudo umount -R "$target"; then
          sudo umount -R -l "$target"
        fi
      }
      trap cleanup_target_mount EXIT
      IFS=: read -r _ _ target_uid target_gid _ < <(grep "^archcfg-e2e:" "$target/etc/passwd")
      [[ -n "$target_uid" && -n "$target_gid" ]]
      sudo install -dm700 -o "$target_uid" -g "$target_gid" "$target/home/archcfg-e2e/.ssh"
      sudo install -m600 -o "$target_uid" -g "$target_gid" /home/live/.ssh/authorized_keys "$target/home/archcfg-e2e/.ssh/authorized_keys"
      sudo systemctl enable --root "$target" sshd.service
    '
}

login_installed_desktop() {
  local deadline=$((SECONDS + 120))
  # The installed la-latin1 console maps the US slash key to a hyphen.
  VBoxManage controlvm "$VM_NAME" keyboardputstring archcfg
  VBoxManage controlvm "$VM_NAME" keyboardputscancode 35 b5
  VBoxManage controlvm "$VM_NAME" keyboardputstring e2e
  sleep 1
  vbox_console_press_enter "$VM_NAME"
  sleep 2
  VBoxManage controlvm "$VM_NAME" keyboardputstring "$(<"$TARGET_PASSWORD_FILE")"
  sleep 1
  vbox_console_press_enter "$VM_NAME"
  while ((SECONDS < deadline)); do
    if vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" \
      'pgrep -u archcfg-e2e -x Hyprland >/dev/null && systemctl --user is-active --quiet waybar.service && systemctl --user is-active --quiet wireplumber.service' >/dev/null 2>&1; then
      run_logged "$E2E_DIR/installed-desktop.log" \
        vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
          set -euo pipefail
          instances=$(hyprctl -j instances)
          test "$(jq length <<< "$instances")" = 1
          export HYPRLAND_INSTANCE_SIGNATURE
          HYPRLAND_INSTANCE_SIGNATURE=$(jq -r ".[0].instance" <<< "$instances")
          hyprctl -j monitors | jq -e "length > 0 and all(.[]; .width > 0 and .height > 0)"
          hyprctl -j configerrors | jq -e '\''type == "array" and all(.[]; . == "")'\''
          test ! -e "$HOME/.config/archcfg/hardware.lua"
          test ! -e "$HOME/.config/archcfg/display-profiles.json"
          printf "PASS: installed graphical login, monitor IPC, zero config errors, generic desktop\n"
        '
      VBoxManage controlvm "$VM_NAME" screenshotpng "$E2E_DIR/installed-screen.png"
      return 0
    fi
    sleep 3
  done
  VBoxManage controlvm "$VM_NAME" screenshotpng "$E2E_DIR/installed-screen.png"
  vbox_die 'Installed graphical login did not become ready within 120 seconds'
}

wait_for_target_services() {
  local deadline=$((SECONDS + 180))

  while ((SECONDS < deadline)); do
    if vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      ping -c 1 -W 3 archlinux.org >/dev/null
      systemctl is-active --quiet iwd.service
      systemctl is-active --quiet systemd-networkd.service
      systemctl is-active --quiet systemd-resolved.service
      systemctl is-active --quiet greetd.service
      systemctl is-active --quiet vboxservice.service
      ! systemctl is-active --quiet NetworkManager.service
      ! systemctl is-enabled --quiet NetworkManager.service
      ! systemctl is-enabled --quiet systemd-networkd-wait-online.service
      ! pacman -Qq networkmanager >/dev/null 2>&1
    ' >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done

  vbox_die "Installed VM services did not become ready within 180 seconds"
}

run_postboot_checks() {
  local hardware_status=0
  run_logged "$E2E_DIR/docker-sudo.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" \
    'sudo -S -p "" bash /opt/arch-linux-config/scripts/e2e-docker.sh archcfg-e2e' < "$TARGET_PASSWORD_FILE"
  run_logged "$E2E_DIR/recipe-tests.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" \
    'bash /opt/arch-linux-config/tests/recipe.sh'
  run_logged "$E2E_DIR/verify-hardware.json" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" \
    'exec bash /opt/arch-linux-config/scripts/verify-hardware.sh --profile virtualbox --json' || hardware_status=$?
  printf 'exit_code=%s\n' "$hardware_status" > "$E2E_DIR/verify-hardware-status"
  case "$hardware_status" in
    0) ;;
    3) vbox_log_warn 'Hardware verification is incomplete (unknown observations); see verify-hardware.json' ;;
    *) return "$hardware_status" ;;
  esac

  run_logged "$E2E_DIR/verify-system.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      exec /usr/bin/bash /opt/arch-linux-config/scripts/verify-system-config.sh \
        --repo /opt/arch-linux-config \
        --root / \
        --profile virtualbox \
        --grub-profile classic
    '

  run_logged "$E2E_DIR/verify-dotfiles.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      exec /usr/bin/bash /opt/arch-linux-config/scripts/verify-dotfiles.sh \
        --repo /opt/arch-linux-config \
        --home /home/archcfg-e2e
    '

  run_logged "$E2E_DIR/runtime.log" \
    vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" '
      set -euo pipefail
      exec /usr/bin/bash /opt/arch-linux-config/scripts/e2e-guest-smoke.sh \
        --mode installed \
        --username archcfg-e2e
    '
}

write_result() {
  {
    printf 'result=passed\n'
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'install_mode=%s\n' "$INSTALL_MODE"
    printf 'source_tree_sha256=%s\n' "$SOURCE_TREE_SHA256"
    printf 'manifest=%s\n' "$MANIFEST"
    printf 'completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$E2E_DIR/result"
  chmod 600 "$E2E_DIR/result"
}

main() {
  local artifact_directory
  local artifact_size
  local manifest_directory
  local schema
  local iso_path
  local iso_directory
  local expected_live_ssh_key
  local expected_checksum
  local actual_checksum

  parse_args "$@"
  [[ -n "$MANIFEST" && -f "$MANIFEST" ]] || vbox_die "--manifest must name an existing file"

  local preflight_args=()
  [[ "$SNAPSHOT_WORKTREE" -ne 1 ]] || preflight_args+=(--snapshot-worktree)
  "$SCRIPT_DIR/vbox-preflight.sh" "${preflight_args[@]}"

  RUN_ID=$(vbox_manifest_value "$MANIFEST" run_id) || vbox_die "Manifest is missing a valid run_id"
  vbox_run_id_is_valid "$RUN_ID" || vbox_die "Manifest contains an invalid run ID: $RUN_ID"
  schema=$(vbox_manifest_value "$MANIFEST" schema) || vbox_die "Manifest is missing a schema version"
  [[ "$schema" == 2 ]] || vbox_die "Unsupported artifact manifest schema: $schema; rebuild with source verification"
  local source_mode base_commit source_checksum
  source_mode=$(vbox_manifest_value "$MANIFEST" source_mode)
  base_commit=$(vbox_manifest_value "$MANIFEST" base_commit)
  [[ "$base_commit" =~ ^[a-f0-9]{40}$ ]] || vbox_die "Invalid base commit"
  case "$source_mode" in
    worktree) [[ "$SNAPSHOT_WORKTREE" -eq 1 ]] || vbox_die "Worktree artifact requires --snapshot-worktree" ;;
    head) [[ "$base_commit" == "$(git -C "$REPO_ROOT" rev-parse HEAD)" ]] || vbox_die "HEAD mismatch" ;;
    *) vbox_die "Invalid source mode" ;;
  esac

  artifact_directory="$ARCHCFG_VBOX_STATE_ROOT/artifacts/$RUN_ID"
  [[ -d "$artifact_directory" ]] || vbox_die "Artifact directory does not exist for run: $RUN_ID"
  artifact_directory=$(cd -- "$artifact_directory" && pwd -P)
  manifest_directory=$(cd -- "$(dirname -- "$MANIFEST")" && pwd -P)
  [[ "$manifest_directory" == "$artifact_directory" && "${MANIFEST##*/}" == manifest ]] || vbox_die "Manifest is outside the managed artifact directory"
  MANIFEST="$manifest_directory/manifest"
  source_checksum=$(vbox_manifest_value "$MANIFEST" source_sha256)
  [[ "$source_checksum" =~ ^[a-f0-9]{64}$ &&
     "$(vbox_file_sha256 "$artifact_directory/source.tar")" == "$source_checksum" ]] || vbox_die "Source archive checksum mismatch"
  SOURCE_TREE_SHA256=$(vbox_manifest_value "$MANIFEST" source_tree_sha256)
  [[ "$SOURCE_TREE_SHA256" =~ ^[a-f0-9]{64}$ ]] || vbox_die "Invalid source tree checksum"

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

  E2E_DIR="$ARCHCFG_VBOX_STATE_ROOT/runs/$RUN_ID/e2e-$INSTALL_MODE"
  VM_NAME="archcfg-e2e-test-$RUN_ID-$INSTALL_MODE"
  TARGET_PASSWORD_FILE="$E2E_DIR/target-password"
  [[ ! -e "$E2E_DIR" ]] || vbox_die "E2E results already exist for run: $RUN_ID"
  vbox_prepare_directory "$E2E_DIR"
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  vbox_generate_password_file "$TARGET_PASSWORD_FILE"

  vbox_log_info "Creating disposable installation VM: $VM_NAME"
  vbox_create_efi_vm "$VM_NAME" 3072 2 24576 "$iso_path"
  VM_CREATED=1
  SSH_PORT=$(vbox_find_ssh_port) || vbox_die "Could not allocate a localhost SSH port"
  vbox_configure_nat_ssh "$VM_NAME" "$SSH_PORT"
  vbox_start_vm "$VM_NAME"
  vbox_wait_for_ssh live "$LIVE_SSH_KEY" "$SSH_PORT" 300 || vbox_die "Live ISO SSH did not become ready"
  capture_live_screen
  vbox_wait_for_ssh_network live "$LIVE_SSH_KEY" "$SSH_PORT" 180 || vbox_die "Live ISO network did not become ready"
  wait_for_live_services
  verify_guest_source live "$E2E_DIR/live-source.log"
  login_live_desktop
  run_live_checks
  capture_live_screen
  vbox_scp_to live "$LIVE_SSH_KEY" "$SSH_PORT" "$TARGET_PASSWORD_FILE" /home/live/target-password
  run_install
  prepare_target_ssh

  vbox_power_off_vm "$VM_NAME"
  vbox_eject_iso "$VM_NAME"
  vbox_start_vm "$VM_NAME"
  vbox_wait_for_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" 300 || vbox_die "Installed system SSH did not become ready"
  wait_for_target_services
  verify_guest_source archcfg-e2e "$E2E_DIR/installed-source.log"
  login_installed_desktop
  if [[ "$INSTALL_MODE" == safe ]]; then
    # shellcheck disable=SC2016 # Read the witness inside the installed guest.
    run_logged "$E2E_DIR/safe-postboot.log" vbox_ssh archcfg-e2e "$LIVE_SSH_KEY" "$SSH_PORT" \
      'test "$(cat /archcfg-safe-witness)" = archcfg-safe-preserve-root'
  fi
  run_postboot_checks
  write_result

  SUCCESS=1
  vbox_log_info "VirtualBox E2E validation passed: $E2E_DIR/result"
}

verify_guest_source() {
  run_logged "$2" vbox_ssh "$1" "$LIVE_SSH_KEY" "$SSH_PORT" "
    set -euo pipefail
    source /opt/arch-linux-config/lib/source-snapshot.sh
    source_tree_verify /opt/arch-linux-config || { printf 'Source snapshot verification failed\\n' >&2; exit 1; }
    test \"\$(cat /opt/arch-linux-config/.archcfg-source.sha256)\" = '$SOURCE_TREE_SHA256'
    printf 'source_tree_sha256=%s\\n' '$SOURCE_TREE_SHA256'
  "
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
