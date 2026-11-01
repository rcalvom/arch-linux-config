#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
[[ $EUID != 0 ]] || { printf 'Run this test as an unprivileged user.\n' >&2; exit 1; }
# Read-only ownership fixture: root-owned sources are valid, destinations are not.
source "$repo/lib/deploy.sh"
deploy_safe_path /usr/bin/bash source
if (deploy_safe_path /usr/bin/bash) >/dev/null 2>&1; then
  printf 'Root-owned destination was accepted\n' >&2
  exit 1
fi
mkdir -p "$tmp/home" "$tmp/repo/lib" "$tmp/repo/packages/sample" "$tmp/mocks"
cp "$repo/apply-config.sh" "$tmp/repo/"
cp "$repo/lib/deploy.sh" "$tmp/repo/lib/"
printf 'user_file|0644|one|.config/demo/one\nuser_file|0755|two|.local/bin/two\n' > "$tmp/repo/packages/sample/files.conf"
printf 'one\n' > "$tmp/repo/packages/sample/one"
printf 'two\n' > "$tmp/repo/packages/sample/two"
for command in sudo systemctl pacman yay paru; do
  printf '#!/bin/sh\nexit 99\n' > "$tmp/mocks/$command"
  chmod +x "$tmp/mocks/$command"
done
export PATH="$tmp/mocks:$PATH"
export HOME="$tmp/home"
unset SUDO_USER
run() { bash "$tmp/repo/apply-config.sh" "$@"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if run "$@" > "$tmp/rejected" 2>&1; then fail "Accepted $*"; fi; }
run --module sample > "$tmp/plan"
[[ -z $(ls -A "$HOME") ]] || fail 'Dry run wrote files'
reject --unknown
reject --module
reject --apply --dry-run
reject --hardware-profile
reject --hardware-profile unknown
reject --rollback
reject --rollback ../escape
reject --rollback run.fake --module sample
reject --rollback run.fake --replace
reject --rollback run.fake --hardware-profile ricardo
reject --replace=true
reject --module ../sample
reject --module nonexistent
run --apply --module sample > "$tmp/applied"
cmp "$HOME/.config/demo/one" "$tmp/repo/packages/sample/one"
[[ $(stat -c %a "$HOME/.local/bin/two") == 755 ]] || fail 'Wrong installed mode'
printf 'unmanaged\n' > "$HOME/.config/demo/unmanaged"
batches=("$HOME"/.local/state/archcfg-deploy/run.*)
first=${batches[0]##*/}
run --apply --module sample > "$tmp/repeated"
batches=("$HOME"/.local/state/archcfg-deploy/run.*)
[[ ${#batches[@]} == 1 ]] || fail 'Idempotent run made backup'
printf 'local\n' > "$HOME/.config/demo/one"
chmod 600 "$HOME/.config/demo/one"
run --apply --module sample > "$tmp/preserved"
[[ $(< "$HOME/.config/demo/one") == local ]] || fail 'Modified content overwritten'
[[ $(stat -c %a "$HOME/.config/demo/one") == 600 ]] || fail 'Modified mode overwritten'
reject --apply --rollback "$first"
[[ -f "$HOME/.local/bin/two" ]] || fail 'Conflicting rollback partially restored files'
run --apply --module sample --replace > "$tmp/replaced"
second=
for batch in "$HOME"/.local/state/archcfg-deploy/run.*; do
  [[ "${batch##*/}" == "$first" ]] || second=${batch##*/}
done
[[ -n "$second" ]] || fail 'Replacement did not create backup'
run --rollback "$second" > "$tmp/rollback-plan"
cmp "$HOME/.config/demo/one" "$tmp/repo/packages/sample/one"
run --apply --rollback "$second" > "$tmp/restored"
[[ $(< "$HOME/.config/demo/one") == local ]] || fail 'Original content not restored'
[[ $(stat -c %a "$HOME/.config/demo/one") == 600 ]] || fail 'Original permissions not restored'
reject --apply --rollback "$second"
install -m644 "$tmp/repo/packages/sample/one" "$HOME/.config/demo/one"
run --apply --rollback "$first" > "$tmp/removed"
[[ ! -e "$HOME/.config/demo/one" && ! -e "$HOME/.local/bin/two" ]] || fail 'Original absence not restored'
[[ $(< "$HOME/.config/demo/unmanaged") == unmanaged ]] || fail 'Unmanaged file changed'
rm "$HOME/.config/demo/unmanaged"
mkdir "$tmp/outside"
rmdir "$HOME/.config/demo"
ln -s "$tmp/outside" "$HOME/.config/demo"
reject --apply --module sample
[[ -z $(ls -A "$tmp/outside") ]] || fail 'Followed parent symlink'
rm "$HOME/.config/demo"
mkdir "$HOME/.config/demo"
ln -s "$tmp/outside/missing" "$HOME/.config/demo/one"
reject --apply --module sample
rm "$HOME/.config/demo/one"
printf 'outside\n' > "$tmp/outside/linked"
ln "$tmp/outside/linked" "$HOME/.config/demo/one"
reject --apply --module sample --replace
[[ $(< "$tmp/outside/linked") == outside ]] || fail 'Hard-linked file overwritten'
rm "$HOME/.config/demo/one"
rmdir "$HOME/.config/demo"
printf 'not a directory\n' > "$HOME/.config/demo"
reject --apply --module sample
rm "$HOME/.config/demo"
mkdir "$HOME/.config/demo"
rm "$HOME/.local/state/archcfg-deploy/lock"
ln -s "$tmp/outside/linked" "$HOME/.local/state/archcfg-deploy/lock"
reject --apply --module sample
[[ $(< "$tmp/outside/linked") == outside ]] || fail 'Followed lock symlink'
rm "$HOME/.local/state/archcfg-deploy/lock"
ln -s "$tmp/outside" "$tmp/repo/packages/sample/one-link"
printf 'user_tree|0644|.|.config/sample\n' > "$tmp/repo/packages/sample/files.conf"
reject --apply --module sample
rm "$tmp/repo/packages/sample/one-link"
run --apply --module sample > "$tmp/tree"
[[ -f "$HOME/.config/sample/one" && ! -e "$HOME/.config/sample/files.conf" ]] || fail 'Shipped tree semantics changed'
printf 'user_file|0644|one|../escape\n' > "$tmp/repo/packages/sample/files.conf"
reject --apply --module sample
printf 'root_file|0644|one|/etc/archcfg-deploy-test\n' > "$tmp/repo/packages/sample/files.conf"
run --apply --module sample > "$tmp/root-skipped" 2>&1
printf 'PASS: deploy planning, preservation, backups, rollback, trees and path safety\n'
