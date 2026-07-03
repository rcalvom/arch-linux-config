#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROFILE="developer"
INSTALL_HOSTNAME="archlinux"
INSTALL_USERNAME="ricardo"
TIMEZONE="America/Bogota"
REPO_DIR="$SCRIPT_DIR"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=scripts/packages.sh
source "$SCRIPT_DIR/scripts/packages.sh"
# shellcheck source=scripts/users.sh
source "$SCRIPT_DIR/scripts/users.sh"
# shellcheck source=scripts/services.sh
source "$SCRIPT_DIR/scripts/services.sh"
# shellcheck source=scripts/dotfiles.sh
source "$SCRIPT_DIR/scripts/dotfiles.sh"
# shellcheck source=scripts/desktop.sh
source "$SCRIPT_DIR/scripts/desktop.sh"

usage() {
  cat <<'USAGE'
Usage: postinstall.sh [options]

Options:
  --profile <name>      Installation profile: minimal, desktop, developer, virtualbox.
  --hostname <name>     Hostname. Default: archlinux.
  --username <name>     Initial user. Default: ricardo.
  --timezone <zone>     Timezone. Default: America/Bogota.
  --repo-dir <path>     Repository path inside the target system.
  --help                Print this help.
USAGE
}

require_postinstall_value() {
  local flag=$1
  local value=${2-}

  if [[ -z "$value" || "$value" == --* ]]; then
    die "$flag requires a value"
  fi
}

parse_postinstall_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        require_postinstall_value "$1" "${2-}"
        PROFILE=$2
        shift 2
        ;;
      --hostname)
        require_postinstall_value "$1" "${2-}"
        INSTALL_HOSTNAME=$2
        shift 2
        ;;
      --username)
        require_postinstall_value "$1" "${2-}"
        INSTALL_USERNAME=$2
        shift 2
        ;;
      --timezone)
        require_postinstall_value "$1" "${2-}"
        TIMEZONE=$2
        shift 2
        ;;
      --repo-dir)
        require_postinstall_value "$1" "${2-}"
        REPO_DIR=$2
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown postinstall argument: $1"
        ;;
    esac
  done
}

configure_timezone() {
  local timezone=$1

  [[ -f "/usr/share/zoneinfo/$timezone" ]] || die "Invalid timezone: $timezone"
  log_info "Configuring timezone: $timezone"
  ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
  hwclock --systohc
}

ensure_line() {
  local line=$1
  local file=$2

  touch "$file"
  grep -qxF "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

configure_locale() {
  log_info "Configuring locale"
  ensure_line "en_US.UTF-8 UTF-8" /etc/locale.gen
  locale-gen
  printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf
  printf 'KEYMAP=la-latin1\n' > /etc/vconsole.conf
}

configure_hostname() {
  local hostname=$1

  log_info "Configuring hostname: $hostname"
  printf '%s\n' "$hostname" > /etc/hostname
  cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
HOSTS
}

configure_bootloader() {
  log_info "Installing GRUB for UEFI"
  [[ -d /sys/firmware/efi/efivars ]] || die "UEFI firmware variables are not available in chroot"
  mountpoint -q /boot || die "/boot must be mounted to the EFI System Partition"

  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux --recheck
  grub-mkconfig -o /boot/grub/grub.cfg
}

profile_has_desktop() {
  case "$1" in
    desktop | developer | virtualbox)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

main() {
  parse_postinstall_args "$@"
  require_root
  validate_profile "$PROFILE"

  configure_timezone "$TIMEZONE"
  configure_locale
  configure_hostname "$INSTALL_HOSTNAME"
  install_packages_for_profile "$PROFILE" "$REPO_DIR"
  configure_bootloader
  configure_initial_user "$INSTALL_USERNAME"

  if profile_has_desktop "$PROFILE"; then
    install_wayland_dotfiles "$REPO_DIR" "$INSTALL_USERNAME"
    configure_wayland_desktop
  fi

  enable_core_services "$PROFILE"
  log_info "Post-install configuration finished"
}

main "$@"
