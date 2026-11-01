#!/usr/bin/env bash
set -euo pipefail
REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/source-snapshot.sh
source "$REPO_DIR/lib/source-snapshot.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT
mkdir "$TEST_DIR/repo" "$TEST_DIR/evidence" "$TEST_DIR/unpacked"
# These setup calls use real Git; later cases define scoped Git mocks.
# ShellCheck still resolves the later function despite the command prefix.
# shellcheck disable=SC2218
command git -C "$TEST_DIR/repo" init -q
printf 'original\n' > "$TEST_DIR/repo/tracked"
printf 'deleted\n' > "$TEST_DIR/repo/deleted"
# shellcheck disable=SC2218
command git -C "$TEST_DIR/repo" add tracked deleted
mkdir "$TEST_DIR/repo/__pycache__"
printf 'cached\n' > "$TEST_DIR/repo/__pycache__/tracked.pyc"
printf 'cached\n' > "$TEST_DIR/repo/standalone.pyc"
# shellcheck disable=SC2218
command git -C "$TEST_DIR/repo" add __pycache__/tracked.pyc standalone.pyc
printf 'modified\n' > "$TEST_DIR/repo/tracked"
rm "$TEST_DIR/repo/deleted"
printf 'new\n' > "$TEST_DIR/repo/untracked file"
printf 'ignored\n' > "$TEST_DIR/repo/.gitignore"
printf 'private\n' > "$TEST_DIR/repo/ignored"
printf 'private\n' > "$TEST_DIR/repo/.env"
ln -s /etc/shadow "$TEST_DIR/repo/link"
source_snapshot_create "$TEST_DIR/repo" "$TEST_DIR/source.tar" worktree "$TEST_DIR/evidence"
tar -xpf "$TEST_DIR/source.tar" -C "$TEST_DIR/unpacked"
source_tree_verify "$TEST_DIR/unpacked"
[[ $(stat -c %a "$TEST_DIR/repo/tracked") == "$(stat -c %a "$TEST_DIR/unpacked/tracked")" ]]
[[ $(<"$TEST_DIR/unpacked/tracked") == modified && -f "$TEST_DIR/unpacked/untracked file" ]]
[[ ! -e "$TEST_DIR/unpacked/deleted" && ! -e "$TEST_DIR/unpacked/ignored" && ! -e "$TEST_DIR/unpacked/.env" ]]
[[ ! -e "$TEST_DIR/unpacked/__pycache__" && ! -e "$TEST_DIR/unpacked/standalone.pyc" ]]
[[ -L "$TEST_DIR/unpacked/link" && $(readlink "$TEST_DIR/unpacked/link") == /etc/shadow ]]
printf 'tampered\n' >> "$TEST_DIR/unpacked/tracked"
if source_tree_verify "$TEST_DIR/unpacked"; then exit 1; fi
printf 'modified\n' > "$TEST_DIR/unpacked/tracked"
chmod +x "$TEST_DIR/unpacked/tracked"
if source_tree_verify "$TEST_DIR/unpacked"; then exit 1; fi
chmod -x "$TEST_DIR/unpacked/tracked"
source_tree_verify "$TEST_DIR/unpacked"
# Generate a credential fixture without embedding a real secret in the source.
printf '%s%s\n' '-----BEGIN RSA ' 'PRIVATE KEY-----' > "$TEST_DIR/repo/innocent.txt"
if (source_snapshot_create "$TEST_DIR/repo" "$TEST_DIR/rejected.tar" worktree "$TEST_DIR/evidence") > "$TEST_DIR/rejection.log" 2>&1; then exit 1; fi
if grep -q 'BEGIN RSA' "$TEST_DIR/rejection.log"; then exit 1; fi
rm "$TEST_DIR/repo/innocent.txt"
printf '%s%s\n' '-----BEGIN PGP ' 'PRIVATE KEY BLOCK-----' > "$TEST_DIR/repo/innocent.txt"
if (source_snapshot_create "$TEST_DIR/repo" "$TEST_DIR/rejected.tar" worktree "$TEST_DIR/evidence") > "$TEST_DIR/rejection.log" 2>&1; then exit 1; fi
if grep -q 'BEGIN PGP' "$TEST_DIR/rejection.log"; then exit 1; fi
rm "$TEST_DIR/repo/innocent.txt"
# shellcheck source=../scripts/build-iso.sh
source "$REPO_DIR/scripts/build-iso.sh"
REPO_ROOT="$TEST_DIR/unpacked"
mkdir -p "$REPO_ROOT/lib"
cp "$REPO_DIR/lib/source-snapshot.sh" "$REPO_ROOT/lib/"
copy_committed_repo_tree "$TEST_DIR/bundled"
source_tree_verify "$TEST_DIR/bundled"
[[ $(<"$TEST_DIR/bundled/tracked") == modified ]]
mkdir -p "$TEST_DIR/profile/airootfs/opt/arch-linux-config"
printf 'executable\n' > "$TEST_DIR/profile/airootfs/opt/arch-linux-config/run me"
chmod 751 "$TEST_DIR/profile/airootfs/opt/arch-linux-config/run me"
printf 'declare -A file_permissions=()\n' > "$TEST_DIR/profile/profiledef.sh"
preserve_bundled_source_permissions "$TEST_DIR/profile"
source "$TEST_DIR/profile/profiledef.sh"
[[ ${file_permissions['/opt/arch-linux-config/run me']} == 0:0:751 ]]
# Exercise real Git archive permissions without creating a fixture commit.
# shellcheck disable=SC2218
command git -C "$TEST_DIR/repo" update-index --chmod=+x tracked
fixture_tree=$(command git -C "$TEST_DIR/repo" write-tree)
(
  git() {
    local args=("$@")
    [[ "${args[-1]}" != HEAD ]] || args[-1]=$fixture_tree
    command git "${args[@]}"
  }
  mkdir "$TEST_DIR/head-unpacked"
  source_snapshot_create "$TEST_DIR/repo" "$TEST_DIR/head-source.tar" head "$TEST_DIR/evidence"
  (umask 022; tar -xf "$TEST_DIR/head-source.tar" -C "$TEST_DIR/head-unpacked")
  source_tree_verify "$TEST_DIR/head-unpacked"
  [[ $(stat -c %a "$TEST_DIR/head-unpacked/tracked") == 755 ]]
  [[ $(stat -c %a "$TEST_DIR/head-unpacked/deleted") == 644 ]]
  [[ ! -e "$TEST_DIR/head-unpacked/__pycache__" && ! -e "$TEST_DIR/head-unpacked/standalone.pyc" ]]
)
# A clean HEAD export also needs metadata; mock Git without creating commits.
REPO_ROOT="$TEST_DIR/head"
TEMP_DIR="$TEST_DIR/head-build"
mkdir -p "$REPO_ROOT/lib" "$TEMP_DIR"
cp "$REPO_DIR/lib/source-snapshot.sh" "$REPO_ROOT/lib/"
printf 'clean head\n' > "$REPO_ROOT/tracked"
git() {
  case " $* " in
    *' rev-parse '* | *' status '*) return 0 ;;
    *' archive '*) tar -C "$REPO_ROOT" -cf - lib tracked ;;
    *' ls-tree '*) printf 'lib/source-snapshot.sh\0tracked\0' ;;
    *) return 99 ;;
  esac
}
copy_committed_repo_tree "$TEST_DIR/head-bundled"
source_tree_verify "$TEST_DIR/head-bundled"
[[ $(< "$TEST_DIR/head-bundled/tracked") == 'clean head' ]]
printf 'source snapshot tests passed\n'
