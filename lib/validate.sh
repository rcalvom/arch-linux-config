#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run this script as root"
  fi
}

require_command() {
  local command_name=$1

  command -v "$command_name" >/dev/null 2>&1 || die "Missing required command: $command_name"
}

validate_internet() {
  log_info "Checking internet connection"
  ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 || die "Internet connection check failed"
}

validate_profile() {
  local profile=$1

  case "$profile" in
    minimal | desktop | developer | virtualbox)
      ;;
    *)
      die "Invalid profile: $profile. Expected minimal, desktop, developer, or virtualbox"
      ;;
  esac
}

validate_uefi() {
  [[ -d /sys/firmware/efi/efivars ]] || die "Only UEFI installations are supported right now"
}

validate_target_mount() {
  local target=$1

  [[ -d "$target" ]] || die "Target directory does not exist: $target"
  mountpoint -q "$target" || die "Target is not mounted: $target"
}

validate_target_boot_mount() {
  local target=$1

  mountpoint -q "$target/boot" || die "EFI System Partition must be mounted at $target/boot"
}

validate_disk() {
  local disk=$1

  [[ "$disk" == /dev/* ]] || die "Disk must be an absolute /dev path: $disk"
  [[ -b "$disk" ]] || die "Disk is not a block device: $disk"
}
