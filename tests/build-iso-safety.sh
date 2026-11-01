#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../scripts/build-iso.sh
source "$REPO_DIR/scripts/build-iso.sh"
TEST_DIR=$(mktemp -d)
trap 'command rm -rf -- "$TEST_DIR"' EXIT
CALLS="$TEST_DIR/removals"
touch "$CALLS"

# Never perform a builder deletion or build, even if validation regresses.
rm() { printf '%s\n' "$*" >> "$CALLS"; }
mkarchiso() { exit 99; }
findmnt() { printf '%s\n' "${MOCK_MOUNT:-/}"; }

reject() {
  if (WORK_DIR=$1 OUT_DIR=$2 CLEAN=1; prepare_build_directories) > /dev/null 2>&1; then
    printf 'Unexpectedly accepted: %s / %s\n' "$1" "$2" >&2
    exit 1
  fi
  [[ ! -s "$CALLS" ]]
}

reject / "$TEST_DIR/out"
reject /etc "$TEST_DIR/out"
reject "$REPO_ROOT" "$TEST_DIR/out"
reject "$HOME" "$TEST_DIR/out"
reject "$TEST_DIR/same" "$TEST_DIR/same"
reject "$TEST_DIR/nested" "$TEST_DIR/nested/out"
reject "$TEST_DIR/nested/out" "$TEST_DIR/nested"
mkdir "$TEST_DIR/unmarked"
printf 'keep\n' > "$TEST_DIR/unmarked/valuable"
reject "$TEST_DIR/unmarked" "$TEST_DIR/out"
ln -s "$TEST_DIR/unmarked" "$TEST_DIR/link"
reject "$TEST_DIR/link/child" "$TEST_DIR/out"
reject "$TEST_DIR/link/" "$TEST_DIR/out"
reject "$TEST_DIR/link/../other" "$TEST_DIR/out"
ln -s "$TEST_DIR/missing" "$TEST_DIR/dangling"
reject "$TEST_DIR/dangling" "$TEST_DIR/out"

WORK_DIR="$TEST_DIR/work"
OUT_DIR="$TEST_DIR/out"
prepare_build_directories
[[ -f "$WORK_DIR/.archcfg-build-iso" && -f "$OUT_DIR/.archcfg-build-iso" ]]
[[ "$(stat -c %a "$WORK_DIR")" == 700 ]]
[[ "$(stat -c %a "$WORK_DIR/.archcfg-build-iso")" == 600 ]]
prepare_build_directories
reject "$WORK_DIR" "$TEST_DIR/unmarked"
MOCK_MOUNT="$WORK_DIR/mounted" reject "$WORK_DIR" "$OUT_DIR"
MOCK_MOUNT="$TEST_DIR/space\\x20work/mounted" reject "$TEST_DIR/space work" "$OUT_DIR"
chmod 644 "$WORK_DIR/.archcfg-build-iso"
reject "$WORK_DIR" "$OUT_DIR"
chmod 600 "$WORK_DIR/.archcfg-build-iso"
reject "$OUT_DIR" "$WORK_DIR"
printf 'forged\n' > "$WORK_DIR/.archcfg-build-iso"
reject "$WORK_DIR" "$OUT_DIR"
printf '%s\n%s\n%s\n' "$REPO_ROOT" work "$WORK_DIR" > "$WORK_DIR/.archcfg-build-iso"
CLEAN=1
prepare_build_directories
[[ "$(wc -l < "$CALLS")" -eq 2 ]]
grep -qF -- "--one-file-system --preserve-root=all -- $WORK_DIR" "$CALLS"
[[ "$(<"$TEST_DIR/unmarked/valuable")" == keep ]]
printf 'build-iso safety tests passed\n'
