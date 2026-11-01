#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/log.sh
builtin source "$REPO_DIR/lib/log.sh"
# shellcheck source=../lib/validate.sh
builtin source "$REPO_DIR/lib/validate.sh"
# shellcheck source=../lib/hardware.sh
builtin source "$REPO_DIR/lib/hardware.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/target/boot/EFI/archcfg-witness"
TARGET="$TEST_ROOT/target"
printf 'keep\n' > "$TARGET/boot/EFI/archcfg-witness/keep"

check() {
  local name=$1 expected=$2 actual=0
  shift 2
  (set -e; "$@") > "$TEST_ROOT/output" 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || {
    printf 'FAIL: %s (expected %s, got %s)\n' "$name" "$expected" "$actual" >&2
    exit 1
  }
  printf 'PASS: %s\n' "$name"
}

check CLI-help 0 bash "$REPO_DIR/scripts/hardware-check.sh" --help
check CLI-unknown 64 bash "$REPO_DIR/scripts/hardware-check.sh" --unknown
check CLI-missing-target 64 bash "$REPO_DIR/scripts/hardware-check.sh" --target
check CLI-implicit-disk 64 bash "$REPO_DIR/scripts/hardware-check.sh" --vm
check CLI-disk-without-VM 64 bash "$REPO_DIR/scripts/hardware-check.sh" --disk /dev/fixture

# All hardware and device evidence is synthetic. No real block nodes or mounts.
hardware_uefi() { [[ "$UEFI" == yes ]]; }
od() {
  [[ "$*" == '-An -tu1 -j4 -N2 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c' ]] || return 99
  [[ "$EFI_BYTES" != unreadable ]] || return 1
  printf '%s\n' "$EFI_BYTES"
}
UEFI=yes EFI_BYTES='   0'
[[ $(hardware_secure_boot) == off ]]
EFI_BYTES='   1'; [[ $(hardware_secure_boot) == on ]]
for EFI_BYTES in '' '0 0' 2 unreadable; do
  [[ $(hardware_secure_boot) == unknown ]]
done
UEFI=no EFI_BYTES=0; [[ $(hardware_secure_boot) == unknown ]]
printf 'PASS: SecureBoot byte decoding and BIOS fail-closed\n'
hardware_arch() { printf '%s\n' "$ARCH"; return "${ARCH_STATUS:-0}"; }
hardware_secure_boot() { printf '%s\n' "$SECURE"; return "${SECURE_STATUS:-0}"; }
hardware_gpu_vendors() { printf '%s\n' "$GPUS"; }
ARCH=x86_64 SECURE=off GPUS=0x8086
check Intel 2 hardware_platform_check
GPUS=0x1002; check AMD 2 hardware_platform_check
GPUS=0x10de; check NVIDIA 2 hardware_platform_check
GPUS=$'0x8086\n0x10de'; check hybrid 2 hardware_platform_check
GPUS=0x80ee; check VirtualBox 2 hardware_platform_check
GPUS=0xffff; check unknown-GPU 2 hardware_platform_check
GPUS=; check no-GPU 2 hardware_platform_check
SECURE=on; check SecureBoot-on 1 hardware_platform_check
SECURE=unknown; check BIOS-or-unknown 1 hardware_platform_check
SECURE=off ARCH=aarch64; check unsupported-architecture 1 hardware_platform_check
ARCH=x86_64
ARCH_STATUS=1; check failed-architecture-with-output 1 hardware_platform_check
ARCH_STATUS=0 SECURE_STATUS=1; check failed-firmware-with-output 1 hardware_platform_check
SECURE_STATUS=0 SECURE=unknown; check host-inventory-unknown-firmware 2 hardware_preflight host
! grep -q '\[unsupported\]' "$TEST_ROOT/output"
SECURE=on; check host-inventory-secure-boot 2 hardware_preflight host
SECURE=off

