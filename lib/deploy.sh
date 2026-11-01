#!/usr/bin/env bash
set -euo pipefail

deploy_die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

deploy_relative() {
  [[ -n "$1" && "$1" != /* && "$1" != *'|'* && "$1" != *$'\n'* && "$1" != *$'\r'* ]] || deploy_die "Unsafe relative path: $1"
  case "/$1/" in */../* | */./* | *//*) deploy_die "Unsafe relative path: $1" ;; esac
}

deploy_safe_path() {
  local path=$1 leaf=true context=${2:-user}
  while [[ "$path" != / && -n "$path" ]]; do
    [[ ! -L "$path" ]] || deploy_die "Symlink rejected: $path"
    if [[ -e "$path" ]]; then
      "$leaf" || [[ -d "$path" ]] || deploy_die "Parent is not a directory: $path"
      [[ -O "$path" || -d "$path" || ( "$context" == source && $(stat -c %u -- "$path") == 0 ) ]] || deploy_die "Foreign file: $path"
      [[ -f "$path" || -d "$path" ]] || deploy_die "Special file rejected: $path"
    fi
    path=${path%/*}
    leaf=false
  done
}

deploy_fingerprint() {
  local path=$1 hash
  deploy_safe_path "$path"
  if [[ ! -e "$path" ]]; then printf 'absent\n'; return; fi
  [[ -f "$path" ]] || deploy_die "Not a regular file: $path"
  [[ $(stat -c %h -- "$path") == 1 ]] || deploy_die "Hard-linked file rejected: $path"
  hash=$(sha256sum < "$path")
  printf '%s:%s\n' "${hash%% *}" "$(stat -c %a -- "$path")"
}

# Expand the shipped four-column manifests without changing their format.
deploy_manifest() {
  local manifest=$1 base kind mode source destination extra file relative
  base=${manifest%/*}
  deploy_safe_path "$manifest" source
  [[ -f "$manifest" ]] || deploy_die "Missing manifest: $manifest"
  while IFS='|' read -r kind mode source destination extra || [[ -n "$kind" ]]; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    [[ -z "$extra" && "$mode" =~ ^0?[0-7]{3}$ ]] || deploy_die "Invalid manifest: $manifest"
    case "$kind" in
      root_file | root_tree) printf '[SKIP] System entry: %s\n' "$destination" >&2; continue ;;
      user_file | user_tree) ;;
      *) deploy_die "Unknown manifest kind: $kind" ;;
    esac
    deploy_relative "$destination"
    [[ "$destination" != .local/state/archcfg-deploy* ]] || deploy_die 'Destination overlaps deployment state'
    [[ "$source" == . && "$kind" == user_tree ]] || deploy_relative "$source"
    source="$base/$source"
    [[ "$source" != */. ]] || source=${source%/.}
    deploy_safe_path "$source" source
    if [[ "$kind" == user_file ]]; then
      deploy_add "$source" "$destination" "$mode"
    else
      [[ -d "$source" ]] || deploy_die "Missing tree: $source"
      while IFS= read -r -d '' file; do
        [[ -d "$file" && ! -L "$file" ]] && continue
        relative=${file#"$source"/}
        [[ "${relative##*/}" != files.conf ]] || continue
        deploy_add "$file" "$destination/$relative" "$mode"
      done < <(find "$source" -mindepth 1 -name __pycache__ -prune -o ! -name '*.py[co]' -print0)
    fi
  done < "$manifest"
}

deploy_add() {
  local source=$1 relative=$2 mode=$3
  deploy_relative "$relative"
  [[ "$relative" != .local/state/archcfg-deploy* ]] || deploy_die 'Destination overlaps deployment state'
  deploy_safe_path "$source" source
  [[ -f "$source" ]] || deploy_die "Missing or special source: $source"
  [[ ! -v seen["$relative"] ]] || deploy_die "Duplicate destination: $relative"
  seen["$relative"]=1
  sources+=("$source")
  destinations+=("$relative")
  printf -v mode '%o' "$((8#$mode))"
  modes+=("$mode")
  before+=("$(deploy_fingerprint "$home_dir/$relative")")
}

deploy_apply() {
  local module manifest i dest desired hash batch='' id
  local -a sources=() destinations=() modes=() before=() manifests=()
  local -A seen=() selected=()
  for module in "${modules[@]}"; do
    [[ "$module" =~ ^[a-zA-Z0-9_-]+$ ]] || deploy_die "Invalid module: $module"
    case "$module" in
      desktop) manifests+=("$repo_dir/wayland/files.conf") ;;
      all) manifests+=("$repo_dir/wayland/files.conf" "$repo_dir"/packages/*/files.conf) ;;
      *) manifests+=("$repo_dir/packages/$module/files.conf") ;;
    esac
  done
  for manifest in "${manifests[@]}"; do
    [[ ! -v selected["$manifest"] ]] || continue
    selected["$manifest"]=1
    deploy_manifest "$manifest"
  done
  if [[ "${hardware_profile:-none}" != none ]]; then
    deploy_manifest "$repo_dir/hardware/$hardware_profile/files.conf"
  fi
  for i in "${!sources[@]}"; do
    dest="$home_dir/${destinations[i]}"
    hash=$(sha256sum < "${sources[i]}")
    desired="${hash%% *}:${modes[i]}"
    if [[ "${before[i]}" == "$desired" ]]; then
      printf '[UNCHANGED] %s\n' "${destinations[i]}"
      continue
    fi
    if [[ "${before[i]}" != absent ]] && ! "$replace"; then
      printf '[PRESERVE] %s\n' "${destinations[i]}"
      continue
    fi
    printf '[WRITE] %s\n' "${destinations[i]}"
    "$apply" || continue
    if [[ -z "$batch" ]]; then
      batch=$(mktemp -d "$state_dir/run.XXXXXXXX")
      printf '[BACKUP] %s\n' "${batch##*/}"
      : > "$batch/records"
    fi
    [[ "$(deploy_fingerprint "$dest")" == "${before[i]}" ]] || deploy_die "Changed during deployment: $dest"
    id=$i
    if [[ "${before[i]}" != absent ]]; then cp -p -- "$dest" "$batch/$id.before"; fi
    install -m "${modes[i]}" -- "${sources[i]}" "$batch/$id.after"
    # Journal before writing so interrupted runs retain recovery information.
    printf '%s|%s|%s|%s\n' "$id" "${destinations[i]}" "${before[i]}" "$(deploy_fingerprint "$batch/$id.after")" >> "$batch/records"
    install -D -m "${modes[i]}" -- "$batch/$id.after" "$dest"
  done
}

