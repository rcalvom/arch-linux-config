#!/usr/bin/env bash
set -euo pipefail

# Test fixture only: the safe installer itself never prepares disks.
[[ $# -eq 3 && "$1" == --vm && "$2" == --disk && "$3" == /dev/sda ]] || exit 2
[[ $EUID -eq 0 && $(systemd-detect-virt) == oracle && -d /sys/firmware/efi ]] || exit 1
[[ $(lsblk -dn -o MODEL /dev/sda) == VBOX* && $(lsblk -dn -o TYPE /dev/sda) == disk ]] || exit 1
[[ -z $(lsblk -nr -o MOUNTPOINTS /dev/sda | tr -d '[:space:]') ]] || exit 1
lsblk /dev/sda
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+1G -t 1:ef00 -n 2:0:0 -t 2:8300 /dev/sda
partprobe /dev/sda
udevadm settle
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
printf 'archcfg-safe-preserve-root\n' > /mnt/archcfg-safe-witness
mkdir -p /mnt/boot/EFI/archcfg-witness
printf 'archcfg-safe-preserve-esp\n' > /mnt/boot/EFI/archcfg-witness/keep
sfdisk --dump /dev/sda > /run/archcfg-safe-before
sha256sum /mnt/archcfg-safe-witness /mnt/boot/EFI/archcfg-witness/keep > /run/archcfg-safe-witnesses
