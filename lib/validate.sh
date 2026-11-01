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
  local root_device target_device

  [[ -d "$target" ]] || die "Target directory does not exist: $target"
  [[ ! "$target" -ef / ]] || die "Target must not be the running root: $target"
  mountpoint -q "$target" || die "Target is not mounted: $target"
  root_device=$(stat -Lc %d -- /) || die "Cannot identify the running root filesystem"
  target_device=$(stat -Lc %d -- "$target") || die "Cannot identify target filesystem: $target"
  [[ "$root_device" =~ ^[0-9]+$ && "$target_device" =~ ^[0-9]+$ ]] ||
    die "Cannot identify root and target filesystems"
  # Device identity also catches bind mounts, including binds of root subdirectories.
  [[ "$target_device" != "$root_device" ]] || die "Target shares the running root filesystem: $target"
}

validate_target_boot_mount() {
  local target=$1

  mountpoint -q "$target/boot" || die "EFI System Partition must be mounted at $target/boot"
}

validate_disk() {
  validated_disk_path "$1" >/dev/null
}

validated_disk_path() {
  local disk=$1
  local disk_type

  [[ "$disk" == /dev/* ]] || die "Disk must be an absolute /dev path: $disk"
  disk=$(readlink -e -- "$disk") || die "Cannot resolve disk: $disk"
  [[ "$disk" == /dev/* ]] || die "Resolved disk must be an absolute /dev path: $disk"
  test -b "$disk" || die "Disk is not a block device: $disk"
  disk_type=$(lsblk -dnro TYPE -- "$disk") || die "Cannot identify disk type: $disk"
  [[ "$disk_type" == disk ]] || die "VM mode requires a whole disk, not a partition or mapped device: $disk"
  printf '%s\n' "$disk"
}

validate_hardware_storage() (
  local mode=$1 target=$2 disk=$3 root_id host_type ancestors host_source
  local root_part boot_part root_disk boot_disk id point mounts descendants value device boot_id
  local esp_files=()

  [[ "$mode" == safe || "$mode" == vm ]] || die 'Invalid storage check mode'
  [[ "$target" == /* && "$target" != *[[:space:]\\]* ]] || die 'Target must be an unambiguous absolute path'
  target=$(readlink -m -- "$target") || die 'Cannot resolve target'
  case "$target/" in
    /boot/* | /efi/* | /dev/* | /proc/* | /sys/* | /etc/* | /usr/* | /var/* | /home/* | /root/* | /opt/* | /run/*)
      die 'Protected target' ;;
  esac
  [[ "$target" != / ]] || die 'Protected target'
  if [[ "$mode" == vm ]]; then
    [[ -d "$target" ]] || die 'VM target must be an existing directory'
    disk=$(validated_disk_path "$disk") || die 'Invalid disk'
    if mountpoint -q "$target"; then
      die 'VM target is already mounted'
    else
      # util-linux uses 32 for a non-mountpoint; errors must not imply unused.
      [[ $? -eq 32 ]] || die 'Cannot establish that VM target is unmounted'
    fi
    root_disk=$disk
    boot_disk=$disk
  else
    validate_target_mount "$target"
    validate_target_boot_mount "$target"
    root_part=$(findmnt -nro SOURCE -M "$target") || die 'Cannot identify target source'
    boot_part=$(findmnt -nro SOURCE -M "$target/boot") || die 'Cannot identify ESP source'
    root_id=$(findmnt -nro MAJ:MIN -M "$target") || die 'Cannot identify root partition'
    boot_id=$(findmnt -nro MAJ:MIN -M "$target/boot") || die 'Cannot identify ESP partition'
    [[ "$root_id" =~ ^[0-9]+:[0-9]+$ && "$boot_id" =~ ^[0-9]+:[0-9]+$ && "$root_id" != "$boot_id" ]] || die 'Root and ESP must have distinct known identities'
    for device in "$root_part" "$boot_part"; do
      [[ "$device" == /dev/* ]] && test -b "$device" || die 'Expected block partition'
      value=$(lsblk -dnro TYPE -- "$device") || die 'Cannot identify partition type'
      [[ "$value" == part ]] || die 'Mapped storage is not supported'
      value=$(lsblk -dnro PTTYPE -- "$device") || die 'Cannot identify partition table'
      [[ "$value" == gpt ]] || die 'GPT is required'
    done
    value=$(findmnt -nro FSTYPE -M "$target") || die 'Cannot identify root filesystem'
    [[ "$value" == ext4 ]] || die 'Root must be ext4'
    value=$(findmnt -nro FSTYPE -M "$target/boot") || die 'Cannot identify ESP filesystem'
    [[ "$value" == vfat ]] || die 'ESP must be FAT'
    value=$(lsblk -dnro FSVER -- "$boot_part") || die 'Cannot identify FAT version'
    [[ "$value" == FAT32 ]] || die 'ESP must be FAT32'
    value=$(lsblk -dnro PARTTYPE -- "$boot_part") || die 'Cannot identify ESP type'
    [[ "${value,,}" == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] || die 'Expected ESP partition type'
    for point in "$target" "$target/boot"; do
      value=$(findmnt -nro FSROOT -M "$point") || die 'Cannot identify mount root'
      [[ "$value" == / ]] || die 'Bind/subdirectory mounts are not supported'
      value=$(findmnt -nro OPTIONS -M "$point") || die 'Cannot identify mount options'
      [[ ",$value," == *,rw,* ]] || die 'Target mounts must already be writable'
    done
    root_disk=$(lsblk -dnpro PKNAME -- "$root_part") || die 'Cannot identify root disk'
    boot_disk=$(lsblk -dnpro PKNAME -- "$boot_part") || die 'Cannot identify ESP disk'
    [[ "$root_disk" == "$boot_disk" ]] || die 'Root and ESP must use the same dedicated disk'
    # Existing boot executables can belong to an offline OS, not just this host.
    shopt -s nullglob globstar nocaseglob
    for device in "$target/boot"/EFI "$target/boot"/EFI/**/*; do
      [[ ! -L "$device" ]] || die 'ESP symlinks require manual review'
    done
    esp_files=("$target/boot"/EFI/**/*.efi)
    [[ ${#esp_files[@]} -eq 0 && ! -e "$target/boot/loader" && ! -L "$target/boot/loader" ]] || die 'Existing bootloader requires manual review'
  fi
  for device in "$root_disk" "$boot_disk"; do
    value=$(lsblk -dnro TYPE -- "$device") || die 'Cannot identify disk type'
    [[ "$value" == disk ]] || die 'Expected a physical disk'
    value=$(lsblk -dnro RO -- "$device") || die 'Cannot identify disk writability'
    [[ "$value" == 0 ]] || die 'Read-only or unknown disk'
    value=$(lsblk -dnro TRAN -- "$device") || die 'Cannot identify transport'
    case "$value" in
      sata | nvme) ;;
      '') [[ "$mode" == vm && "$device" == /dev/vd[a-z]* ]] || die 'Unknown transport' ;;
      *) die 'Unsupported transport' ;;
    esac
  done

  root_id=$(findmnt -nro MAJ:MIN -M /) || die 'Cannot identify host root'
  [[ "$root_id" =~ ^[0-9]+:[0-9]+$ ]] || die 'Unknown host root identity'
  host_source="/dev/block/$root_id"
  if [[ "$root_id" == 0:* ]]; then
    # Arch ISO root is an overlay; protect the physical live-media ancestor.
    host_type=$(findmnt -nro FSTYPE -M /) || die 'Unknown host root type'
    [[ "$host_type" == overlay ]] || die 'Unresolvable host root'
    host_source=$(findmnt -nro SOURCE -M /run/archiso/bootmnt) || die 'Unresolvable live-media ancestry'
  fi
  test -b "$host_source" || die 'Unresolvable host root device'
  value=$(lsblk -snro TYPE -- "$host_source") || die 'Cannot resolve physical host ancestry'
  [[ $'\n'"$value"$'\n' == *$'\ndisk\n'* || $'\n'"$value"$'\n' == *$'\nrom\n'* ]] || die 'Host ancestry has no physical device'
  ancestors=$(lsblk -snrpo NAME -- "$host_source") || die 'Cannot trace host root ancestry'
  [[ -n "$ancestors" ]] || die 'Empty host root ancestry'
  while IFS= read -r device; do
    [[ "$device" != "$root_disk" && "$device" != "$boot_disk" ]] || die 'Selected disk contains the host root or live media'
  done <<< "$ancestors"

  descendants=$(lsblk -nrpo MAJ:MIN -- "$root_disk") || die 'Cannot enumerate disk'
  [[ -n "$descendants" ]] || die 'Empty disk topology'
  value=$(lsblk -nrpo TYPE -- "$root_disk") || die 'Cannot check disk holders'
  while IFS= read -r device; do
    [[ "$device" == disk || "$device" == part ]] || die 'Active mapped devices are not supported'
  done <<< "$value"
  mounts=$(findmnt -rn -o MAJ:MIN,TARGET) || die 'Cannot enumerate mounts'
  [[ -n "$mounts" ]] || die 'Empty mount inventory'
  while read -r id point; do
    [[ "$id" =~ ^[0-9]+:[0-9]+$ && "$point" == /* ]] || die 'Malformed mount inventory'
    if [[ "$mode" == safe && ( "$point" == "$target" || "$point" == "$target/boot" ) ]]; then
      continue
    fi
    [[ "$point" != "$target/"* ]] || die 'Unexpected nested mount'
    while IFS= read -r value; do
      [[ "$value" =~ ^[0-9]+:[0-9]+$ ]] || die 'Invalid disk identity'
      [[ "$id" != "$value" ]] || die 'Disk is mounted outside the target'
    done <<< "$descendants"
  done <<< "$mounts"
  value=$(lsblk -nrpo MOUNTPOINTS -- "$root_disk") || die 'Cannot check active swap'
  [[ "$value" != *'[SWAP]'* ]] || die 'Disk has active swap'
)
