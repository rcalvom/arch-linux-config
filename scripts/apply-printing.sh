#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
BACKUP_ROOT=/var/lib/arch-linux-config/printing-backups
CUPS_SOCKET=/run/cups/cups.sock
TARGET_USER=""
BACKUP_DIR=""
PRINTING_CONFIG="$REPO_DIR/printing/printing.conf"

# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

usage() {
  cat <<'USAGE'
Usage: apply-printing.sh [options]

Configures CUPS for Purdue printing:

  - Resolves .local names through mDNS in /etc/nsswitch.conf.
  - Enables cups.socket and avahi-daemon.service.
  - Points the user's CUPS client at the Engineering (ECN) spooler.
  - Creates the PaperCut Mobility Print queues over IPP.

Options:
  --user <name>   Account that receives ~/.cups/client.conf. Default: $SUDO_USER.
  --config <path> Trusted local shell configuration. The default template is empty.
  --help          Print this help.
USAGE
}

require_root() {
  [[ $EUID -eq 0 ]] || die "Run this script with sudo"
}

require_file() {
  [[ -f "$1" ]] || die "Missing required file: $1"
}

require_command() {
  local command_name=$1
  local package=$2

  command -v "$command_name" >/dev/null 2>&1 ||
    die "Missing $command_name; install the '$package' package first"
}

require_value() {
  local flag=$1
  local value=${2-}

  if [[ -z "$value" || "$value" == --* ]]; then
    die "$flag requires a value"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        require_value "$1" "${2-}"
        PRINTING_CONFIG=$2
        shift 2
        ;;
      --user)
        require_value "$1" "${2-}"
        TARGET_USER=$2
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
}

