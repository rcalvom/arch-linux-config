#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/source/nested/__pycache__" "$tmp/home"
printf 'source\n' > "$tmp/source/nested/code.py"
printf 'cache\n' > "$tmp/source/nested/__pycache__/code.cpython.pyc"
printf 'cache\n' > "$tmp/source/nested/code.pyc"
printf 'cache\n' > "$tmp/source/nested/code.pyo"
printf 'user_tree|644|source|.config/fixture\n' > "$tmp/files.conf"
source "$repo/lib/deploy.sh"
sources=() destinations=() modes=() before=()
declare -A seen=()
home_dir="$tmp/home"
deploy_manifest "$tmp/files.conf"
[[ ${#sources[@]} == 1 && ${destinations[0]} == .config/fixture/nested/code.py ]]
source "$repo/scripts/dotfiles.sh"
die() { printf '%s\n' "$*" >&2; exit 1; }
chown() { :; }
install_user_tree "$tmp/source" "$tmp/installed" fixture 644
source "$repo/live/airootfs/usr/local/bin/archcfg-live-session"
install_live_tree "$tmp/source" "$tmp/live" 644
for context in installed live; do
  cmp "$tmp/source/nested/code.py" "$tmp/$context/nested/code.py"
  [[ ! -e "$tmp/$context/nested/__pycache__" ]]
  [[ ! -e "$tmp/$context/nested/code.pyc" && ! -e "$tmp/$context/nested/code.pyo" ]]
done
printf 'PASS: Python cache exclusion in user, installed and live mappings\n'
