#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
for profile in minimal desktop developer virtualbox; do
  for existing in 0 1; do
    bash -euo pipefail -c '
      source "$1/scripts/users.sh"
      existing=$2
      changed=0
      log_info() { :; }
      die() { printf "%s\n" "$*" >&2; exit 1; }
      id() { [[ "$*" == "-u fixture" ]] || die "Unexpected identity lookup"; (( existing )); }
      getent() { [[ "$*" == "passwd fixture" ]] || die "Unexpected group lookup"; }
      useradd() {
        [[ "$*" == "-m -G wheel,video,audio,storage,input fixture" && "$existing" == 0 ]] || die "Unexpected new-user groups"
        changed=1
      }
      usermod() {
        [[ "$*" == "-aG wheel,video,audio,storage,input fixture" && "$existing" == 1 ]] || die "Existing groups were replaced"
        changed=1
      }
      gpasswd() { die "Existing membership must not be removed"; }
      chsh() { :; }
      runuser() { die "Unexpected user command"; }
      # Stop before any system file writes; all preceding host operations are mocked.
      install() { [[ "$changed" == 1 && "$*" == "-dm755 /etc/sudoers.d" ]] || exit 1; exit 0; }
      configure_initial_user fixture "$3"
      exit 1
    ' bash "$repo" "$existing" "$profile"
  done
done
printf 'PASS: sudo Docker policy and existing membership preservation (8 cases)\n'
