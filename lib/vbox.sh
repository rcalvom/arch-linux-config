#!/usr/bin/env bash
set -euo pipefail

ARCHCFG_VBOX_STATE_ROOT=${ARCHCFG_VBOX_STATE_ROOT:-"$HOME/.local/state/arch-linux-config/e2e-vbox"}
ARCHCFG_VBOX_VM_ROOT=${ARCHCFG_VBOX_VM_ROOT:-"$HOME/VirtualBox VMs"}

vbox_log_info() {
  printf '[INFO] %s\n' "$*"
}

vbox_log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

vbox_die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

vbox_require_command() {
  command -v "$1" >/dev/null 2>&1 || vbox_die "Missing required command: $1"
}

vbox_require_regular_user() {
  [[ "${EUID:-$(id -u)}" -ne 0 ]] || vbox_die "Run VirtualBox automation as a regular user"
}

vbox_run_id_is_valid() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]]
}

vbox_new_run_id() {
  printf '%s-%04x\n' "$(date -u +%Y%m%dt%H%M%sz)" "$RANDOM"
}

vbox_managed_vm_name_is_valid() {
  [[ "$1" =~ ^archcfg-e2e-(build|test)-[a-z0-9][a-z0-9._-]{0,63}$ ]]
}

vbox_require_managed_vm_name() {
  vbox_managed_vm_name_is_valid "$1" || vbox_die "Refusing to operate on an unmanaged VM name: $1"
}

vbox_prepare_directory() {
  install -dm700 "$1"
}

vbox_generate_password_file() {
  local path=$1

  vbox_require_command openssl
  install -dm700 "$(dirname -- "$path")"
  install -m600 /dev/null "$path"
  openssl rand -hex 32 > "$path"
}

vbox_file_sha256() {
  local file=$1
  local checksum
  local ignored

  read -r checksum ignored < <(sha256sum -- "$file")
  printf '%s\n' "$checksum"
}

vbox_manifest_value() {
  local manifest=$1
  local key=$2
  local name
  local value
  local result=
  local matches=0

  [[ "$key" =~ ^[a-z0-9_]+$ ]] || return 2
  [[ -f "$manifest" ]] || return 1

  while IFS='=' read -r name value || [[ -n "$name" ]]; do
    [[ "$name" == "$key" ]] || continue
    result=$value
    ((matches += 1))
  done < "$manifest"

  [[ "$matches" -eq 1 ]] || return 1
  printf '%s\n' "$result"
}

