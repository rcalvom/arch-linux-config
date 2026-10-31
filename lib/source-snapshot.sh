#!/usr/bin/env bash
set -euo pipefail

# Canonical GNU tar binds file bytes, modes, paths and symlink targets, not mtimes.
source_tree_hash() {
  local root=$1
  tar --format=gnu --mtime=@0 --owner=0 --group=0 --numeric-owner \
    --hard-dereference --no-recursion -C "$root" \
    --null -T "$root/.archcfg-source.files" -cf - | sha256sum | cut -d ' ' -f 1
}

source_tree_verify() {
  local root=$1 expected
  [[ -f "$root/.archcfg-source.sha256" && ! -L "$root/.archcfg-source.sha256" &&
     -f "$root/.archcfg-source.files" && ! -L "$root/.archcfg-source.files" ]] || return 1
  expected=$(<"$root/.archcfg-source.sha256")
  [[ "$expected" =~ ^[a-f0-9]{64}$ ]] || return 1
  [[ "$(source_tree_hash "$root")" == "$expected" ]]
}

source_snapshot_create() (
  local repo=$1 archive=$2 mode=$3 evidence=$4 path parent stage candidates
  umask 077
  stage=$(mktemp -d)
  trap 'rm -rf -- "$stage"' EXIT
  mkdir "$stage/tree"
  candidates="$stage/candidates"
  if [[ "$mode" == worktree ]]; then
    git -C "$repo" ls-files --cached --others --exclude-standard -z | LC_ALL=C sort -zu > "$candidates"
  else
    # Git's default 0002 adds group-write bits that ordinary extraction removes.
    git -C "$repo" -c tar.umask=0022 archive --format=tar HEAD | tar -xpf - -C "$stage/tree"
    git -C "$repo" ls-tree -r --name-only -z HEAD > "$candidates"
    repo="$stage/tree"
  fi
  : > "$stage/selected"
  : > "$evidence/source-excluded.txt"
  while IFS= read -r -d '' path; do
    case "/${path,,}" in
      */__pycache__/*|*/__pycache__|*.pyc|*.pyo|*/.git/*|*/.git|*/.env|*/.env.*|*/.ssh/*|*/.gnupg/*|*/secrets/*|*/credentials/*|*/auth.json|*/credentials.json|*/token.json|*/tokens.json|*/oauth*.json|*/client_secret*|*/id_rsa*|*/id_ed25519*|*.pem|*.key|*.p12|*.pfx|*/.archcfg-source.*)
        printf '%q\n' "$path" >> "$evidence/source-excluded.txt"
        continue ;;
    esac
    [[ -e "$repo/$path" || -L "$repo/$path" ]] || continue
    parent=$(dirname -- "$repo/$path")
    [[ "$(realpath -m -- "$parent")" == "$(realpath -ms -- "$parent")" ]] || {
      printf '[ERROR] Snapshot refuses symlink parent: %q\n' "$path" >&2; exit 1;
    }
    [[ -f "$repo/$path" || -L "$repo/$path" ]] || {
      printf '[ERROR] Snapshot refuses special file or submodule: %q\n' "$path" >&2; exit 1;
    }
    printf '%s\0' "$path" >> "$stage/selected"
  done < "$candidates"
  if [[ "$mode" == worktree ]]; then
    tar --no-recursion --hard-dereference -C "$repo" --null -T "$stage/selected" -cf - |
      tar -xpf - -C "$stage/tree"
  fi
  # Inspect the frozen selection without printing possible secret contents.
  while IFS= read -r -d '' path; do
    if [[ ! -L "$stage/tree/$path" ]] &&
      LC_ALL=C grep -aqE -- '-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----|"(refresh_token|access_token|client_secret)"[[:space:]]*:[[:space:]]*"[^"[:space:]]+"|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}' "$stage/tree/$path"; then
      printf '[ERROR] Potential secret in snapshot file: %q (contents withheld)\n' "$path" >&2
      exit 1
    fi
    printf '%q\n' "$path"
  done < "$stage/selected" > "$evidence/source-selected.txt"
  cp "$stage/selected" "$stage/tree/.archcfg-source.files"
  source_tree_hash "$stage/tree" > "$stage/tree/.archcfg-source.sha256"
  chmod 644 "$stage/tree/.archcfg-source.files" "$stage/tree/.archcfg-source.sha256"
  cp "$stage/tree/.archcfg-source.sha256" "$evidence/source-tree.sha256"
  # Archive only the selection, including in HEAD mode where exclusions apply.
  printf '.archcfg-source.files\0.archcfg-source.sha256\0' >> "$stage/selected"
  tar --format=gnu --mtime=@0 --owner=0 --group=0 --numeric-owner \
    --hard-dereference --no-recursion -C "$stage/tree" \
    --null -T "$stage/selected" -cf "$archive"
)
