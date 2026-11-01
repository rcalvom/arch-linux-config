#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROFILE="developer"
INSTALL_HOSTNAME="archlinux"
INSTALL_USERNAME="ricardo"
TIMEZONE="America/Bogota"
REPO_DIR="$SCRIPT_DIR"
ENABLE_AUR=0
PACKAGE_EXTRAS=()
MICROCODE=auto
HARDWARE_PROFILE=none
RECIPE=none
GPU_POLICY=auto
DEFER_MANUAL=0
DRY_RUN=0

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=scripts/packages.sh
source "$SCRIPT_DIR/scripts/packages.sh"
# shellcheck source=scripts/aur.sh
source "$SCRIPT_DIR/scripts/aur.sh"
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
  --recipe <name>       Optional personal package recipe: ricardo.
  --dry-run             Print selection without changing the target.
  --gpu <policy>        Recipe GPU: auto, amd, intel (Broadwell+), software.
  --defer-manual         Explicitly defer blocked recipe AUR packages.
  --profile <name>      Installation profile: minimal, desktop, developer, virtualbox.
  --hostname <name>     Hostname. Default: archlinux.
  --username <name>     Initial user. Default: ricardo.
  --timezone <zone>     Timezone. Default: America/Bogota.
  --repo-dir <path>     Repository path inside the target system.
  --aur                 Install optional AUR packages for the selected profile.
  --extra <name>         Add an opt-in package set (repeatable): dev-extras, research,
                         multimedia, virtualization, amd, fingerprint.
  --microcode <policy>  CPU microcode: auto (default), none. Runs in the target.
  --hardware-profile <name>  none (default) or ricardo (personal display layouts).
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
      --recipe)
        require_postinstall_value "$1" "${2-}"
        case "$2" in ricardo) RECIPE=$2 ;; *) die "Invalid recipe: $2" ;; esac
        shift 2
        ;;
      --gpu)
        require_postinstall_value "$1" "${2-}"
        case "$2" in auto | amd | intel | software) GPU_POLICY=$2 ;; *) die "Invalid GPU policy: $2" ;; esac
        shift 2
        ;;
      --defer-manual) DEFER_MANUAL=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
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
      --aur)
        ENABLE_AUR=1
        shift
        ;;
      --extra)
        require_postinstall_value "$1" "${2-}"
        package_file_for_extra "$2" >/dev/null
        PACKAGE_EXTRAS+=("$2")
        shift 2
        ;;
      --microcode)
        require_postinstall_value "$1" "${2-}"
        case "$2" in
          auto | none) MICROCODE=$2 ;;
          *) die "Invalid microcode policy: $2" ;;
        esac
        shift 2
        ;;
      --hardware-profile)
        require_postinstall_value "$1" "${2-}"
        case "$2" in none | ricardo) HARDWARE_PROFILE=$2 ;; *) die "Invalid hardware profile: $2" ;; esac
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
  validate_recipe_options
  [[ "$HARDWARE_PROFILE" == none || "$PROFILE" != minimal ]] || die 'Hardware display profiles require a desktop profile'
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

install_grub_theme() {
  local repo_dir=$1
  local theme_dir=/usr/share/grub/themes/arch-classic

  [[ -f "$repo_dir/grub/classic/grub" ]] || die "Missing GRUB defaults: $repo_dir/grub/classic/grub"
  [[ -d "$repo_dir/grub/classic/theme" ]] || die "Missing GRUB theme: $repo_dir/grub/classic/theme"

  log_info "Installing classic GRUB defaults and theme"
  install -Dm644 "$repo_dir/grub/classic/grub" /etc/default/grub
  rm -rf "$theme_dir"
  install -dm755 "$theme_dir"
  cp -a "$repo_dir/grub/classic/theme/." "$theme_dir/"
  chown -R root:root "$theme_dir"
}

configure_bootloader() {
  local repo_dir=$1

  log_info "Installing GRUB for UEFI"
  [[ -d /sys/firmware/efi/efivars ]] || die "UEFI firmware variables are not available in chroot"
  mountpoint -q /boot || die "/boot must be mounted to the EFI System Partition"

  install_grub_theme "$repo_dir"
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
  validate_profile "$PROFILE"
  if [[ "$DRY_RUN" == 1 ]]; then
    print_package_plan "$REPO_DIR"
    return
  fi
  require_root
  validate_profile "$PROFILE"
  validate_recipe_installation

  configure_timezone "$TIMEZONE"
  configure_locale
  configure_hostname "$INSTALL_HOSTNAME"
  install_packages_for_profile "$PROFILE" "$REPO_DIR" "${PACKAGE_EXTRAS[@]}"
  install_cpu_microcode "$MICROCODE"
  configure_bootloader "$REPO_DIR"
  configure_initial_user "$INSTALL_USERNAME" "$PROFILE"

  if profile_has_desktop "$PROFILE"; then
    install_wayland_dotfiles "$REPO_DIR" "$INSTALL_USERNAME" "$HARDWARE_PROFILE"
    configure_wayland_desktop "$PROFILE" "$REPO_DIR"
  fi

  configure_iwd_networking "$REPO_DIR"
  configure_charge_limits "$REPO_DIR"
  enable_core_services "$PROFILE"
  install_aur_packages_for_profile "$PROFILE" "$REPO_DIR" "$INSTALL_USERNAME" "$ENABLE_AUR"
  if [[ "$RECIPE" == ricardo ]]; then
    install -dm755 /var/lib/archcfg
    print_package_plan "$REPO_DIR" > /var/lib/archcfg/recipe-selection.txt
    log_warn 'Personal recipe installed with explicit deferred selections; review /var/lib/archcfg/recipe-selection.txt (AUR requires --aur; manual packages remain pending)'
  fi
  log_info "Post-install configuration finished"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
