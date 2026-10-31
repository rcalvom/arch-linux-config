#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
apply=false
consent=false
for arg in "$@"; do
  case "$arg" in
    --apply) apply=true ;;
    --consent-marketplace) consent=true ;;
    --help) printf '%s\n' 'Usage: install-vscode-extensions.sh [--apply --consent-marketplace]'; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 1 ;;
  esac
done
[[ $EUID != 0 && -z ${SUDO_USER:-} ]] || { printf 'Run as the target user without sudo.\n' >&2; exit 1; }
ids=()
while IFS= read -r id || [[ -n "$id" ]]; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  [[ "$id" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]] || { printf 'Invalid extension ID\n' >&2; exit 1; }
  ids+=("$id")
done < "$repo/packages/vscode/extensions.txt"
printf 'Extension: %s\n' "${ids[@]}"
"$apply" || exit 0
"$consent" || { printf 'Marketplace access requires --consent-marketplace.\n' >&2; exit 1; }
[[ -x /usr/bin/code && $(/usr/bin/pacman -Qqo /usr/bin/code) == visual-studio-code-bin ]] || {
  printf 'Expected /usr/bin/code owned by visual-studio-code-bin.\n' >&2; exit 1;
}
for id in "${ids[@]}"; do
  /usr/bin/code --install-extension "$id"
done
