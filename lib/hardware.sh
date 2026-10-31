#!/usr/bin/env bash
set -euo pipefail

# Probe functions have no fixture/environment overrides in production.
hardware_arch() { uname -m; }
hardware_uefi() { [[ -d /sys/firmware/efi/efivars ]]; }

hardware_secure_boot() {
  local value
  hardware_uefi || { printf 'unknown\n'; return; }
  value=$(od -An -tu1 -j4 -N2 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null) || {
    printf 'unknown\n'; return;
  }
  case "${value//[[:space:]]/}" in
    0) printf 'off\n' ;;
    1) printf 'on\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

hardware_gpu_vendors() {
  local device class vendor
  [[ -d /sys/bus/pci/devices ]] || return 1
  for device in /sys/bus/pci/devices/*; do
    [[ -r "$device/class" ]] || continue
    read -r class < "$device/class" || return 1
    [[ "$class" == 0x03* ]] || continue
    read -r vendor < "$device/vendor" || return 1
    printf '%s\n' "$vendor"
  done
  return 0
}

hardware_platform_check() {
  local mode=${1:-install} status=0 vendors vendor count=0 nvidia=0 other=0
  local architecture secure severity=unsupported
  [[ "$mode" != host ]] || severity=warning
  architecture=$(hardware_arch) || architecture=unknown
  secure=$(hardware_secure_boot) || secure=unknown
  if [[ "$architecture" != x86_64 ]]; then
    printf '[%s] architecture: only x86_64 is in installation scope\n' "$severity"
    status=1
  else
    printf '[supported] architecture: x86_64\n'
  fi
  case "$secure" in
    off) printf '[supported] firmware: UEFI, Secure Boot off\n' ;;
    on) printf '[%s] firmware: Secure Boot enabled; signed boot is not implemented\n' "$severity"; status=1 ;;
    *) printf '[%s] firmware: BIOS or unreadable/unknown Secure Boot; refusing to guess\n' "$severity"; status=1 ;;
  esac
  vendors=$(hardware_gpu_vendors) || vendors=unknown
  while IFS= read -r vendor; do
    [[ -n "$vendor" ]] || continue
    count=$((count + 1))
    case "$vendor" in
      0x8086 | 0x1002) ;;
      0x10de) nvidia=1 ;;
      *) other=1 ;;
    esac
  done <<< "$vendors"
  if [[ $nvidia -eq 1 ]]; then
    printf '[warning] graphics: NVIDIA (possibly hybrid); driver and display setup require manual validation\n'
  elif [[ $other -eq 1 || $count -eq 0 ]]; then
    printf '[warning] graphics: virtual, absent or unknown GPU; desktop compatibility is unverified\n'
  else
    printf '[warning] graphics: Intel/AMD detected; integrated vs discrete and working outputs are not proven\n'
  fi
  # PCI vendor IDs cannot prove integrated graphics or a working desktop.
  [[ $status -eq 1 && "$mode" != host ]] || status=2
  printf '[warning] detection is not installation, boot or hardware test evidence\n'
  return "$status"
}

# Keep diagnostics categorical: device aliases can contain serials or UUIDs.
hardware_preflight() {
  local mode=$1 target=${2-} disk=${3-} status=0 command_name
  local dependencies=(uname od)
  [[ "$mode" == host ]] || dependencies+=(findmnt lsblk readlink stat mountpoint)
  for command_name in "${dependencies[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      if [[ "$mode" == host ]]; then
        printf '[warning] missing read-only probe dependency: %s\n' "$command_name"
        continue
      fi
      printf '[unsupported] missing read-only probe dependency: %s\n' "$command_name"
      return 1
    fi
  done
  hardware_platform_check "$mode" || status=$?
  if [[ "$mode" != host ]]; then
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
      printf '[unsupported] target/device checks require root\n'
      return 1
    fi
    # Subshell contains legacy validators that exit; suppress their path output.
    if (validate_hardware_storage "$mode" "$target" "$disk") >/dev/null 2>&1; then
      printf '[supported] storage: explicit, isolated target within the initial layout policy\n'
    else
      printf '[unsupported] storage: unsafe, shared, busy, unsupported layout or unverifiable device ancestry\n'
      printf '[unsupported] require dedicated GPT/ext4 root and FAT32 ESP, or an unused explicit VM disk; see docs/hardware-support.md\n'
      status=1
    fi
  else
    printf '[warning] host inventory only: no installation target or disk safety has been checked\n'
    [[ $status -eq 1 ]] || status=2
  fi
  return "$status"
}
