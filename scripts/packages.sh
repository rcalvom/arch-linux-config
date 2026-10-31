#!/usr/bin/env bash
set -euo pipefail

package_file_for_extra() {
  case "$1" in
    dev-extras | research | multimedia | virtualization | amd | fingerprint)
      printf 'packages/extras/%s.txt\n' "$1"
      ;;
    *) die "Invalid package extra: $1" ;;
  esac
}

package_files_for_profile() {
  local profile=$1
  local extra
  shift

  # Validate all names before emitting any files or starting a transaction.
  for extra in "$@"; do
    package_file_for_extra "$extra" >/dev/null || return 1
  done

  if [[ "${RECIPE:-none}" == ricardo ]]; then
    case "$profile" in developer | virtualbox) ;; *) die 'Ricardo recipe requires developer or virtualbox profile' ;; esac
    printf '%s\n' packages/base.txt packages/recipes/ricardo.txt
    [[ "$profile" != virtualbox ]] || printf '%s\n' packages/vm.txt
    for extra in "$@"; do
      [[ "$extra" == fingerprint ]] || die 'Only the fingerprint extra is supported with the closed Ricardo recipe'
      package_file_for_extra "$extra"
    done
    return
  fi

  case "$profile" in
    minimal)
      printf '%s\n' "packages/base.txt"
      ;;
    desktop)
      printf '%s\n' "packages/base.txt" "packages/desktop.txt"
      ;;
    developer)
      printf '%s\n' "packages/base.txt" "packages/desktop.txt" "packages/dev.txt"
      ;;
    virtualbox)
      printf '%s\n' "packages/base.txt" "packages/desktop.txt" "packages/dev.txt" "packages/vm.txt"
      ;;
    *)
      die "Invalid profile: $profile"
      ;;
  esac

  for extra in "$@"; do
    package_file_for_extra "$extra"
  done
}

load_packages_from_files() {
  local -n output=$1
  local file
  local line
  local -A seen=()

  shift
  output=()

  for file in "$@"; do
    [[ -f "$file" ]] || die "Package file not found: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
      line=${line%%#*}
      line=${line#"${line%%[![:space:]]*}"}
      line=${line%"${line##*[![:space:]]}"}
      [[ -z "$line" ]] && continue
      [[ "$line" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || die "Invalid package name in $file: $line"
      [[ -v "seen[$line]" ]] && continue
      seen[$line]=1
      output+=("$line")
    done < "$file"
  done
}

install_packages_for_profile() {
  local profile=$1
  local repo_dir=$2
  local files=()
  local relative_file
  local packages=()
  local selected_files
  shift 2

  selected_files=$(package_files_for_profile "$profile" "$@") || return 1

  while IFS= read -r relative_file; do
    files+=("$repo_dir/$relative_file")
  done <<< "$selected_files"

  load_packages_from_files packages "${files[@]}"

  if [[ "${RECIPE:-none}" == ricardo ]]; then
    local gpu_packages
    gpu_packages=$(recipe_gpu_packages "$GPU_POLICY") || return 1
    while IFS= read -r relative_file; do packages+=("$relative_file"); done <<< "$gpu_packages"
    enable_recipe_multilib
  fi

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_warn "No packages selected for profile: $profile"
    return 0
  fi

  log_info "Installing profile packages: $profile"
  pacman -Syu --needed --noconfirm "${packages[@]}"
}

validate_recipe_options() {
  case "${RECIPE:-none}" in
    none)
      [[ "${GPU_POLICY:-auto}" == auto && "${DEFER_MANUAL:-0}" == 0 ]] || die '--gpu and --defer-manual require --recipe ricardo'
      ;;
    ricardo)
      [[ "$PROFILE" == developer || "$PROFILE" == virtualbox ]] || die 'Ricardo recipe requires developer or virtualbox profile'
      local extra
      for extra in "${PACKAGE_EXTRAS[@]}"; do
        [[ "$extra" == fingerprint ]] || die 'Only --extra fingerprint may extend the closed Ricardo recipe'
      done
      ;;
    *) die "Invalid recipe: $RECIPE" ;;
  esac
}

recipe_gpu_packages() {
  local policy=$1 device driver detected=''
  if [[ "$policy" == auto ]]; then
    if systemd-detect-virt --vm --quiet; then
      policy=software
    else
      [[ $? == 1 ]] || die 'Cannot detect target virtualization for GPU selection'
      for device in /sys/class/drm/card[0-9]*/device; do
        [[ -e "$device" ]] || continue
        driver=$(basename -- "$(readlink -f "$device/driver")")
        case "$driver" in
          amdgpu) policy=amd ;;
          xe) policy=intel ;;
          *) die 'Unsupported or ambiguous GPU: select a reviewed driver policy explicitly; NVIDIA is not validated' ;;
        esac
        [[ -z "$detected" || "$detected" == "$policy" ]] || die 'Mixed GPU vendors require a separately reviewed setup'
        detected=$policy
      done
      [[ -n "$detected" ]] || die 'No supported GPU detected; use --gpu software for software rendering'
    fi
  fi
  printf '%s\n' mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
  case "$policy" in
    amd) printf '%s\n' vulkan-radeon lib32-vulkan-radeon ;;
    intel) printf '%s\n' vulkan-intel lib32-vulkan-intel intel-media-driver ;;
    software) printf '%s\n' vulkan-swrast lib32-vulkan-swrast ;;
    *) die "Invalid GPU policy: $policy" ;;
  esac
}

