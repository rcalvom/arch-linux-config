#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/grub-backups
PROFILE=

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

usage() {
  printf '%s\n' "Usage: apply-grub-profile.sh --profile <graphical|classic>"
}

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

restore_defaults_on_error() {
  local status=$?

  if [[ -n "${TEMPORARY_CONFIG-}" ]]; then
    rm -f -- "$TEMPORARY_CONFIG"
  fi

  if [[ $status -ne 0 && -n "${BACKUP_DIR-}" && -f "$BACKUP_DIR/default-grub" ]]; then
    cp -a "$BACKUP_DIR/default-grub" /etc/default/grub
    log_error "Restored /etc/default/grub after a failed GRUB update"
  fi

  exit "$status"
}

main() {
  local config_source theme_source= theme_dir= obsolete_theme_dir= confirmation

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        [[ -n "${2-}" ]] || die "--profile requires a value"
        PROFILE=$2
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

  require_root

  case "$PROFILE" in
    graphical)
      config_source="$REPO_DIR/grub/grub"
      theme_source="$REPO_DIR/grub/theme"
      theme_dir=/usr/share/grub/themes/arch
      ;;
    classic)
      config_source="$REPO_DIR/grub/classic/grub"
      theme_source="$REPO_DIR/grub/classic/theme"
      theme_dir=/usr/share/grub/themes/arch-classic
      obsolete_theme_dir=/usr/share/grub/themes/arch-tui
      ;;
    *)
      usage >&2
      die "--profile must be graphical or classic"
      ;;
  esac

  [[ -f "$config_source" ]] || die "Missing GRUB profile: $config_source"
  if [[ -n "$theme_source" ]]; then
    [[ -f "$theme_source/theme.txt" ]] || die "Missing GRUB theme: $theme_source/theme.txt"
  fi
  command -v grub-mkconfig >/dev/null 2>&1 || die "grub-mkconfig is required"
  [[ -d /boot/grub ]] || die "/boot/grub is not available"

  log_warn "This will activate the $PROFILE GRUB profile and regenerate /boot/grub/grub.cfg."
  printf 'Type APPLY to continue: '
  read -r confirmation
  [[ "$confirmation" == "APPLY" ]] || die "GRUB profile change cancelled"

  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S)"
  install -dm700 "$BACKUP_DIR"
  cp -a /etc/default/grub "$BACKUP_DIR/default-grub"
  TEMPORARY_CONFIG=$(mktemp /boot/grub/grub.cfg.XXXXXX)
  trap restore_defaults_on_error EXIT

  log_info "Installing the $PROFILE GRUB profile"
  install -Dm644 "$config_source" /etc/default/grub
  if [[ -n "$theme_source" ]]; then
    install -dm755 "$theme_dir"
    cp -a "$theme_source/." "$theme_dir/"
    chown -R root:root "$theme_dir"
  fi

  log_info "Regenerating GRUB configuration"
  grub-mkconfig -o "$TEMPORARY_CONFIG"
  mv "$TEMPORARY_CONFIG" /boot/grub/grub.cfg
  TEMPORARY_CONFIG=

  if [[ -n "$obsolete_theme_dir" && -d "$obsolete_theme_dir" ]]; then
    cp -a "$obsolete_theme_dir" "$BACKUP_DIR/retired-arch-tui-theme" || log_warn "Could not back up the retired TUI theme"
    rm -rf -- "$obsolete_theme_dir" || log_warn "Could not remove the retired TUI theme"
  fi

  trap - EXIT
  log_info "GRUB profile applied. Backup: $BACKUP_DIR/default-grub"
}

main "$@"
