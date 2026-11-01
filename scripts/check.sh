#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo"

case "${1:-}" in
  '') ;;
  --lint) ;;
  *) printf 'Usage: bash scripts/check.sh [--lint]\n' >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Too many arguments\n' >&2; exit 2; }

# Tests use private fixtures and mocked system commands, never real disks/services.
mkdir -p /tmp/opencode
export TMPDIR=/tmp/opencode
mapfile -d '' -t shell_files < <(find lib scripts tests -type f -name '*.sh' -print0)
shell_files+=(install.sh postinstall.sh apply-config.sh packages/calcurse/archcfg-calcurse-google)
for file in "${shell_files[@]}"; do
  bash -n "$file"
done
printf 'PASS: Bash syntax\n'

if [[ ${1:-} == --lint ]]; then
  command -v shellcheck >/dev/null || { printf 'ShellCheck is required for --lint\n' >&2; exit 1; }
  # Error-level findings block CI; warnings remain a separate cleanup task.
  shellcheck --severity=error --external-sources "${shell_files[@]}"
fi

for name in \
  package-profiles recipe aur-parser install-safety install-password-file \
  source-install source-snapshot build-iso-args build-iso-safety \
  vbox-helpers vbox-e2e-mocks config-cache-exclusion \
  calcurse-google-cache calcurse-google-notify calcurse-local-notify \
  printing-backup greetd-config mirror-refresh; do
  printf '\n[TEST] %s\n' "$name"
  bash "tests/$name.sh"
done

for name in preferences-portable hyprlock-config greeter-theme-helper grub-profile; do
  printf '\n[TEST] %s\n' "$name"
  python3 "tests/$name.py"
done
node --test packages/openclaw-meeting-audio/test.mjs
git diff --check
printf '\nPASS: local regression suite\n'
