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
USER_PASSWORD_FILE=""
PACKAGE_EXTRAS=()
MICROCODE=auto
HARDWARE_PROFILE=none
RECIPE=none
GPU_POLICY=auto
DEFER_MANUAL=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Options:
  --target <path>       Target mount point. Default: /mnt.
  --profile <name>      Installation profile: minimal, desktop, developer, virtualbox.
                        Default: developer.
  --recipe <name>       Optional personal package recipe: ricardo (not a hardware profile).
  --dry-run             Print package selection only; no root, network or target writes.
  --gpu <policy>        Recipe GPU: auto, amd, intel (Broadwell+), software.
  --defer-manual         Explicitly defer blocked recipe AUR packages; see recipe docs.
  --vm                  Enable automatic VM/disk installation mode.
  --disk <device>       Disk to wipe and install to in VM mode.
  --yes                 Skip disk erase confirmation. Only valid with --vm.
  --aur                 Install optional AUR packages for the selected profile.
  --extra <name>        Optional package set (repeatable): dev-extras, research,
                        multimedia, virtualization, amd, fingerprint.
  --microcode <policy>  auto (default; skips virtual machines) or none.
  --hardware-profile <name>  none (default) or ricardo (personal display layouts).
  --hostname <name>     Hostname. Default: archlinux.
  --username <name>     Initial user. Default: ricardo.
  --timezone <zone>     Timezone. Default: America/Bogota.
  --user-password-file <path>
                        One-use initial-user password file for automated VM tests.
                        Only valid with --vm --yes.
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
      --recipe)
        require_arg_value "$1" "${2-}"
        case "$2" in ricardo) RECIPE=$2 ;; *) die "Invalid recipe: $2" ;; esac
        shift 2
        ;;
      --gpu)
        require_arg_value "$1" "${2-}"
        case "$2" in auto | amd | intel | software) GPU_POLICY=$2 ;; *) die "Invalid GPU policy: $2" ;; esac
        shift 2
        ;;
      --defer-manual) DEFER_MANUAL=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
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
      --extra)
        require_arg_value "$1" "${2-}"
        package_file_for_extra "$2" >/dev/null
        PACKAGE_EXTRAS+=("$2")
        shift 2
        ;;
      --microcode)
        require_arg_value "$1" "${2-}"
        case "$2" in auto | none) MICROCODE=$2 ;; *) die "Invalid microcode policy: $2" ;; esac
        shift 2
        ;;
      --hardware-profile)
        require_arg_value "$1" "${2-}"
        case "$2" in none | ricardo) HARDWARE_PROFILE=$2 ;; *) die "Invalid hardware profile: $2" ;; esac
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
      --user-password-file)
        require_arg_value "$1" "${2-}"
        USER_PASSWORD_FILE=$2
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

  validate_recipe_options

  if [[ "$YES" -eq 1 && "$VM_MODE" -ne 1 ]]; then
    die "--yes is only valid with --vm"
  fi
  [[ "$HARDWARE_PROFILE" == none || "$PROFILE" != minimal ]] || die 'Hardware display profiles require a desktop profile'

  if [[ "$VM_MODE" -eq 1 && -z "$DISK" ]]; then
    die "--vm requires --disk"
  fi

  if [[ "$VM_MODE" -eq 0 && -n "$DISK" ]]; then
    die "--disk is only valid with --vm"
  fi

  if [[ -n "$USER_PASSWORD_FILE" && ( "$VM_MODE" -ne 1 || "$YES" -ne 1 ) ]]; then
    die "--user-password-file is only valid with --vm --yes"
  fi
}
