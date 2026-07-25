#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DEST="/opt/arch-linux-config"
MOUNTED_BY_INSTALLER=0
PASSWORD_FILE_VALIDATED=0
PASSWORD_FILE_STAGED=0

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/args.sh
source "$SCRIPT_DIR/lib/args.sh"
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=lib/network.sh
source "$SCRIPT_DIR/lib/network.sh"
# shellcheck source=lib/disk.sh
source "$SCRIPT_DIR/lib/disk.sh"
# shellcheck source=scripts/packages.sh
source "$SCRIPT_DIR/scripts/packages.sh"
# shellcheck source=lib/install.sh
source "$SCRIPT_DIR/lib/install.sh"

parse_args "$@"

cleanup() {
  local exit_code=$?

  trap - EXIT HUP INT TERM
  set +e
  if [[ "$PASSWORD_FILE_VALIDATED" -eq 1 ]]; then
    rm -f -- "$USER_PASSWORD_FILE"
  fi

  if [[ "$PASSWORD_FILE_STAGED" -eq 1 ]]; then
    rm -f -- "$TARGET/root/.archcfg-user-password"
  fi

  if [[ "$exit_code" -ne 0 && "$MOUNTED_BY_INSTALLER" -eq 1 ]] && mountpoint -q "$TARGET"; then
    log_warn "Installation failed; unmounting $TARGET"
    umount -R "$TARGET"
  fi

  exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

main() {
  require_root
  validate_profile "$PROFILE"
  wifi_interface_name_is_valid "$WIFI_INTERFACE" || [[ "$WIFI_INTERFACE" == "auto" || "$WIFI_INTERFACE" == "none" ]] || die "Invalid Wi-Fi interface: $WIFI_INTERFACE"
  if [[ -n "$USER_PASSWORD_FILE" ]]; then
    validate_user_password_file "$USER_PASSWORD_FILE"
    PASSWORD_FILE_VALIDATED=1
  fi
  validate_uefi
  validate_internet
  refresh_mirrors_if_available
  require_command pacstrap
  require_command pacman-key
  require_command genfstab
  require_command arch-chroot

  if [[ "$VM_MODE" -eq 1 ]]; then
    validate_disk "$DISK"
    require_vm_commands
    confirm_vm_disk "$DISK" "$YES"
    unmount_vm_disk_mounts "$DISK"
    partition_vm_disk "$DISK"
    format_vm_partitions "$DISK"
    MOUNTED_BY_INSTALLER=1
    mount_vm_partitions "$DISK" "$TARGET"
  else
    validate_target_mount "$TARGET"
    validate_target_boot_mount "$TARGET"
  fi

  install_base_system "$TARGET" "$SCRIPT_DIR"
  generate_fstab "$TARGET"
  copy_repo_to_target "$SCRIPT_DIR" "$TARGET" "$REPO_DEST"
  write_user_password_file "$TARGET" "$INSTALL_USERNAME" "$USER_PASSWORD_FILE"
  run_postinstall "$TARGET" "$REPO_DEST" "$PROFILE" "$INSTALL_HOSTNAME" "$INSTALL_USERNAME" "$TIMEZONE" "$ENABLE_AUR" "$WIFI_INTERFACE"
  PASSWORD_FILE_STAGED=0

  if [[ "$MOUNTED_BY_INSTALLER" -eq 1 ]]; then
    log_info "Unmounting $TARGET"
    umount -R "$TARGET"
    MOUNTED_BY_INSTALLER=0
    PASSWORD_FILE_STAGED=0
  fi

  log_info "Installation finished"
  log_info "Reboot with: reboot"
}

main