readlink() {
  if [[ "$1" == -m ]]; then printf '%s\n' "${*: -1}"; else printf '/dev/sda\n'; fi
}
test() { [[ "$1" == -b && "$BLOCK" == yes ]]; }
mountpoint() { [[ "$MODE" != safe ]] || return 0; return "${MOUNT_STATUS:-32}"; }
stat() { if [[ "${*: -1}" == / ]]; then printf '100\n'; else printf '%s\n' "$TARGET_ID"; fi; }
findmnt() {
  local column=${2-} point=${*: -1}
  [[ "$QUERY_FAIL" != yes ]] || return 1
  if [[ "$1" == -rn ]]; then printf '%s\n' "$MOUNTS"; return; fi
  case "$column:$point" in
    MAJ:MIN:/) printf '%s\n' "$HOST_ID" ;;
    SOURCE:/run/archiso/bootmnt) printf '/dev/sr0\n' ;;
    FSTYPE:/) printf '%s\n' "$HOST_TYPE" ;;
    SOURCE:*/boot) printf '/dev/sda1\n' ;;
    SOURCE:*) printf '/dev/sda2\n' ;;
    MAJ:MIN:*/boot) printf '8:1\n'; return "${IDENTITY_STATUS:-0}" ;;
    MAJ:MIN:*) printf '8:2\n' ;;
    FSTYPE:*/boot) printf '%s\n' "$BOOT_FS" ;;
    FSTYPE:*) printf '%s\n' "$ROOT_FS" ;;
    FSROOT:*) printf '%s\n' "$FSROOT" ;;
    OPTIONS:*) printf '%s\n' "$OPTIONS" ;;
    *) return 99 ;;
  esac
}
lsblk() {
  case "$1:$2" in
    -dnro:TYPE)
      if [[ "${*: -1}" == /dev/sda[12] ]]; then printf '%s\n' "$PART_TYPE"; else printf 'disk\n'; fi ;;
    -dnro:PTTYPE) printf '%s\n' "$PTTYPE"; return "${PTTYPE_STATUS:-0}" ;;
    -dnro:FSVER) printf '%s\n' "$FSVER" ;;
    -dnro:PARTTYPE) printf '%s\n' "$ESP_TYPE" ;;
    -dnpro:PKNAME) printf '/dev/sda\n' ;;
    -dnro:RO) printf '%s\n' "$RO" ;;
    -dnro:TRAN) printf '%s\n' "$TRAN" ;;
    -snrpo:NAME) printf '%s\n' "$ANCESTORS" ;;
    -snro:TYPE) printf '%s\n' "$ANCESTOR_TYPES" ;;
    -nrpo:MAJ:MIN) printf '8:0\n8:1\n8:2\n' ;;
    -nrpo:TYPE) printf '%s\n' "$HOLDERS" ;;
    -nrpo:MOUNTPOINTS) printf '%s\n' "$SWAP" ;;
    *) return 99 ;;
  esac
}