deploy_rollback() {
  local run=$1 batch id relative old expected extra dest i
  local -a ids=() paths=() originals=() installed=()
  [[ "$run" =~ ^run\.[a-zA-Z0-9]+$ ]] || deploy_die 'Invalid rollback ID'
  batch="$state_dir/$run"
  deploy_safe_path "$batch/records"
  deploy_safe_path "$batch/rolled-back"
  [[ -f "$batch/records" && ! -e "$batch/rolled-back" ]] || deploy_die 'Unknown or already rolled-back deployment'
  # Preflight the entire transaction before restoring any file.
  while IFS='|' read -r id relative old expected extra; do
    [[ "$id" =~ ^[0-9]+$ && -z "$extra" ]] || deploy_die 'Invalid backup record'
    deploy_relative "$relative"
    [[ "$relative" != .local/state/archcfg-deploy* ]] || deploy_die 'Invalid backup destination'
    dest="$home_dir/$relative"
    [[ "$(deploy_fingerprint "$batch/$id.after")" == "$expected" ]] || deploy_die 'Damaged deployment snapshot'
    if [[ "$old" != absent ]]; then
      [[ "$(deploy_fingerprint "$batch/$id.before")" == "$old" ]] || deploy_die 'Damaged original snapshot'
    fi
    [[ "$(deploy_fingerprint "$dest")" == "$expected" ]] || deploy_die "Rollback conflict; nothing restored: $relative"
    ids+=("$id"); paths+=("$relative"); originals+=("$old"); installed+=("$expected")
  done < "$batch/records"
  for i in "${!ids[@]}"; do
    dest="$home_dir/${paths[i]}"
    printf '[RESTORE] %s\n' "${paths[i]}"
    "$apply" || continue
    [[ "$(deploy_fingerprint "$dest")" == "${installed[i]}" ]] || deploy_die "Concurrent change: $dest"
    if [[ "${originals[i]}" == absent ]]; then
      rm -- "$dest"
    else
      cp -p -- "$batch/${ids[i]}.before" "$dest"
    fi
  done
  if "$apply"; then : > "$batch/rolled-back"; fi
}