load_printing_conf() {
  local name queue
  local required=(ECN_CUPS_SERVER ECN_CAREER_ACCOUNT PAPERCUT_HOST PAPERCUT_PORT PAPERCUT_QUEUES)
  require_file "$PRINTING_CONFIG"
  # Do not fill missing local settings from inherited environment values.
  unset "${required[@]}"
  # Trusted operator-supplied shell code, executed as root; never source downloads.
  # shellcheck source=/dev/null
  source "$PRINTING_CONFIG"
  for name in "${required[@]}"; do
    [[ -n "${!name:-}" && "${!name}" != *[\<\>]* ]] ||
      die "Printing configuration requires $name; provision a private file and pass --config PATH"
  done
  for name in ECN_CUPS_SERVER PAPERCUT_HOST; do
    [[ "${!name}" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || die "Invalid printing configuration field: $name (hostname required)"
  done
  [[ "$ECN_CAREER_ACCOUNT" =~ ^[A-Za-z0-9_][A-Za-z0-9_.@-]*$ ]] || die "Invalid printing configuration field: ECN_CAREER_ACCOUNT"
  [[ "$PAPERCUT_PORT" =~ ^[0-9]{1,5}$ ]] &&
    (( 10#$PAPERCUT_PORT >= 1 && 10#$PAPERCUT_PORT <= 65535 )) || die "Invalid printing configuration field: PAPERCUT_PORT"
  [[ "$PAPERCUT_QUEUES" =~ [^[:space:]] ]] || die "Printing configuration requires PAPERCUT_QUEUES"
  [[ "$PAPERCUT_QUEUES" =~ ^[A-Za-z0-9_.[:blank:]-]+$ ]] || die "Invalid printing configuration field: PAPERCUT_QUEUES"
  for queue in $PAPERCUT_QUEUES; do
    [[ "$queue" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || die "Invalid printing configuration field: PAPERCUT_QUEUES"
  done
}

resolve_target_user() {
  [[ -n "$TARGET_USER" ]] || TARGET_USER=${SUDO_USER:-}
  [[ -n "$TARGET_USER" ]] || die "Cannot determine the target user; pass --user <name>"
  getent passwd "$TARGET_USER" >/dev/null || die "Unknown user: $TARGET_USER"
}

backup_path() {
  local path=$1
  local destination="$BACKUP_DIR/files$path"

  if [[ -e "$path" || -L "$path" ]]; then
    install -dm700 "$(dirname -- "$destination")" || die "Cannot create backup directory for $path"
    cp -a -- "$path" "$destination" || die "Cannot back up $path"
  else
    (umask 077; printf '%s\n' "$path" >> "$BACKUP_DIR/absent-paths.txt") || die "Cannot record absent path: $path"
  fi
}

# Avahi resolves .local hostnames only when nss-mdns sits ahead of the regular
# resolver in the hosts line. This is useless on eduroam, which blocks
# multicast between clients, but it is what makes home and wired printers
# discoverable without typing an address.
ensure_mdns_in_nsswitch() {
  local file=/etc/nsswitch.conf
  local tmp

  require_file "$file"

  if grep -qE '^hosts:.*mdns_minimal' "$file"; then
    log_info "nsswitch.conf already resolves .local through mDNS"
    return 0
  fi

  grep -qE '^hosts:' "$file" || die "$file has no hosts: line to extend"

  log_info "Adding mdns_minimal to the nsswitch.conf hosts line"
  tmp=$(mktemp)
  awk '
    /^hosts:/ && !/mdns_minimal/ {
      if (sub(/[[:space:]]resolve/, " mdns_minimal [NOTFOUND=return] resolve") == 0) {
        sub(/[[:space:]]dns/, " mdns_minimal [NOTFOUND=return] dns")
      }
    }
    { print }
  ' "$file" > "$tmp"

  install -Dm644 "$tmp" "$file"
  rm -f "$tmp"

  grep -qE '^hosts:.*mdns_minimal' "$file" ||
    die "Could not add mdns_minimal to $file; restore it from $BACKUP_DIR"
}

enable_unit_if_present() {
  local unit=$1

  if [[ -f "/usr/lib/systemd/system/$unit" || -f "/etc/systemd/system/$unit" ]]; then
    log_info "Enabling $unit"
    systemctl enable --now "$unit"
  else
    log_warn "Unit not installed, skipping: $unit"
  fi
}

enable_printing_services() {
  # cups.socket activates cupsd on demand; cups.service stays inactive and that
  # is the expected state.
  enable_unit_if_present cups.socket
  enable_unit_if_present avahi-daemon.service
}

# The ECN spooler owns the printer drivers, so no local PPD is needed. Setting
# ServerName redirects every CUPS client command for this user to that spooler.
write_cups_client_conf() {
  local user=$1
  local home_dir
  local conf

  home_dir=$(getent passwd "$user" | cut -d: -f6)
  [[ -n "$home_dir" ]] || die "Cannot determine home directory for $user"
  conf="$home_dir/.cups/client.conf"
  [[ ! -L "$home_dir/.cups" && ! -L "$conf" ]] || die "Refusing symlinked CUPS configuration: $conf"
  [[ ! -e "$conf" || -f "$conf" ]] || die "Not a regular CUPS configuration: $conf"
  backup_path "$conf"

  log_info "Writing $conf for $user"
  install -dm755 "$home_dir/.cups"
  printf 'ServerName %s\nUser %s\n' "$ECN_CUPS_SERVER" "$ECN_CAREER_ACCOUNT" > "$conf"
  chmod 644 "$conf"
  chown "$user:$user" "$home_dir/.cups" "$conf"
}

# CUPS_SERVER points at the local domain socket for two reasons: the
# client.conf written above would otherwise redirect these calls to the ECN
# spooler, and cupsd authenticates root through its local certificate over the
# socket instead of prompting for a password as it does over TCP.
ensure_papercut_queues() {
  local queue
  local uri

  for queue in $PAPERCUT_QUEUES; do
    uri="ipp://$PAPERCUT_HOST:$PAPERCUT_PORT/printers/$queue"
    log_info "Configuring a local print queue"
    CUPS_SERVER="$CUPS_SOCKET" lpadmin -p "$queue" -E -v "$uri" -m everywhere ||
      die "Could not configure a print queue; check the local configuration and server connectivity"
  done
}

main() {
  parse_args "$@"
  require_root
  load_printing_conf
  require_command lpadmin cups
  require_command avahi-daemon avahi
  resolve_target_user

  install -dm700 "$BACKUP_ROOT"
  BACKUP_DIR=$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%dT%H%M%S).XXXXXX")
  backup_path /etc/nsswitch.conf

  ensure_mdns_in_nsswitch
  enable_printing_services
  write_cups_client_conf "$TARGET_USER"
  ensure_papercut_queues

  log_info "Purdue printing configured; configuration backup: $BACKUP_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
