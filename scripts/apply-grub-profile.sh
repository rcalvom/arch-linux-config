#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/bin
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/grub-backups
PROFILE=
SIZE=

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

usage() {
  printf '%s\n' "Usage: apply-grub-profile.sh --profile <graphical|classic> [--size <compact|normal|large>]" \
    "--size is graphical-only; defaults to compact. No automatic size selection." \
    "Installs theme assets, merges display settings, and runs grub-mkconfig." \
    "Requires root and interactive APPLY confirmation; never installs GRUB or reboots."
}

cleanup() {
  local status=$? failed=0
  trap - EXIT
  if [[ $status -ne 0 && ${CHANGED:-0} == 1 ]]; then
    cp -a -- "$BACKUP_DIR/default-grub" /etc/default/grub || failed=1
    cp -a -- "$BACKUP_DIR/grub.cfg" /boot/grub/grub.cfg || failed=1
    if [[ ${THEME_CHANGED:-0} == 1 ]]; then
      rm -rf -- "$THEME_DIR" || failed=1
      if [[ -d "$BACKUP_DIR/theme" ]]; then
        cp -a -- "$BACKUP_DIR/theme" "$THEME_DIR" || failed=1
      fi
    fi
    if [[ $failed == 1 ]]; then
      log_error "Rollback incomplete. Do not reboot; restore from $BACKUP_DIR"
    else
      log_error "Update failed; previous defaults, theme and grub.cfg restored. Logs: $BACKUP_DIR"
    fi
  fi
  [[ -z ${TEMPORARY_CONFIG:-} ]] || rm -f -- "$TEMPORARY_CONFIG" "$TEMPORARY_CONFIG.new"
  [[ -z ${STAGE:-} ]] || rm -rf -- "$STAGE"
  exit "$status"
}

