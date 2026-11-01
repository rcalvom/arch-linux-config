#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
unset SUDO_USER
mkdir "$HOME"
run() { bash "$repo/apply-config.sh" "$@"; }
run --module all > "$tmp/plan"
[[ -z $(ls -A "$HOME") ]]
run --module all --apply > "$tmp/first"
[[ ! -e "$HOME/.config/archcfg/display-profiles.json" ]]
run --module all --apply > "$tmp/second"
if grep -q '\[WRITE\]\|\[BACKUP\]' "$tmp/second"; then exit 1; fi
printf 'private-provider-settings\n' > "$HOME/.config/cliamp/config.toml"
run --module cliamp --apply > "$tmp/preserve"
[[ $(< "$HOME/.config/cliamp/config.toml") == private-provider-settings ]]
chmod 600 "$HOME/.config/cliamp/config.toml"
run --module cliamp --replace --apply > "$tmp/replace"
batch=$(sed -n 's/^\[BACKUP\] //p' "$tmp/replace")
[[ $(stat -c %a "$HOME/.local/state/archcfg-deploy/$batch") == 700 ]]
run --rollback "$batch" > "$tmp/rollback-plan"
cmp "$repo/packages/cliamp/config.toml" "$HOME/.config/cliamp/config.toml"
printf 'later-local-edit\n' > "$HOME/.config/cliamp/config.toml"
if run --rollback "$batch" --apply > "$tmp/conflict" 2>&1; then exit 1; fi
[[ $(< "$HOME/.config/cliamp/config.toml") == later-local-edit ]]
install -m644 "$repo/packages/cliamp/config.toml" "$HOME/.config/cliamp/config.toml"
run --rollback "$batch" --apply > "$tmp/rollback"
[[ $(< "$HOME/.config/cliamp/config.toml") == private-provider-settings ]]
[[ $(stat -c %a "$HOME/.config/cliamp/config.toml") == 600 ]]
run --module desktop --hardware-profile ricardo --apply > "$tmp/hardware"
cmp "$repo/hardware/ricardo/display-profiles.json" "$HOME/.config/archcfg/display-profiles.json"
cmp "$repo/hardware/ricardo/hardware.lua" "$HOME/.config/archcfg/hardware.lua"
batch=$(sed -n 's/^\[BACKUP\] //p' "$tmp/hardware")
run --rollback "$batch" --apply > "$tmp/hardware-rollback"
[[ ! -e "$HOME/.config/archcfg/display-profiles.json" ]]
[[ ! -e "$HOME/.config/archcfg/hardware.lua" ]]
printf 'PASS: real manifests, idempotency, private-file preservation, replacement and hardware rollback\n'
