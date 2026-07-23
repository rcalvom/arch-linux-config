#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
ARCHCFG_SYS_CLASS_NET="$TEST_ROOT/net"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

# shellcheck source=../lib/network.sh
source "$REPO_DIR/lib/network.sh"

assert_equal() {
  local expected=$1
  local actual=$2

  [[ "$actual" == "$expected" ]] || {
    printf 'expected %q, got %q\n' "$expected" "$actual" >&2
    exit 1
  }
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
  assert_equal "$expected" "$actual"
}

mkdir -p "$ARCHCFG_SYS_CLASS_NET"
assert_status 1 select_wifi_interface auto
assert_equal none "$(select_wifi_interface none)"
assert_equal wlp2s0 "$(select_wifi_interface wlp2s0)"
assert_status 3 select_wifi_interface 'wlp2s0;rm'

mkdir -p "$ARCHCFG_SYS_CLASS_NET/enp0s3"
assert_status 4 select_wifi_interface enp0s3

mkdir -p "$ARCHCFG_SYS_CLASS_NET/wlp2s0/wireless"
assert_equal wlp2s0 "$(select_wifi_interface auto)"
assert_equal $'[keyfile]\nunmanaged-devices=interface-name:wlp2s0' "$(iwd_networkmanager_config wlp2s0)"

mkdir -p "$ARCHCFG_SYS_CLASS_NET/wlan1/wireless"
assert_status 2 select_wifi_interface auto
