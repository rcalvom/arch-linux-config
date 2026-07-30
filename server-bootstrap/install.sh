#!/usr/bin/env bash
# Public launcher for the versioned server-bootstrap payload.

set -euo pipefail

REPOSITORY="${WORKSPACE_BOOTSTRAP_REPOSITORY:-rcalvom/arch-linux-config}"
REF="${WORKSPACE_BOOTSTRAP_REF:-master}"
DRY_RUN=false
ASSUME_YES=false
TEMP_DIR=""
declare -a BOOTSTRAP_ARGS=()

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

usage() {
  cat <<'EOF'
Usage: curl -fsSL <url>/server-bootstrap/install.sh | bash -s -- [options]

Download the versioned server-bootstrap payload and configure the current user.
The downloaded bootstrap installs only terminal development tools and user
configuration. It never changes disks, services, networking, SSH, credentials,
or Git identity.

Launcher options:
  --yes                    Confirm the download and host changes.
  --repository OWNER/REPO  GitHub repository to download.
  --ref REF                Git ref to download.
  --dry-run                Print the planned download and bootstrap command.
  -h, --help               Show this help.
  --                       Pass all following arguments to bootstrap.sh.

All unrecognized options are passed through to bootstrap.sh. For example:
  --skip-packages --skip-opencode-install --set-zsh-default
EOF
}

require_value() {
  local option=$1
  local value=${2:-}

  [[ -n "$value" && "$value" != --* ]] || die "$option requires a value."
}

parse_args() {
  while (($# > 0)); do
    case $1 in
      --yes)
        ASSUME_YES=true
        ;;
      --repository)
        require_value "$1" "${2:-}"
        REPOSITORY=$2
        shift
        ;;
      --ref)
        require_value "$1" "${2:-}"
        REF=$2
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        BOOTSTRAP_ARGS+=("$1")
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        BOOTSTRAP_ARGS+=("$@")
        break
        ;;
      *)
        BOOTSTRAP_ARGS+=("$1")
        ;;
    esac
    shift
  done
}

validate_source() {
  [[ "$REPOSITORY" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    die "Repository must use the OWNER/REPO form."
  }
  [[ "$REF" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ && "$REF" != *..* && "$REF" != */ && "$REF" != *//* ]] || {
    die "Ref contains unsupported characters."
  }
}

archive_url() {
  printf 'https://codeload.github.com/%s/tar.gz/%s\n' "$REPOSITORY" "$REF"
}

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

download() {
  local url=$1
  local destination=$2

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --retry 3 --output "$destination" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document="$destination" "$url"
  else
    die "curl or wget is required to download the bootstrap payload."
  fi
}

archive_root() {
  local archive=$1
  local entry
  local candidate
  local root=""

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    [[ "$entry" != /* ]] || die "Archive contains an absolute path."
    case "/$entry/" in
      *'/../'*) die "Archive contains an unsafe path." ;;
    esac

    candidate=${entry%%/*}
    [[ -n "$candidate" && "$candidate" != . ]] || die "Archive has an invalid top-level path."
    if [[ -n "$root" && "$root" != "$candidate" ]]; then
      die "Archive has multiple top-level paths."
    fi
    root=$candidate
  done < <(tar -tzf "$archive")

  [[ -n "$root" ]] || die "Archive is empty."
  printf '%s\n' "$root"
}

run_bootstrap() {
  local url
  local archive
  local root
  local source_root
  local bootstrap

  command -v tar >/dev/null 2>&1 || die "tar is required to unpack the bootstrap payload."
  command -v mktemp >/dev/null 2>&1 || die "mktemp is required to prepare the bootstrap payload."

  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/server-bootstrap.XXXXXX")
  archive="$TEMP_DIR/source.tar.gz"
  url=$(archive_url)

  log_info "Downloading $REPOSITORY at $REF"
  download "$url" "$archive"
  root=$(archive_root "$archive")
  tar -xzf "$archive" -C "$TEMP_DIR"

  source_root="$TEMP_DIR/$root"
  [[ -d "$source_root" && ! -L "$source_root" ]] || die "Downloaded source root is invalid."
  [[ -d "$source_root/server-bootstrap" && ! -L "$source_root/server-bootstrap" ]] || {
    die "Downloaded server-bootstrap directory is invalid."
  }
  bootstrap="$source_root/server-bootstrap/bootstrap.sh"
  [[ -f "$bootstrap" && ! -L "$bootstrap" ]] || die "Downloaded source does not contain server-bootstrap/bootstrap.sh."

  log_info "Launching the downloaded bootstrap payload."
  bash "$bootstrap" "${BOOTSTRAP_ARGS[@]}"
}

main() {
  parse_args "$@"
  validate_source

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] download $(archive_url)"
    log_info "[dry-run] bash <downloaded>/server-bootstrap/bootstrap.sh $(printf '%q ' "${BOOTSTRAP_ARGS[@]}")"
    return 0
  fi

  [[ $EUID -ne 0 ]] || die "Run this script as the target user, not as root or through sudo."
  [[ "$ASSUME_YES" == true ]] || die "Refusing to change this host without --yes."
  run_bootstrap
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM
main "$@"