vbox_machine_value() {
  local vm=$1
  local key=$2
  local line
  local value

  while IFS= read -r line; do
    [[ "$line" == "$key="* ]] || continue
    value=${line#"$key="}
    value=${value#\"}
    value=${value%\"}
    printf '%s\n' "$value"
    return 0
  done < <(VBoxManage showvminfo "$vm" --machinereadable)

  return 1
}

vbox_vm_state() {
  vbox_machine_value "$1" VMState
}

vbox_wait_for_state() {
  local vm=$1
  local expected_state=$2
  local timeout_seconds=$3
  local deadline=$((SECONDS + timeout_seconds))
  local state

  while ((SECONDS < deadline)); do
    state=$(vbox_vm_state "$vm" 2>/dev/null || true)
    [[ "$state" == "$expected_state" ]] && return 0
    sleep 2
  done

  vbox_log_warn "Timed out waiting for $vm to reach state: $expected_state"
  return 1
}

vbox_create_efi_vm() {
  local vm=$1
  local memory_mb=$2
  local cpus=$3
  local disk_mb=$4
  local iso=$5
  local vm_dir="$ARCHCFG_VBOX_VM_ROOT/$vm"
  local disk="$vm_dir/$vm.vdi"

  vbox_require_managed_vm_name "$vm"
  [[ -f "$iso" ]] || vbox_die "Bootstrap ISO does not exist: $iso"
  [[ ! -e "$vm_dir" ]] || vbox_die "VM directory already exists: $vm_dir"

  install -dm755 "$ARCHCFG_VBOX_VM_ROOT"
  VBoxManage createvm --name "$vm" --ostype ArchLinux_64 --basefolder "$ARCHCFG_VBOX_VM_ROOT" --register || return 1
  if ! VBoxManage modifyvm "$vm" \
    --firmware efi \
    --memory "$memory_mb" \
    --cpus "$cpus" \
    --vram 128 \
    --graphicscontroller vmsvga \
    --accelerate3d off \
    --ioapic on \
    --nic1 nat \
    --audio-enabled off \
    --clipboard disabled \
    --drag-and-drop disabled \
    --usb off \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none; then
    vbox_rollback_new_vm "$vm" "$disk"
    return 1
  fi
  if ! VBoxManage storagectl "$vm" --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on; then
    vbox_rollback_new_vm "$vm" "$disk"
    return 1
  fi
  if ! VBoxManage createmedium disk --filename "$disk" --size "$disk_mb" --format VDI --variant Standard; then
    vbox_rollback_new_vm "$vm" "$disk"
    return 1
  fi
  if ! VBoxManage storageattach "$vm" --storagectl SATA --port 0 --device 0 --type hdd --medium "$disk"; then
    vbox_rollback_new_vm "$vm" "$disk"
    return 1
  fi
  if ! VBoxManage storageattach "$vm" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$iso"; then
    vbox_rollback_new_vm "$vm" "$disk"
    return 1
  fi
}

vbox_rollback_new_vm() {
  local vm=$1
  local disk=$2

  VBoxManage unregistervm "$vm" --delete >/dev/null 2>&1 || true
  VBoxManage closemedium disk "$disk" --delete >/dev/null 2>&1 || true
}

vbox_start_vm() {
  VBoxManage startvm "$1" --type headless
}

vbox_power_off_vm() {
  local vm=$1
  local state

  state=$(vbox_vm_state "$vm" 2>/dev/null || true)
  [[ "$state" == running || "$state" == paused || "$state" == stuck ]] || return 0
  VBoxManage controlvm "$vm" poweroff >/dev/null
  vbox_wait_for_state "$vm" poweroff 60
}

vbox_eject_iso() {
  local vm=$1

  VBoxManage storageattach "$vm" --storagectl SATA --port 1 --device 0 --type dvddrive --medium none
  VBoxManage modifyvm "$vm" --boot1 disk --boot2 none
}

vbox_find_ssh_port() {
  local port
  local attempt

  vbox_require_command ss
  for ((attempt = 0; attempt < 100; attempt++)); do
    port=$((22000 + RANDOM % 20000))
    if [[ -z "$(ss -ltnH "sport = :$port" 2>/dev/null)" ]]; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  vbox_log_warn "Could not find an available localhost SSH port"
  return 1
}

vbox_configure_nat_ssh() {
  local vm=$1
  local port=$2

  [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1024 && "$port" -le 65535 ]] || vbox_die "Invalid SSH port: $port"
  VBoxManage modifyvm "$vm" --natpf1 "archcfg-ssh,tcp,127.0.0.1,$port,,22"
}

vbox_generate_ssh_key() {
  local key_path=$1

  vbox_require_command ssh-keygen
  install -dm700 "$(dirname -- "$key_path")"
  rm -f -- "$key_path" "$key_path.pub"
  ssh-keygen -q -t ed25519 -N '' -C archcfg-e2e -f "$key_path"
  chmod 600 "$key_path"
}

vbox_ssh() {
  local username=$1
  local key_path=$2
  local port=$3

  shift 3
  ssh \
    -i "$key_path" \
    -p "$port" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=10 \
    "$username@127.0.0.1" \
    "$@"
}

vbox_scp_to() {
  local username=$1
  local key_path=$2
  local port=$3
  local source=$4
  local target_path=$5

  scp \
    -i "$key_path" \
    -P "$port" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "$source" \
    "$username@127.0.0.1:$target_path"
}

vbox_scp_from() {
  local username=$1
  local key_path=$2
  local port=$3
  local source_path=$4
  local target_path=$5

  install -dm700 "$(dirname -- "$target_path")"
  scp \
    -r \
    -i "$key_path" \
    -P "$port" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "$username@127.0.0.1:$source_path" \
    "$target_path"
}

vbox_wait_for_ssh() {
  local username=$1
  local key_path=$2
  local port=$3
  local timeout_seconds=$4
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if vbox_ssh "$username" "$key_path" "$port" true >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done

  vbox_log_warn "Timed out waiting for SSH access as $username on localhost:$port"
  return 1
}

vbox_wait_for_ssh_network() {
  local username=$1
  local key_path=$2
  local port=$3
  local timeout_seconds=$4
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if vbox_ssh "$username" "$key_path" "$port" 'ping -c 1 -W 3 archlinux.org >/dev/null' >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done

  vbox_log_warn "Timed out waiting for network access over SSH on localhost:$port"
  return 1
}

vbox_console_run() {
  local vm=$1
  local command=$2

  VBoxManage controlvm "$vm" keyboardputstring "$command"
  sleep 1
  vbox_console_press_enter "$vm"
}

vbox_console_press_enter() {
  local vm=$1

  VBoxManage controlvm "$vm" keyboardputscancode 1c 9c
}

vbox_bootstrap_official_ssh() {
  local vm=$1
  local key_path=$2
  local port=$3
  local timeout_seconds=$4
  local public_key
  local command
  local deadline

  [[ -f "$key_path.pub" ]] || vbox_die "Missing public SSH key: $key_path.pub"
  public_key=$(<"$key_path.pub")
  [[ "$public_key" =~ ^ssh-ed25519[[:space:]][A-Za-z0-9+/=]+[[:space:]]archcfg-e2e$ ]] || vbox_die "Unexpected generated SSH public key format"
  command="install -dm700 /root/.ssh; printf '%s\\n' '$public_key' > /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys; systemctl start sshd"
  vbox_log_info "Waiting for the official ISO root console"
  sleep 30
  deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    vbox_console_run "$vm" "$command"
    if vbox_ssh root "$key_path" "$port" true >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done

  vbox_log_warn "Timed out bootstrapping SSH from the official Arch ISO"
  return 1
}

vbox_collect_vm_evidence() {
  local vm=$1
  local destination=$2
  local cfg_file
  local vm_dir

  install -dm700 "$destination"
  VBoxManage showvminfo "$vm" --machinereadable > "$destination/showvminfo.txt" 2>&1 || true

  cfg_file=$(vbox_machine_value "$vm" CfgFile 2>/dev/null || true)
  [[ -n "$cfg_file" ]] || return 0
  vm_dir=$(dirname -- "$cfg_file")
  [[ -d "$vm_dir/Logs" ]] && cp -a "$vm_dir/Logs" "$destination/"
}

vbox_remove_managed_vm() {
  local vm=$1
  local cfg_file
  local expected_prefix="$ARCHCFG_VBOX_VM_ROOT/$vm/"

  vbox_require_managed_vm_name "$vm"
  cfg_file=$(vbox_machine_value "$vm" CfgFile) || {
    vbox_log_warn "Could not determine the configuration path for $vm; leaving it intact"
    return 1
  }
  [[ "$cfg_file" == "$expected_prefix"* ]] || {
    vbox_log_warn "VM $vm is outside the managed VM root; leaving it intact"
    return 1
  }

  vbox_power_off_vm "$vm" || true
  VBoxManage unregistervm "$vm" --delete
}
