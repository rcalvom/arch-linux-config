#!/usr/bin/env bash
set -euo pipefail

require_vm_commands() {
  require_command lsblk
  require_command wipefs
  require_command sgdisk
  require_command mkfs.fat
  require_command mkfs.ext4
  require_command partprobe
  require_command udevadm
  require_command mount
  require_command umount
}

partition_path() {
  local disk=$1
  local number=$2

  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s\n' "$disk" "$number"
  else
    printf '%s%s\n' "$disk" "$number"
  fi
}

confirm_vm_disk() {
  local disk=$1
  local yes=$2
  local response

  log_warn "VM mode will erase $disk completely."
  log_warn "This mode is intended for VirtualBox, QEMU, VMware, or disposable disks."
  lsblk "$disk"

  if [[ "$yes" -eq 1 ]]; then
    return 0
  fi

  printf 'Type ERASE to continue: '
  read -r response
  [[ "$response" == "ERASE" ]] || die "Disk erase was not confirmed"
}

partition_vm_disk() {
  local disk=$1

  log_info "Partitioning $disk"
  wipefs -a "$disk"
  sgdisk --zap-all "$disk"
  sgdisk -n 1:0:+512M -t 1:EF00 -c 1:"EFI System" "$disk"
  sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux root" "$disk"
  partprobe "$disk"
  udevadm settle
}

format_vm_partitions() {
  local disk=$1
  local efi_part
  local root_part

  efi_part=$(partition_path "$disk" 1)
  root_part=$(partition_path "$disk" 2)

  log_info "Formatting $efi_part as FAT32"
  mkfs.fat -F 32 "$efi_part"

  log_info "Formatting $root_part as ext4"
  mkfs.ext4 -F "$root_part"
}

mount_vm_partitions() {
  local disk=$1
  local target=$2
  local efi_part
  local root_part

  efi_part=$(partition_path "$disk" 1)
  root_part=$(partition_path "$disk" 2)

  log_info "Mounting $root_part at $target"
  install -dm755 "$target"
  mount "$root_part" "$target"

  log_info "Mounting $efi_part at $target/boot"
  install -dm755 "$target/boot"
  mount "$efi_part" "$target/boot"
}