main() {
  local config_source theme_source confirmation path
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        [[ -n ${2-} ]] || die "--profile requires a value"
        PROFILE=$2
        shift 2
        ;;
      --size)
        [[ -n ${2-} ]] || die "--size requires a value"
        SIZE=$2
        shift 2
        ;;
      --help) usage; return ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
  case "$PROFILE" in
    graphical)
      SIZE=${SIZE:-compact}
      case "$SIZE" in
        compact|normal|large) ;;
        *) die "--size must be compact, normal or large" ;;
      esac
      config_source="$REPO_DIR/grub/grub"
      theme_source="$REPO_DIR/grub/theme/variants/$SIZE"
      THEME_DIR=/usr/share/grub/themes/arch
      ;;
    classic)
      [[ -z $SIZE ]] || die "--size is only valid with --profile graphical"
      config_source="$REPO_DIR/grub/classic/grub"
      theme_source="$REPO_DIR/grub/classic/theme"
      THEME_DIR=/usr/share/grub/themes/arch-classic
      ;;
    *) usage >&2; die "--profile must be graphical or classic" ;;
  esac
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
  for path in grub-mkconfig grub-script-check flock; do
    command -v "$path" >/dev/null || die "$path is required"
  done
  exec 9>/run/lock/arch-linux-config-grub.lock
  flock -n 9 || die "Another GRUB profile update is running"
  for path in /etc/default/grub /boot/grub/grub.cfg; do
    [[ -f $path && ! -L $path && $(stat -c %u "$path") == 0 ]] || die "Expected a regular root-owned file: $path"
  done
  [[ ! -L $THEME_DIR ]] || die "Refusing a symlink theme directory"
  [[ ! -e $THEME_DIR || -d $THEME_DIR ]] || die "Theme destination is not a directory"
  [[ -f $config_source && -f $theme_source/theme.txt ]] || die "Missing profile assets"

  log_warn "Activate $PROFILE and regenerate GRUB (visible timeout: 3 seconds)."
  [[ $PROFILE != graphical ]] || log_info "Graphical size: $SIZE"
  log_warn "Kernel parameters, default selection, OS probing and custom generators are preserved."
  printf 'Type APPLY to continue: '
  read -r confirmation
  [[ $confirmation == APPLY ]] || die "GRUB profile change cancelled"

  install -dm700 "$BACKUP_ROOT"
  BACKUP_DIR=$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S).XXXXXX")
  cp -a -- /etc/default/grub "$BACKUP_DIR/default-grub"
  cp -a -- /boot/grub/grub.cfg "$BACKUP_DIR/grub.cfg"
  [[ ! -d $THEME_DIR ]] || cp -a -- "$THEME_DIR" "$BACKUP_DIR/theme"
  log_info "Private backup and logs: $BACKUP_DIR"
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  install -dm755 /usr/share/grub/themes
  STAGE=$(mktemp -d /usr/share/grub/themes/.arch-stage.XXXXXX)
  # Install only GRUB assets, never the legacy installer or development sources.
  while IFS= read -r -d '' path; do
    install -Dm644 "$path" "$STAGE/${path#"$theme_source/"}"
  done < <(find "$theme_source" -type f \( -name '*.pf2' -o -name '*.png' -o -name '*FONT-LICEN[CS]E.txt' -o -name theme.txt \) -print0)
  chmod 755 "$STAGE"
  chown -R root:root "$STAGE"
  [[ -s $STAGE/theme.txt ]] || die "Staged theme is empty"

  # Merge only presentation keys; never source or replace the host's boot settings.
  awk '
    BEGIN { keys="^(GRUB_TIMEOUT|GRUB_TIMEOUT_STYLE|GRUB_TERMINAL|GRUB_TERMINAL_INPUT|GRUB_TERMINAL_OUTPUT|GRUB_GFXMODE|GRUB_COLOR_NORMAL|GRUB_COLOR_HIGHLIGHT|GRUB_THEME|GRUB_BACKGROUND|GRUB_DISABLE_RECOVERY)$" }
    { key=$0; sub(/^[ \t]*(export[ \t]+)?/, "", key); sub(/=.*/, "", key) }
    NR==FNR { if (key ~ keys) settings=settings $0 "\n"; next }
    key !~ keys { print }
    END { printf "%s", settings }
  ' "$config_source" /etc/default/grub > "$BACKUP_DIR/merged-defaults"
  bash -n "$BACKUP_DIR/merged-defaults" > "$BACKUP_DIR/validation.log" 2>&1
  TEMPORARY_CONFIG=$(mktemp /boot/grub/grub.cfg.XXXXXX)
  cmp -s /etc/default/grub "$BACKUP_DIR/default-grub" || die "GRUB defaults changed during preparation"
  cmp -s /boot/grub/grub.cfg "$BACKUP_DIR/grub.cfg" || die "GRUB configuration changed during preparation"
  CHANGED=1
  # Keep the original owner and mode while replacing the contents.
  cat "$BACKUP_DIR/merged-defaults" > /etc/default/grub
  THEME_CHANGED=1
  rm -rf -- "$THEME_DIR"
  mv -- "$STAGE" "$THEME_DIR"
  STAGE=

  log_info "Generating and checking GRUB configuration (diagnostics kept private)"
  grub-mkconfig -o "$TEMPORARY_CONFIG" > "$BACKUP_DIR/generation.log" 2>&1
  [[ -s $TEMPORARY_CONFIG ]] || die "Generated GRUB configuration is empty"
  grub-script-check "$TEMPORARY_CONFIG" >> "$BACKUP_DIR/validation.log" 2>&1
  grep -Fq "$THEME_DIR/theme.txt" "$TEMPORARY_CONFIG" || die "Generated configuration does not reference the selected theme"
  grep -Eq '^[[:space:]]*set timeout_style=menu[[:space:]]*$' "$TEMPORARY_CONFIG" || die "Generated configuration does not expose the menu"
  local timeout=3
  grep -Eq "^[[:space:]]*set timeout=$timeout[[:space:]]*$" "$TEMPORARY_CONFIG" || die "Generated configuration has an unexpected timeout"
  chmod --reference="$BACKUP_DIR/grub.cfg" "$TEMPORARY_CONFIG"
  chown --reference="$BACKUP_DIR/grub.cfg" "$TEMPORARY_CONFIG"
  mv -- "$TEMPORARY_CONFIG" /boot/grub/grub.cfg
  TEMPORARY_CONFIG=
  CHANGED=0
  log_info "GRUB profile applied. No reboot performed. Backup: $BACKUP_DIR"
}

main "$@"
