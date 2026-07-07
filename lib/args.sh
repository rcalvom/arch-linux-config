#!/usr/bin/env bash
set -euo pipefail

TARGET="/mnt"
PROFILE="developer"
VM_MODE=0
DISK=""
YES=0
ENABLE_AUR=0
INSTALL_HOSTNAME="archlinux"
INSTALL_USERNAME="ricardo"
TIMEZONE="America/Bogota"

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Options:
  --target <path>       Target mount point. Default: /mnt.
  --profile <name>      Installation profile: minimal, desktop, developer, virtualbox.
                        Default: developer.
  --vm                  Enable automatic VM/disk installation mode.
  --disk <device>       Disk to wipe and install to in VM mode.
  --yes                 Skip disk erase confirmation. Only valid with --vm.
  --aur                 Install optional AUR packages for the selected profile.
  --hostname <name>     Hostname. Default: archlinux.
  --username <name>     Initial user. Default: ricardo.
  --timezone <zone>     Timezone. Default: America/Bogota.
  --help                Print this help.

Examples:
  sudo ./install.sh --target /mnt --profile developer
  sudo ./install.sh --vm --disk /dev/sda --profile developer
  sudo ./install.sh --vm --disk /dev/sda --profile developer --yes
USAGE
}

require_arg_value() {
  local flag=$1
  local value=${2-}

  if [[ -z "$value" || "$value" == --* ]]; then
    die "$flag requires a value"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        require_arg_value "$1" "${2-}"
        TARGET=$2
        shift 2
        ;;
      --profile)
        require_arg_value "$1" "${2-}"
        PROFILE=$2
        shift 2
        ;;
      --vm)
        VM_MODE=1
        shift
        ;;
      --disk)
        require_arg_value "$1" "${2-}"
        DISK=$2
        shift 2
        ;;
      --yes)
        YES=1
        shift
        ;;
      --aur)
        ENABLE_AUR=1
        shift
        ;;
      --hostname)
        require_arg_value "$1" "${2-}"
        INSTALL_HOSTNAME=$2
        shift 2
        ;;
      --username)
        require_arg_value "$1" "${2-}"
        INSTALL_USERNAME=$2
        shift 2
        ;;
      --timezone)
        require_arg_value "$1" "${2-}"
        TIMEZONE=$2
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

  if [[ "$YES" -eq 1 && "$VM_MODE" -ne 1 ]]; then
    die "--yes is only valid with --vm"
  fi

  if [[ "$VM_MODE" -eq 1 && -z "$DISK" ]]; then
    die "--vm requires --disk"
  fi

  if [[ "$VM_MODE" -eq 0 && -n "$DISK" ]]; then
    die "--disk is only valid with --vm"
  fi
}
