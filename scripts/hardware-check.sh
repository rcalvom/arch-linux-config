#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=../lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=../lib/hardware.sh
source "$SCRIPT_DIR/lib/hardware.sh"

mode=host target=/mnt disk= target_set=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      printf '%s\n' 'Usage: bash scripts/hardware-check.sh [--target PATH | --vm --disk DEVICE [--target PATH]]' \
        'No arguments: read-only host inventory. No network, mounts, writes or driver installation.' \
        'Exit codes: 0 supported, 2 warning (non-blocking), 1 unsupported, 64 usage error.'
      exit 0 ;;
    --vm) mode=vm; shift ;;
    --target | --disk)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || exit 64
      if [[ "$1" == --target ]]; then target=$2; target_set=1; else disk=$2; fi
      shift 2 ;;
    *) printf 'Invalid hardware-check option; use --help\n' >&2; exit 64 ;;
  esac
done
if [[ "$mode" == vm ]]; then
  [[ -n "$disk" ]] || exit 64
else
  [[ -z "$disk" ]] || exit 64
  [[ "$target_set" -eq 0 ]] || mode=safe
fi
hardware_preflight "$mode" "$target" "$disk"