MODE=safe BLOCK=yes TARGET_ID=200 QUERY_FAIL=no HOST_ID=8:18 HOST_TYPE=ext4
ROOT_FS=ext4 BOOT_FS=vfat FSROOT=/ OPTIONS=rw PTTYPE=gpt FSVER=FAT32
ESP_TYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b PART_TYPE=part RO=0 TRAN=sata
ANCESTORS=$'/dev/sdb2\n/dev/sdb' HOLDERS=$'disk\npart\npart' SWAP=
ANCESTOR_TYPES=$'part\ndisk'
MOUNTS=$(printf '8:18 /\n8:2 %s\n8:1 %s/boot\n' "$TARGET" "$TARGET")
safe_check() { validate_hardware_storage safe "$TARGET" ''; }
vm_check() { validate_hardware_storage vm "$TARGET" /dev/sda; }
check safe-SATA 0 safe_check
[[ -z $(safe_check) ]]
[[ $(validated_disk_path /dev/sda) == /dev/sda ]]
printf 'PASS: storage validators stdout contract\n'
IDENTITY_STATUS=1; check failed-identity-with-output 1 safe_check
IDENTITY_STATUS=0 PTTYPE_STATUS=1; check failed-table-with-output 1 safe_check
PTTYPE_STATUS=0 ESP_TYPE=${ESP_TYPE^^}; check uppercase-ESP-type 0 safe_check
ESP_TYPE=${ESP_TYPE,,}
check protected-target 1 validate_hardware_storage safe /etc ''
TRAN=nvme; check safe-NVMe 0 safe_check
TRAN=usb; check USB-out-of-scope 1 safe_check
TRAN=sata TARGET_ID=100; check host-root-bind 1 safe_check
TARGET_ID=200 OPTIONS=ro; check readonly-root 1 safe_check
OPTIONS=rw FSROOT=/subdir; check subdirectory-bind 1 safe_check
FSROOT=/ ROOT_FS=btrfs; check btrfs-out-of-scope 1 safe_check
ROOT_FS=ext4 BOOT_FS=ext4; check non-FAT-ESP 1 safe_check
BOOT_FS=vfat FSVER=FAT16; check FAT16-ESP 1 safe_check
FSVER=FAT32 ESP_TYPE=unknown; check wrong-ESP-type 1 safe_check
ESP_TYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b PTTYPE=dos
check MBR-layout 1 safe_check
PTTYPE=gpt PART_TYPE=crypt; check encryption-out-of-scope 1 safe_check
PART_TYPE=part
MOUNTS+=$'\n8:1 /boot'; check shared-host-ESP 1 safe_check
MOUNTS=$(printf '8:18 /\n8:2 %s\n8:1 %s/boot\n9:1 %s/home\n' "$TARGET" "$TARGET" "$TARGET")
check nested-mount 1 safe_check
MOUNTS=$(printf '8:18 /\n8:2 %s\n8:1 %s/boot\n' "$TARGET" "$TARGET")
printf 'fixture\n' > "$TARGET/boot/EFI/existing.EFI"
check existing-bootloader 1 safe_check
rm "$TARGET/boot/EFI/existing.EFI"
ln -s "$TEST_ROOT" "$TARGET/boot/EFI/link"
check ESP-symlink 1 safe_check
rm "$TARGET/boot/EFI/link"
check E2E-witness-preserved 0 safe_check
[[ $(< "$TARGET/boot/EFI/archcfg-witness/keep") == keep ]]
MODE=vm MOUNTS='8:18 /'
check VM-explicit-unused-disk 0 vm_check
check VM-target-missing 1 validate_hardware_storage vm "$TEST_ROOT/missing" /dev/sda
check VM-target-file 1 validate_hardware_storage vm "$TARGET/boot/EFI/archcfg-witness/keep" /dev/sda
MOUNT_STATUS=1; check VM-mountpoint-query-error 1 vm_check
MOUNT_STATUS=32 MOUNTS=; check VM-empty-mount-inventory 1 vm_check
MOUNTS=malformed; check VM-malformed-mount-inventory 1 vm_check
MOUNTS='8:18 /'
check VM-missing-disk 1 validate_hardware_storage vm "$TARGET" ''
ANCESTORS=$'/dev/dm-0\n/dev/sda2\n/dev/sda'; check host-root-ancestor 1 vm_check
ANCESTOR_TYPES=loop; check unresolved-physical-ancestor 1 vm_check
ANCESTOR_TYPES=$'part\ndisk'
ANCESTORS=$'/dev/sdb2\n/dev/sdb' MOUNTS=$'8:18 /\n8:2 /other'
check VM-mounted-partition 1 vm_check
MOUNTS='8:18 /' SWAP='[SWAP]'; check VM-active-swap 1 vm_check
SWAP= HOLDERS=$'disk\npart\ncrypt'; check VM-active-mapping 1 vm_check
HOLDERS=$'disk\npart\npart' HOST_ID=0:42 HOST_TYPE=overlay ANCESTORS=/dev/sr0
ANCESTOR_TYPES=rom
check archiso-overlay 0 vm_check
ANCESTORS=$'/dev/sda1\n/dev/sda'; check live-media-disk 1 vm_check
HOST_TYPE=tmpfs; check unknown-pseudo-root 1 vm_check
HOST_TYPE=overlay BLOCK=no; check unresolved-host-block 1 vm_check
BLOCK=yes QUERY_FAIL=yes; check failed-storage-query 1 vm_check

# Exercise the actual installer orchestration with all side effects mocked.
# Load argument defaults, but keep probe and write functions mocked.
source() {
  case "$1" in
    */lib/args.sh) builtin source "$1" ;;
    *) : ;;
  esac
}
parse_args() { :; }
require_root() { :; }
validate_profile() { :; }
validate_recipe_options() { :; }
validate_recipe_installation() { :; }
hardware_preflight() { printf 'preflight\n' >> "$TEST_ROOT/order"; return "$PREFLIGHT_STATUS"; }
validate_hardware_storage() { printf 'storage\n' >> "$TEST_ROOT/order"; }
validate_user_password_file() { printf 'password\n' >> "$TEST_ROOT/order"; }
validate_internet() { printf 'internet\n' >> "$TEST_ROOT/order"; }
refresh_mirrors_if_available() { printf 'write\n' >> "$TEST_ROOT/order"; exit 77; }
PREFLIGHT_STATUS=1
installer_case() (
  # No real command after the preflight is reachable, even on a passing result.
  builtin source "$REPO_DIR/install.sh" "$@"
)
check installer-reject 1 installer_case --target "$TARGET"
[[ $(< "$TEST_ROOT/order") == preflight ]]
: > "$TEST_ROOT/order"
printf 'fixture-password\n' > "$TEST_ROOT/password"
check installer-VM-reject 1 installer_case --vm --disk /dev/sda --yes --user-password-file "$TEST_ROOT/password"
[[ $(< "$TEST_ROOT/order") == preflight && -f "$TEST_ROOT/password" ]]
: > "$TEST_ROOT/order"
PREFLIGHT_STATUS=2
check installer-warning-continues 77 installer_case --target "$TARGET"
[[ $(< "$TEST_ROOT/order") == $'preflight\ninternet\nwrite' ]]
printf 'Hardware preflight fixtures passed.\n'
