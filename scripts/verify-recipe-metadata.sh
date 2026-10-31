#!/usr/bin/env bash
set -euo pipefail

# Disposable guest only: refresh an isolated metadata database, never install.
[[ $EUID == 0 ]] || { printf 'Run inside a disposable guest as root\n' >&2; exit 1; }
systemd-detect-virt --vm --quiet || { printf 'Refusing metadata fixture outside a VM\n' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
# Only public metadata lives here; pacman's unprivileged downloader must traverse it.
chmod 755 "$tmp"
mkdir "$tmp/db" "$tmp/cache"
# Live mirrorlists may still be commented before installer mirror refresh.
# Keep both repository choice and downloader sandbox explicit in this fixture.
cat > "$tmp/pacman.conf" <<'PACMAN'
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
DownloadUser = alpm
[core]
Server = https://geo.mirror.pkgbuild.com/core/os/$arch
[extra]
Server = https://geo.mirror.pkgbuild.com/extra/os/$arch
[multilib]
Server = https://geo.mirror.pkgbuild.com/multilib/os/$arch
PACMAN
bash "$repo/install.sh" --recipe ricardo --gpu software --aur --defer-manual --dry-run > "$tmp/plan"
packages=()
while read -r kind name rest; do
  case "$kind" in official | aur-dependency) packages+=("$name") ;; esac
done < "$tmp/plan"
pacman_args=(--config "$tmp/pacman.conf" --dbpath "$tmp/db" --cachedir "$tmp/cache")
pacman "${pacman_args[@]}" -Sy --noconfirm
pacman "${pacman_args[@]}" -Sp --noconfirm --print-format '%n %v' "${packages[@]}"
printf 'PASS: complete official recipe and AUR dependency transaction resolved; no packages installed\n'
