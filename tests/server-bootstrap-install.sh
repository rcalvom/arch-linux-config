#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
INSTALLER="$REPO_DIR/server-bootstrap/install.sh"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    die "Expected command to fail: $*"
  fi
}

help=$(bash "$INSTALLER" --help)
[[ "$help" == *"--yes"* ]] || die "Launcher help does not document --yes."

dry_run=$(bash "$INSTALLER" --dry-run --ref release-1 --skip-packages)
[[ "$dry_run" == *"https://codeload.github.com/rcalvom/arch-linux-config/tar.gz/release-1"* ]] || {
  die "Dry run did not use the requested source ref."
}
[[ "$dry_run" == *"bootstrap.sh --dry-run --skip-packages"* ]] || {
  die "Dry run did not forward bootstrap options."
}

expect_failure bash "$INSTALLER" --skip-packages
expect_failure bash "$INSTALLER" --yes --ref ../unsafe
expect_failure bash "$INSTALLER" --yes --ref release/

if [[ $EUID -eq 0 ]]; then
  exit 0
fi

TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT
SOURCE_ROOT="$TEST_DIR/source/arch-linux-config-release-1"
FAKE_BIN="$TEST_DIR/bin"
ARCHIVE="$TEST_DIR/source.tar.gz"
mkdir -p -- "$SOURCE_ROOT" "$FAKE_BIN" "$TEST_DIR/home"
cp -a -- "$REPO_DIR/server-bootstrap" "$SOURCE_ROOT/server-bootstrap"
tar -czf "$ARCHIVE" -C "$TEST_DIR/source" arch-linux-config-release-1

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'destination=""' \
  'while (($# > 0)); do' \
  '  case $1 in' \
  '    --output) destination=$2; shift 2; continue ;;' \
  '  esac' \
  '  shift' \
  'done' \
  '[[ -n "$destination" ]]' \
  'cp -- "$TEST_ARCHIVE" "$destination"' > "$FAKE_BIN/curl"
chmod 0755 "$FAKE_BIN/curl"

integration_output=$(
  PATH="$FAKE_BIN:$PATH" \
    TEST_ARCHIVE="$ARCHIVE" \
    HOME="$TEST_DIR/home" \
    XDG_CONFIG_HOME="$TEST_DIR/config" \
    XDG_STATE_HOME="$TEST_DIR/state" \
    bash "$INSTALLER" --yes --ref release-1 -- --dry-run
)
[[ "$integration_output" == *"Launching the downloaded bootstrap payload."* ]] || {
  die "Launcher did not invoke the downloaded bootstrap."
}
[[ "$integration_output" == *"Bootstrap summary"* ]] || {
  die "Downloaded bootstrap did not complete its dry run."
}
