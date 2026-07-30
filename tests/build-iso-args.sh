#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
BUILD_SCRIPT="$REPO_DIR/scripts/build-iso.sh"

fail() {
  printf 'test failure: %s\n' "$*" >&2
  exit 1
}

assert_rejected() {
  if "$BUILD_SCRIPT" "$@" >/dev/null 2>&1; then
    fail "expected arguments to be rejected: $*"
  fi
}

assert_valid_before_root_check() {
  local output

  output=$("$BUILD_SCRIPT" "$@" 2>&1 || true)
  [[ "$output" == *'Run this script as root'* ]] || fail "arguments did not reach the root check: $*"
}

assert_rejected --jobs 1
assert_rejected --fast --jobs 0
assert_rejected --fast --jobs invalid
assert_valid_before_root_check --fast --jobs 1
assert_rejected --fast --live-authorized-key-file /does/not/exist

authorized_key=$(mktemp)
trap 'rm -f -- "$authorized_key"' EXIT
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA archcfg-e2e\n' > "$authorized_key"
assert_valid_before_root_check --fast --live-authorized-key-file "$authorized_key"