enable_recipe_multilib() {
  # Only called inside the target postinstall, never by dry-run or the ISO builder.
  if ! pacman-conf --repo-list | grep -x multilib >/dev/null; then
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
  fi
}

print_package_plan() {
  local repo_dir=$1 relative selected_files files=() packages=() aur_files=() names=() revisions=() index
  selected_files=$(package_files_for_profile "$PROFILE" "${PACKAGE_EXTRAS[@]}") || return 1
  while IFS= read -r relative; do files+=("$repo_dir/$relative"); done <<< "$selected_files"
  load_packages_from_files packages "${files[@]}"
  printf 'profile=%s recipe=%s hardware_profile=%s gpu=%s aur=%s defer_manual=%s\n' \
    "$PROFILE" "${RECIPE:-none}" "${HARDWARE_PROFILE:-none}" "${GPU_POLICY:-auto}" "$ENABLE_AUR" "${DEFER_MANUAL:-0}"
  printf 'official %s\n' "${packages[@]}"
  if [[ "${RECIPE:-none}" == ricardo ]]; then
    if [[ "$GPU_POLICY" == auto ]]; then
      printf 'hardware GPU packages resolved on target; no host inspection in dry-run\n'
    else
      selected_files=$(recipe_gpu_packages "$GPU_POLICY") || return 1
      while IFS= read -r relative; do printf 'official %s\n' "$relative"; done <<< "$selected_files"
    fi
    load_aur_packages_from_files names revisions "$repo_dir/packages/recipes/ricardo-manual.txt"
    for index in "${!names[@]}"; do printf 'manual %s %s\n' "${names[index]}" "${revisions[index]}"; done
  fi
  while IFS= read -r relative; do aur_files+=("$repo_dir/$relative"); done < <(aur_package_files_for_profile "$PROFILE")
  if (( ${#aur_files[@]} )); then
    load_aur_packages_from_files names revisions "${aur_files[@]}"
    for index in "${!names[@]}"; do printf 'aur %s %s\n' "${names[index]}" "${revisions[index]}"; done
  fi
  if [[ "${RECIPE:-none}" == ricardo && "$ENABLE_AUR" == 1 ]]; then
    load_packages_from_files packages "$repo_dir/packages/recipes/ricardo-aur-deps.txt"
    printf 'aur-dependency %s\n' "${packages[@]}"
  fi
  printf 'No models, credentials, SDK license acceptance or host changes are included.\n'
}

validate_recipe_installation() {
  [[ "${RECIPE:-none}" == ricardo ]] || return 0
  [[ "$(uname -m)" == x86_64 ]] || die 'Ricardo recipe is reviewed only for x86_64'
  recipe_gpu_packages "$GPU_POLICY" >/dev/null || return 1
  if [[ "$ENABLE_AUR" == 1 && "$DEFER_MANUAL" != 1 ]]; then
    die 'Manual packages blocked: davinci-resolve, flutter-bin, verapdf. Review docs/recipe-ricardo.md and explicitly use --defer-manual to proceed without them'
  fi
}

microcode_package_for_cpu() {
  local architecture=$1 vendor=$2
  [[ "$architecture" == x86_64 ]] || die "Unsupported microcode architecture: $architecture (use --microcode none to skip)"
  case "$vendor" in
    GenuineIntel) printf '%s\n' intel-ucode ;;
    AuthenticAMD) printf '%s\n' amd-ucode ;;
    *) die "Unsupported or ambiguous CPU vendor: $vendor (use --microcode none to skip)" ;;
  esac
}

detect_cpu_vendor() {
  local key value vendor=""
  while IFS=: read -r key value; do
    [[ "${key//[[:space:]]/}" == vendor_id ]] || continue
    value=${value//[[:space:]]/}
    [[ -z "$vendor" || "$vendor" == "$value" ]] || die "Mixed CPU vendors are not supported"
    vendor=$value
  done < /proc/cpuinfo
  printf '%s\n' "$vendor"
}

install_cpu_microcode() {
  local policy=$1 package vendor architecture
  case "$policy" in
    none) return 0 ;;
    auto) ;;
    *) die "Invalid microcode policy: $policy" ;;
  esac
  if systemd-detect-virt --vm --quiet; then
    log_info "Skipping guest CPU microcode; managed by the hypervisor"
    return 0
  else
    [[ $? -eq 1 ]] || die "Cannot detect virtualization for microcode policy (use --microcode none to skip)"
  fi
  architecture=$(uname -m) || return 1
  vendor=$(detect_cpu_vendor) || return 1
  package=$(microcode_package_for_cpu "$architecture" "$vendor") || return 1
  log_info "Installing CPU microcode: $package"
  pacman -S --needed --noconfirm "$package" || return 1
  # Refresh autodetected early microcode before generating the bootloader config.
  mkinitcpio -P
}
