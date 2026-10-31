#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/log.sh
source "$REPO_DIR/lib/log.sh"
# shellcheck source=../lib/validate.sh
source "$REPO_DIR/lib/validate.sh"
# shellcheck source=../lib/disk.sh
source "$REPO_DIR/lib/disk.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/target"
ln -s / "$TEST_ROOT/root-alias"
TRACE="$TEST_ROOT/trace"

# All device queries and disk operations are mocked; no block nodes are needed.
record() { printf '%s\n' "$*" >>"$TRACE"; }
readlink() {
  record "resolve ${*: -1}"
  [[ "$RESOLVE" != fail ]] || return 1
  printf '%s\n' "$RESOLVE"
}
test() {
  [[ "$1" == -b && "$2" == "$RESOLVE" ]] || exit 99
  [[ "$BLOCK" == yes ]]
}
lsblk() {
  record "lsblk $*"
  case "$1" in
    -dnro)
      [[ "$TYPE" != fail ]] || return 1
      printf '%s\n' "$TYPE"
      ;;
    -nrpo)
      [[ "$MOUNTS" != fail ]] || return 1
      printf '%s\n' "$MOUNTS"
      ;;
  esac
}
stat() {
  [[ "$STAT" != fail ]] || return 1
  if [[ "${*: -1}" == / ]]; then
    printf '100\n'
  else
    printf '%s\n' "$STAT"
  fi
}
mountpoint() { [[ "$MOUNTED" == yes ]]; }
wipefs() { record "wipefs $*"; }
sgdisk() { record "sgdisk $*"; }
partprobe() { record "partprobe $*"; }
udevadm() { record "udevadm $*"; }
mkfs.fat() { record "mkfs.fat $*"; }
mkfs.ext4() { record "mkfs.ext4 $*"; }
mount() { record "mount $*"; }
umount() { record "umount $*"; }
install() { record "install $*"; }

vm_flow() {
  validate_disk "$INPUT"
  confirm_vm_disk "$INPUT" "$YES"
  unmount_vm_disk_mounts "$INPUT"
  partition_vm_disk "$INPUT"
  format_vm_partitions "$INPUT"
  mount_vm_partitions "$INPUT" "$TEST_ROOT/target"
}

run_case() {
  local name=$1 expected=$2 status
  shift 2
  : >"$TRACE"
  set +e
  (set -e; "$@") >"$TEST_ROOT/output" 2>&1
  status=$?
  set -e
  if [[ "$expected" == pass && "$status" != 0 ]] ||
    [[ "$expected" == fail && "$status" == 0 ]]; then
    printf 'FAIL: %s (status %s)\n' "$name" "$status" >&2
    exit 1
  fi
  if [[ "$expected" == fail ]] &&
    grep -Eq '^(wipefs|sgdisk|mkfs\.|mount |umount |install )' "$TRACE"; then
    printf 'FAIL: %s performed a destructive operation\n' "$name" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$name"
}

MOUNTED=yes STAT=200
run_case 'safe separate filesystem' pass validate_target_mount "$TEST_ROOT/target"
run_case 'safe root' fail validate_target_mount /
run_case 'safe root spelling' fail validate_target_mount /tmp/..
run_case 'safe root symlink' fail validate_target_mount "$TEST_ROOT/root-alias"
STAT=100
run_case 'safe root bind or same filesystem' fail validate_target_mount "$TEST_ROOT/target"
STAT=fail
run_case 'safe identity query failure' fail validate_target_mount "$TEST_ROOT/target"
STAT=
run_case 'safe empty identity' fail validate_target_mount "$TEST_ROOT/target"
STAT=unknown
run_case 'safe malformed identity' fail validate_target_mount "$TEST_ROOT/target"
STAT=200 MOUNTED=no
run_case 'safe unmounted target' fail validate_target_mount "$TEST_ROOT/target"
run_case 'safe missing target' fail validate_target_mount "$TEST_ROOT/missing"
MOUNTED=yes

INPUT=/dev/disk/by-id/disposable RESOLVE=/dev/sda BLOCK=yes TYPE=disk MOUNTS=/old YES=1
for RESOLVE in /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0; do
  run_case "VM whole-disk alias to $RESOLVE" pass vm_flow
  efi=$(partition_path "$RESOLVE" 1)
  root=$(partition_path "$RESOLVE" 2)
  grep -qxF "mkfs.fat -F 32 $efi" "$TRACE"
  grep -qxF "mkfs.ext4 -F $root" "$TRACE"
  grep -qxF "mount $root $TEST_ROOT/target" "$TRACE"
  grep -qxF "mount $efi $TEST_ROOT/target/boot" "$TRACE"
  # Check ordering and canonical paths, not just the final outcome.
  shown=0 unmounted=0 validated=0 wiped=0
  while IFS= read -r line; do
    case "$line" in
      "lsblk -dnro TYPE -- $RESOLVE") validated=1 ;;
      "lsblk $RESOLVE") [[ "$validated" == 1 ]]; shown=1 ;;
      'umount -R /old') [[ "$shown" == 1 ]]; unmounted=1; validated=0 ;;
      "wipefs -a $RESOLVE") [[ "$unmounted" == 1 && "$validated" == 1 ]]; wiped=1 ;;
    esac
  done <"$TRACE"
  [[ "$wiped" == 1 ]]
done

RESOLVE=/dev/sda INPUT=/dev/sda MOUNTS=
run_case 'VM direct whole disk' pass vm_flow
INPUT=sda
run_case 'VM relative disk' fail vm_flow
INPUT=/dev/disk/by-id/disposable RESOLVE=fail
run_case 'VM unresolved alias' fail vm_flow
RESOLVE=/tmp/not-a-device
run_case 'VM alias outside dev' fail vm_flow
RESOLVE=/dev/sda BLOCK=no
run_case 'VM non-block device' fail vm_flow
BLOCK=yes
for TYPE in part crypt lvm loop rom '' fail; do
  run_case "VM rejects type '$TYPE'" fail vm_flow
done
TYPE=part RESOLVE=/dev/sda1
run_case 'VM partition alias before unmount' fail unmount_vm_disk_mounts "$INPUT"
run_case 'VM partition alias before wipe' fail partition_vm_disk "$INPUT"
run_case 'VM partition alias before format' fail format_vm_partitions "$INPUT"
run_case 'VM partition alias before mount' fail mount_vm_partitions "$INPUT" "$TEST_ROOT/target"
TYPE=disk RESOLVE=/dev/sda MOUNTS=fail
run_case 'VM mount query failure before wipe' fail vm_flow
MOUNTS= YES=0
run_case 'VM rejected confirmation' fail vm_flow <<<NO
run_case 'VM accepted confirmation' pass vm_flow <<<ERASE
printf 'Install safety tests passed.\n'
