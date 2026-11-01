#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
SMOKE_SCRIPT="$REPO_DIR/scripts/e2e-guest-smoke.sh"
E2E_SCRIPT="$REPO_DIR/scripts/vbox-e2e.sh"

fail() {
  printf 'test failure: %s\n' "$*" >&2
  exit 1
}

bash -n "$SMOKE_SCRIPT"
"$SMOKE_SCRIPT" --help >/dev/null

grep -Fq 'check_network_stack' "$SMOKE_SCRIPT" || fail 'smoke test does not check networking'
grep -Fq 'check_desktop_commands' "$SMOKE_SCRIPT" || fail 'smoke test does not check desktop commands'
grep -Fq 'docker.service' "$SMOKE_SCRIPT" || fail 'smoke test does not check Docker'
grep -Fq 'vboxservice.service' "$SMOKE_SCRIPT" || fail 'smoke test does not check VirtualBox services'
grep -Fq 'e2e-guest-smoke.sh --mode live' "$E2E_SCRIPT" || fail 'E2E runner does not run live smoke checks'
grep -Fq -- '--mode installed' "$E2E_SCRIPT" || fail 'E2E runner does not run installed smoke checks'
