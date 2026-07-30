#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
HOOK="$REPO_DIR/live/airootfs/root/customize_airootfs.sh"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

for account_file in passwd group shadow gshadow; do
  [[ ! -e "$REPO_DIR/live/airootfs/etc/$account_file" ]] || {
    die "Live account database must not be versioned: $account_file"
  }
done

[[ -x "$HOOK" ]] || die "Live account hook must be executable."
bash -n "$HOOK"
rg -q 'systemd-sysusers /usr/lib/sysusers\.d/greetd\.conf' "$HOOK" || {
  die "Live account hook must create the greetd service user."
}
rg -q 'live:live' "$HOOK" || die "Live account hook must set the documented live password."
