#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=../lib/vbox.sh
source "$REPO_ROOT/lib/vbox.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/vbox-preflight.sh

Checks that regular-user VirtualBox ISO automation can run safely. It does not
repair the host driver, create a VM, or modify the repository.
USAGE
}

main() {
  case "${1-}" in
    "" )
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      vbox_die "Unknown argument: $1"
      ;;
  esac

  vbox_require_regular_user
  for command_name in VBoxManage base64 git openssl scp sha256sum ssh ssh-keygen ss stat tar tee; do
    vbox_require_command "$command_name"
  done

  [[ -d /sys/module/vboxdrv && -e /dev/vboxdrvu ]] || vbox_die "VirtualBox host driver is unavailable. An administrator must install matching kernel headers, rebuild/load vboxdrv, and reboot if needed."
  [[ -r /dev/vboxdrvu && -w /dev/vboxdrvu ]] || vbox_die "Current user cannot access /dev/vboxdrvu. Ask an administrator to grant the required VirtualBox device access."
  VBoxManage list vms >/dev/null

  [[ -z "$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)" ]] || vbox_die "Working tree is not clean; commit changes before building an ISO from HEAD"

  vbox_log_info "VirtualBox preflight passed"
  vbox_log_info "Runtime state: $ARCHCFG_VBOX_STATE_ROOT"
  vbox_log_info "Managed VM root: $ARCHCFG_VBOX_VM_ROOT"
}

main "$@"
