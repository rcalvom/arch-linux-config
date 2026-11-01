#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/deploy.sh
source "$repo_dir/lib/deploy.sh"

apply=false
replace=false
rollback=
modules=()
hardware_profile=none
usage() {
  printf '%s\n' 'Usage: bash apply-config.sh [--dry-run | --apply] [--module NAME]... [--replace]' \
    '       bash apply-config.sh [--dry-run | --apply] --rollback ID' \
    'Modules: desktop (default), package directory names, or all. --replace backs up differing files.' \
    'Optional: --hardware-profile none|ricardo (never selected by all).'
}
mode_set=false
while (($#)); do
  case "$1" in
    --dry-run | --apply)
      "$mode_set" && deploy_die 'Choose only one execution mode'
      mode_set=true
      [[ "$1" != --apply ]] || apply=true
      shift ;;
    --module | --rollback)
      (($# >= 2)) && [[ -n "$2" ]] || deploy_die "Missing value for $1"
      if [[ "$1" == --module ]]; then modules+=("$2"); else rollback=$2; fi
      shift 2 ;;
    --replace) replace=true; shift ;;
    --hardware-profile)
      (($# >= 2)) || deploy_die 'Missing hardware profile'
      case "$2" in none | ricardo) hardware_profile=$2 ;; *) deploy_die "Invalid hardware profile: $2" ;; esac
      shift 2 ;;
    --help | -h) usage; exit 0 ;;
    *) deploy_die "Unknown argument: $1" ;;
  esac
done
[[ $EUID != 0 && -z ${SUDO_USER:-} ]] || deploy_die 'Run as the intended user, without sudo'
home_dir=${HOME:?HOME is required}
[[ "$home_dir" == /* && "$home_dir" != / ]] || deploy_die 'HOME must be an absolute user directory'
home_dir=${home_dir%/}
[[ "$(realpath -ms -- "$home_dir")" == "$home_dir" ]] || deploy_die 'HOME must not contain dot components or repeated slashes'
deploy_safe_path "$home_dir"
[[ -d "$home_dir" && -O "$home_dir" ]] || deploy_die 'HOME must exist and belong to the current user'
home_dir=${home_dir%/}
state_dir="$home_dir/.local/state/archcfg-deploy"
deploy_safe_path "$state_dir"
deploy_safe_path "$state_dir/lock"
if "$apply"; then
  umask 077
  mkdir -p -- "$state_dir"
  exec 9>"$state_dir/lock"
  flock -n 9 || deploy_die 'Another deployment is running'
fi
if [[ -n "$rollback" ]]; then
  ((${#modules[@]} == 0)) && ! "$replace" && [[ "$hardware_profile" == none ]] || deploy_die 'Rollback cannot be combined with selections or --replace'
  deploy_rollback "$rollback"
else
  ((${#modules[@]})) || modules=(desktop)
  deploy_apply
fi
