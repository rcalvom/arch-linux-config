#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
source "$repo/lib/install.sh"
source "$repo/lib/source-snapshot.sh"
log_info() { :; }
die() { printf '%s\n' "$*" >&2; exit 1; }
chown() { :; }
mkdir -p "$test_dir/source" "$test_dir/target" "$test_dir/iso" "$test_dir/evidence"
git -C "$test_dir/source" init -q
printf 'original\n' > "$test_dir/source/code.sh"
printf 'deleted tracked file\n' > "$test_dir/source/deleted.sh"
printf 'ignored/\n' > "$test_dir/source/.gitignore"
git -C "$test_dir/source" add .
rm "$test_dir/source/deleted.sh"
printf 'dirty tracked content\n' > "$test_dir/source/code.sh"
printf 'new content\n' > "$test_dir/source/new.sh"
mkdir "$test_dir/source/ignored"
printf 'private fixture\n' > "$test_dir/source/ignored/private.txt"
printf 'private fixture\n' > "$test_dir/source/.env"
copy_repo_to_target "$test_dir/source" "$test_dir/target" /opt/archcfg
dest="$test_dir/target/opt/archcfg"
source_tree_verify "$dest"
cmp "$test_dir/source/code.sh" "$dest/code.sh"
[[ -f "$dest/new.sh" && ! -e "$dest/deleted.sh" && ! -e "$dest/.git" && ! -e "$dest/.env" && ! -e "$dest/ignored" ]]
source_snapshot_create "$test_dir/source" "$test_dir/source.tar" worktree "$test_dir/evidence"
tar -xf "$test_dir/source.tar" -C "$test_dir/iso"
printf 'private fixture\n' > "$test_dir/iso/unlisted-secret"
copy_repo_to_target "$test_dir/iso" "$test_dir/target" /opt/archcfg
source_tree_verify "$dest"
[[ ! -e "$dest/unlisted-secret" ]]
printf 'tampered\n' > "$test_dir/iso/code.sh"
if (copy_repo_to_target "$test_dir/iso" "$test_dir/target" /opt/archcfg); then exit 1; fi
source_tree_verify "$dest"
if (copy_repo_to_target "$test_dir/source" / /opt/archcfg); then exit 1; fi
mkdir "$test_dir/unverified"
if (copy_repo_to_target "$test_dir/unverified" "$test_dir/target" /opt/archcfg); then exit 1; fi
printf '%s%s\n' '-----BEGIN ' 'PRIVATE KEY-----' > "$test_dir/source/unsafe.txt"
if (copy_repo_to_target "$test_dir/source" "$test_dir/target" /opt/archcfg); then exit 1; fi
source_tree_verify "$dest"
printf 'Source installation fixtures passed\n'
