#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
script="$repo/scripts/install-vscode-extensions.sh"
output=$(bash "$script")
[[ "$output" == *'Extension: ms-python.python'* ]]
if bash "$script" --apply >/dev/null 2>&1; then
  printf 'Marketplace consent was not required\n' >&2
  exit 1
fi
if bash "$script" --unknown >/dev/null 2>&1; then exit 1; fi
printf 'PASS: extension planning and missing-consent rejection (no marketplace access)\n'
