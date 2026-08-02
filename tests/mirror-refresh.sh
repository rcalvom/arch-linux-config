#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
MOCK_BIN="$TEST_ROOT/bin"
MIRRORLIST="$TEST_ROOT/mirrorlist"
REFLECTOR_LOG="$TEST_ROOT/reflector.log"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'test failure: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$MOCK_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\n" "$*" > "$REFLECTOR_LOG"' \
  '[[ "${REFLECTOR_FAILURE:-0}" != 1 ]] || exit 1' \
  'printf "%s\n" "Server = https://selected.example/\$repo/os/\$arch" > "${!#}"' > "$MOCK_BIN/reflector"
chmod 755 "$MOCK_BIN/reflector"

export PATH="$MOCK_BIN:$PATH"
export REFLECTOR_LOG

log_info() {
  :
}

log_warn() {
  :
}

# shellcheck source=../lib/install.sh
source "$REPO_DIR/lib/install.sh"

printf '%s\n' 'Server = https://previous.example/$repo/os/$arch' > "$MIRRORLIST"
refresh_mirrors_if_available "$MIRRORLIST"

mapfile -t mirrors < "$MIRRORLIST"
[[ "${mirrors[0]}" == 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' ]] || fail "official mirror is not first"
[[ "${mirrors[1]}" == 'Server = https://selected.example/$repo/os/$arch' ]] || fail "refreshed mirror is not retained"
[[ "$(<"$REFLECTOR_LOG")" == *'--latest 20 --protocol https --sort rate --save '* ]] || fail "reflector was invoked with unexpected options"

printf '%s\n' 'Server = https://previous.example/$repo/os/$arch' > "$MIRRORLIST"
REFLECTOR_FAILURE=1 refresh_mirrors_if_available "$MIRRORLIST"
[[ "$(<"$MIRRORLIST")" == 'Server = https://previous.example/$repo/os/$arch' ]] || fail "failed refresh overwrote the existing mirrorlist"
