#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../scripts/vbox-e2e.sh
source "$REPO_DIR/scripts/vbox-e2e.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT
CALLS="$TEST_DIR/calls"
E2E_DIR=$TEST_DIR
LIVE_SSH_KEY="$TEST_DIR/key"
SSH_PORT=22222
SOURCE_TREE_SHA256=$(printf 'a%.0s' {1..64})
vbox_ssh() { printf '%s\n' "$*" >> "$CALLS"; }
VBoxManage() { exit 99; }
parse_args --snapshot-worktree --safe --manifest "$TEST_DIR/manifest"
[[ $SNAPSHOT_WORKTREE -eq 1 && $INSTALL_MODE == safe ]]
run_install
calls=$(<"$CALLS")
[[ "$calls" == *'e2e-prepare-safe.sh --vm --disk /dev/sda'* ]]
[[ "$calls" == *'archcfg-install --target /mnt'* && "$calls" != *'--user-password-file'* ]]
[[ "$calls" == *'cmp /run/archcfg-safe-before /run/archcfg-safe-after'* ]]
[[ "$calls" == *'sha256sum -c /run/archcfg-safe-witnesses'* ]]
: > "$CALLS"
INSTALL_MODE=vm
run_install
calls=$(<"$CALLS")
[[ "$calls" == *'--disk /dev/sda'* && "$calls" == *'--user-password-file'* ]]
[[ "$calls" != *'e2e-prepare-safe.sh'* ]]
: > "$CALLS"
verify_guest_source live "$TEST_DIR/verify.log"
calls=$(<"$CALLS")
[[ "$calls" == *'source_tree_verify /opt/arch-linux-config'* && "$calls" == *"$SOURCE_TREE_SHA256"* ]]
if (parse_args --unknown) >/dev/null 2>&1; then exit 1; fi
if bash "$REPO_DIR/scripts/e2e-prepare-safe.sh" --vm --disk /dev/sdb; then exit 1; fi
: > "$CALLS"
VM_NAME=archcfg-e2e-test-fixture
VBoxManage() { printf '%s\n' "$*" >> "$CALLS"; }
login_live_desktop
calls=$(< "$CALLS")
[[ "$calls" == *'keyboardputstring live'* && "$calls" == *'keyboardputscancode 1c 9c'* ]]
[[ "$calls" == *'pgrep -u live -x Hyprland'* && "$calls" == *'waybar.service'* ]]
[[ "$calls" == *'hyprctl -j instances | jq -e "length == 1"'* ]]
: > "$CALLS"
TARGET_PASSWORD_FILE="$TEST_DIR/password"
printf 'fixture-password\n' > "$TARGET_PASSWORD_FILE"
sleep() { :; }
login_installed_desktop
calls=$(< "$CALLS")
[[ "$calls" == *'keyboardputstring archcfg'* && "$calls" == *'keyboardputstring fixture-password'* ]]
[[ "$calls" == *'keyboardputscancode 35 b5'* && "$calls" == *'keyboardputstring e2e'* ]]
[[ "$calls" == *'wireplumber.service'* && "$calls" == *'installed-screen.png'* ]]
[[ "$calls" == *'test ! -e "$HOME/.config/archcfg/hardware.lua"'* ]]
for status in 0 1 2 3 255; do
  vbox_ssh() {
    if [[ "$*" == *verify-hardware.sh* ]]; then return "$status"; fi
    return 0
  }
  actual=0
  run_postboot_checks || actual=$?
  if [[ "$status" == 0 || "$status" == 3 ]]; then
    [[ "$actual" == 0 ]]
  else
    [[ "$actual" == "$status" ]]
  fi
  [[ $(< "$E2E_DIR/verify-hardware-status") == "exit_code=$status" ]]
done
printf 'VirtualBox E2E mocks passed\n'
