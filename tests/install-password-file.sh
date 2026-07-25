#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'test failure: %s\n' "$*" >&2
  exit 1
}

assert_status() {
  local expected=$1

  shift
  local actual

  if "$@"; then
    actual=0
  else
    actual=$?
  fi
  [[ "$actual" -eq "$expected" ]] || fail "expected status $expected, got $actual"
}

assert_valid_automated_args() {
  bash -c '
    set -euo pipefail
    source "$1/lib/log.sh"
    source "$1/lib/args.sh"
    shift
    parse_args "$@"
    [[ "$USER_PASSWORD_FILE" == /run/archcfg-e2e/user-password ]]
  ' _ "$REPO_DIR" \
    --vm \
    --disk /dev/sda \
    --yes \
    --user-password-file /run/archcfg-e2e/user-password
}

assert_invalid_automated_args() {
  bash -c '
    set -euo pipefail
    source "$1/lib/log.sh"
    source "$1/lib/args.sh"
    shift
    parse_args "$@"
  ' _ "$REPO_DIR" "$@" >/dev/null 2>&1
}

test_password_staging() {
  local target="$TEST_ROOT/target"
  local source_file="$TEST_ROOT/source-password"
  local staged_file="$target/root/.archcfg-user-password"

  printf 'temporary-password\n' > "$source_file"
  chmod 600 "$source_file"

  # shellcheck source=../lib/log.sh
  source "$REPO_DIR/lib/log.sh"
  # shellcheck source=../lib/install.sh
  source "$REPO_DIR/lib/install.sh"
  PASSWORD_FILE_STAGED=0
  write_user_password_file "$target" archcfg-e2e "$source_file"

  [[ ! -e "$source_file" ]] || fail "source password file was not consumed"
  [[ "$PASSWORD_FILE_STAGED" -eq 1 ]] || fail "password staging was not recorded"
  [[ "$(stat -c '%a' "$staged_file")" == 600 ]] || fail "staged password file mode is not 0600"
  [[ "$(<"$staged_file")" == 'archcfg-e2e:temporary-password' ]] || fail "staged password record is incorrect"
}

assert_status 0 assert_valid_automated_args
assert_status 1 assert_invalid_automated_args --vm --disk /dev/sda --user-password-file /run/archcfg-e2e/user-password
assert_status 1 assert_invalid_automated_args --yes --user-password-file /run/archcfg-e2e/user-password
test_password_staging
