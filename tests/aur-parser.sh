#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

# shellcheck source=../scripts/packages.sh
source "$REPO_DIR/scripts/packages.sh"
# shellcheck source=../scripts/aur.sh
source "$REPO_DIR/scripts/aur.sh"

packages=()
revisions=()
load_aur_packages_from_files packages revisions "$REPO_DIR/packages/aur.txt"

[[ "${#packages[@]}" -eq 4 ]]
[[ "${packages[0]}" == cliamp ]]
[[ "${revisions[0]}" =~ ^[[:xdigit:]]{40}$ ]]
[[ "${packages[1]}" == opencode-notifier ]]
[[ "${revisions[1]}" == de186d859a034a05a3f4156cdd478e80ecb47bdb ]]
[[ "${packages[3]}" == visual-studio-code-bin ]]
[[ " ${packages[*]} " != *" opencode-bin "* ]]
grep -qxF bun "$REPO_DIR/packages/aur-deps.txt"
