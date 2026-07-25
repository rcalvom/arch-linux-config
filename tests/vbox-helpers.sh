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

assert_equal() {
  [[ "$1" == "$2" ]] || fail "expected $1, got $2"
}

MOCK_BIN="$TEST_ROOT/bin"
VBOX_MOCK_LOG="$TEST_ROOT/vbox.log"
mkdir -p "$MOCK_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\n" "$*" >> "$VBOX_MOCK_LOG"' \
  'case "$1" in' \
  '  modifyvm)' \
  '    [[ "${VBOX_MOCK_FAILURE:-}" == modifyvm ]] && exit 1' \
  '    exit 0' \
  '    ;;' \
  '  storageattach)' \
  '    [[ "${VBOX_MOCK_FAILURE:-}" == storageattach ]] && exit 1' \
  '    exit 0' \
  '    ;;' \
  '  *)' \
  '    exit 0' \
  '    ;;' \
  'esac' > "$MOCK_BIN/VBoxManage"
chmod 755 "$MOCK_BIN/VBoxManage"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "ssh %s\n" "$*" >> "$VBOX_MOCK_LOG"' > "$MOCK_BIN/ssh"
chmod 755 "$MOCK_BIN/ssh"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "scp %s\n" "$*" >> "$VBOX_MOCK_LOG"' > "$MOCK_BIN/scp"
chmod 755 "$MOCK_BIN/scp"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'exit 0' > "$MOCK_BIN/ss"
chmod 755 "$MOCK_BIN/ss"

export PATH="$MOCK_BIN:$PATH"
export VBOX_MOCK_LOG
export ARCHCFG_VBOX_STATE_ROOT="$TEST_ROOT/state"
export ARCHCFG_VBOX_VM_ROOT="$TEST_ROOT/vms"

# shellcheck source=../lib/vbox.sh
source "$REPO_DIR/lib/vbox.sh"

assert_status 0 vbox_run_id_is_valid 20260724t010203z-1a2b
assert_status 1 vbox_run_id_is_valid '../unsafe'
assert_status 0 vbox_managed_vm_name_is_valid archcfg-e2e-build-20260724t010203z-1a2b
assert_status 0 vbox_managed_vm_name_is_valid archcfg-e2e-test-20260724t010203z-1a2b
assert_status 1 vbox_managed_vm_name_is_valid 'Testing Live Iso'

manifest="$TEST_ROOT/manifest"
printf 'schema=1\nrun_id=20260724t010203z-1a2b\niso=/tmp/archcfg.iso\niso_sha256=checksum-value\n' > "$manifest"
assert_equal 20260724t010203z-1a2b "$(vbox_manifest_value "$manifest" run_id)"
assert_equal /tmp/archcfg.iso "$(vbox_manifest_value "$manifest" iso)"
assert_equal checksum-value "$(vbox_manifest_value "$manifest" iso_sha256)"

printf 'run_id=duplicate\n' >> "$manifest"
assert_status 1 vbox_manifest_value "$manifest" run_id

bootstrap_iso="$TEST_ROOT/bootstrap.iso"
: > "$bootstrap_iso"
export VBOX_MOCK_FAILURE=modifyvm
assert_status 1 vbox_create_efi_vm archcfg-e2e-build-20260724t010203z-1a2b 2048 2 1024 "$bootstrap_iso"
[[ "$(<"$VBOX_MOCK_LOG")" == *'unregistervm archcfg-e2e-build-20260724t010203z-1a2b --delete'* ]] || fail "partial VM creation was not rolled back"

: > "$VBOX_MOCK_LOG"
export VBOX_MOCK_FAILURE=storageattach
assert_status 1 vbox_create_efi_vm archcfg-e2e-build-20260724t010203z-1a2b 2048 2 1024 "$bootstrap_iso"
[[ "$(<"$VBOX_MOCK_LOG")" == *'closemedium disk '* ]] || fail "unattached VDI was not removed during rollback"
unset VBOX_MOCK_FAILURE

: > "$VBOX_MOCK_LOG"
vbox_configure_nat_ssh test-vm 22222
vbox_console_run test-vm 'echo bootstrap'
[[ "$(<"$VBOX_MOCK_LOG")" == *'--natpf1 archcfg-ssh,tcp,127.0.0.1,22222,,22'* ]] || fail "NAT SSH forwarding was not configured"
[[ "$(<"$VBOX_MOCK_LOG")" == *'keyboardputstring echo bootstrap'* ]] || fail "console bootstrap command was not sent"

: > "$VBOX_MOCK_LOG"
vbox_ssh test-user /tmp/test-key 22222 true
vbox_scp_to test-user /tmp/test-key 22222 "$bootstrap_iso" /guest/source.tar
vbox_scp_from test-user /tmp/test-key 22222 /guest/out "$TEST_ROOT/artifacts/out"
[[ "$(<"$VBOX_MOCK_LOG")" == *'ssh -i /tmp/test-key -p 22222'* ]] || fail "SSH command was not configured"
[[ "$(<"$VBOX_MOCK_LOG")" == *"scp -i /tmp/test-key -P 22222"* ]] || fail "SCP command was not configured"

bootstrap_key="$TEST_ROOT/bootstrap-key"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA archcfg-e2e\n' > "$bootstrap_key.pub"
: > "$bootstrap_key"
: > "$VBOX_MOCK_LOG"
vbox_bootstrap_official_ssh test-vm "$bootstrap_key" 22222 1
[[ "$(<"$VBOX_MOCK_LOG")" == *'keyboardputstring install -dm700 /root/.ssh'* ]] || fail "official ISO SSH bootstrap command was not sent"
