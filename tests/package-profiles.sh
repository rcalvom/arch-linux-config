#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../postinstall.sh
source "$REPO_DIR/postinstall.sh"

log_info() { :; }
calls=()
pacman() { calls+=("pacman $*"); }
mkinitcpio() { calls+=("mkinitcpio $*"); }
uname() { printf '%s\n' x86_64; }
detect_cpu_vendor() { printf '%s\n' GenuineIntel; }
systemd-detect-virt() { return 1; }

[[ "$(package_files_for_profile minimal)" == packages/base.txt ]]
[[ "$(package_files_for_profile developer)" != *extras* ]]
[[ "$(package_files_for_profile virtualbox)" == *packages/vm.txt ]]
for extra in dev-extras research multimedia virtualization amd fingerprint; do
  [[ "$(package_files_for_profile minimal "$extra")" == *"packages/extras/$extra.txt" ]]
  load_packages_from_files selected "$REPO_DIR/packages/extras/$extra.txt"
  [[ ${#selected[@]} -gt 0 ]]
done

if (package_files_for_profile developer ../base) >/dev/null 2>&1; then
  die "Extra traversal was accepted"
fi
if (install_packages_for_profile bad "$REPO_DIR") >/dev/null 2>&1; then
  die "Invalid profile was accepted"
fi
if (install_packages_for_profile minimal "$REPO_DIR" bad) >/dev/null 2>&1; then
  die "Invalid extra was accepted"
fi

parse_postinstall_args --extra research --extra amd --microcode none
[[ "${PACKAGE_EXTRAS[*]}" == 'research amd' && "$MICROCODE" == none ]]
for flag in --extra --microcode; do
  if (parse_postinstall_args "$flag") >/dev/null 2>&1; then
    die "Missing value was accepted: $flag"
  fi
  if (parse_postinstall_args "$flag" invalid) >/dev/null 2>&1; then
    die "Invalid value was accepted: $flag"
  fi
done

install_packages_for_profile desktop "$REPO_DIR" research research
[[ ${#calls[@]} -eq 1 ]]
[[ " ${calls[0]} " == *' --needed '* ]]
[[ " ${calls[0]} " == *' evince '* && " ${calls[0]} " == *' neovim '* ]]
[[ " ${calls[0]} " != *' fprintd '* ]]
[[ " ${calls[0]} " != *' qemu-desktop '* ]]
load_packages_from_files selected "$REPO_DIR/packages/extras/research.txt" "$REPO_DIR/packages/extras/research.txt"
count=0
for package in "${selected[@]}"; do
  if [[ "$package" == r ]]; then count=$((count + 1)); fi
done
[[ "$count" -eq 1 ]]

[[ "$(microcode_package_for_cpu x86_64 GenuineIntel)" == intel-ucode ]]
[[ "$(microcode_package_for_cpu x86_64 AuthenticAMD)" == amd-ucode ]]
for vendor in '' unknown 'GenuineIntel AuthenticAMD'; do
  if (microcode_package_for_cpu x86_64 "$vendor") >/dev/null 2>&1; then
    die "Invalid CPU vendor was accepted"
  fi
done
if (microcode_package_for_cpu aarch64 GenuineIntel) >/dev/null 2>&1; then
  die "Invalid architecture was accepted"
fi
calls=()
install_cpu_microcode none
[[ ${#calls[@]} -eq 0 ]]
install_cpu_microcode auto
[[ "${calls[*]}" == 'pacman -S --needed --noconfirm intel-ucode mkinitcpio -P' ]]
calls=()
detect_cpu_vendor() { printf '%s\n' AuthenticAMD; }
install_cpu_microcode auto
[[ "${calls[*]}" == 'pacman -S --needed --noconfirm amd-ucode mkinitcpio -P' ]]
if (install_cpu_microcode invalid) >/dev/null 2>&1; then
  die "Invalid microcode policy was accepted"
fi

# A failed package transaction must not be hidden by successful initramfs work.
pacman() { return 42; }
mkinitcpio() { calls+=(unexpected-initramfs); }
calls=()
if install_cpu_microcode auto; then
  die "Microcode package failure was ignored"
fi
[[ ${#calls[@]} -eq 0 ]]

printf '%s\n' 'Package profile and microcode mock tests passed'
systemd-detect-virt() { return 127; }
detect_cpu_vendor() { exit 99; }
status=0
(install_cpu_microcode auto) >/dev/null 2>&1 || status=$?
[[ "$status" -eq 1 ]] || die 'Unknown virtualization did not stop before CPU inspection'
systemd-detect-virt() { return 0; }
detect_cpu_vendor() { die 'Guest CPU must not be inspected'; }
install_cpu_microcode auto

# Exercise the public installer parser without entering its installation flow.
source "$REPO_DIR/lib/args.sh"
parse_args --extra research --extra amd --microcode none --hardware-profile ricardo
[[ "${PACKAGE_EXTRAS[*]}" == 'research amd' && "$MICROCODE" == none && "$HARDWARE_PROFILE" == ricardo ]]
for flag in --extra --microcode --hardware-profile; do
  if (parse_args "$flag") >/dev/null 2>&1; then die "Missing value accepted: $flag"; fi
  if (parse_args "$flag" invalid) >/dev/null 2>&1; then die "Invalid value accepted: $flag"; fi
done
if (parse_args --profile minimal --hardware-profile ricardo) >/dev/null 2>&1; then die 'Minimal accepted display hardware'; fi
