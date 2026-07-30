#!/usr/bin/env bash
# Portable, user-level development environment bootstrap for Linux servers.
# It deliberately continues after optional failures and summarizes them at exit.

set -uo pipefail

: "${HOME:?HOME must be set}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PAYLOAD_DIR="$SCRIPT_DIR/payload"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ZSH_CONFIG_HOME="${ZDOTDIR:-$HOME}"
ZSH_CUSTOM_HOME="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

DRY_RUN=false
SKIP_PACKAGES=false
SKIP_OH_MY_ZSH=false
SKIP_OPENCODE_INSTALL=false
SET_DEFAULT_SHELL=false
PACMAN_UPGRADE=false
PACKAGE_MANAGER=""
BACKUP_DIR=""
NVIM_SUPPORTED=false

declare -a COMPLETED_STEPS=()
declare -a FAILED_STEPS=()
declare -a FAILURE_DETAILS=()

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: bash bootstrap.sh [options]

Configure a portable terminal development environment for the current user.
The script never changes disks, services, network settings, SSH settings, or
credentials. Existing managed files are backed up before replacement.

Options:
  --dry-run                Print actions without changing the system.
  --skip-packages          Do not refresh package metadata or install packages.
  --skip-oh-my-zsh         Do not clone Oh My Zsh; still deploy the Zsh config.
  --skip-opencode-install  Do not install OpenCode; still deploy its config/theme.
  --set-zsh-default        Run chsh after installation to make Zsh the login shell.
  --pacman-upgrade         Explicitly run pacman -Syu before installing packages.
  -h, --help               Show this help.
EOF
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] $(printf '%q ' "$@")"
    return 0
  fi

  "$@"
}

run_step() {
  local name=$1
  shift

  log_info "$name"
  if "$@"; then
    COMPLETED_STEPS+=("$name")
    return 0
  fi

  log_error "$name failed; continuing with the remaining steps."
  FAILED_STEPS+=("$name")
  return 0
}

require_unprivileged_user() {
  if [[ $EUID -eq 0 ]]; then
    log_error "Run this script as the target user, not as root or through sudo."
    return 1
  fi
}

normalize_xdg_paths() {
  if [[ "$CONFIG_HOME" != /* ]]; then
    log_warn "Ignoring relative XDG_CONFIG_HOME: $CONFIG_HOME"
    CONFIG_HOME="$HOME/.config"
  fi

  if [[ "$STATE_HOME" != /* ]]; then
    log_warn "Ignoring relative XDG_STATE_HOME: $STATE_HOME"
    STATE_HOME="$HOME/.local/state"
  fi
}

dependencies_are_planned() {
  [[ "$DRY_RUN" == true && "$SKIP_PACKAGES" == false && -n "$PACKAGE_MANAGER" ]]
}

parse_args() {
  while (($# > 0)); do
    case $1 in
      --dry-run)
        DRY_RUN=true
        ;;
      --skip-packages)
        SKIP_PACKAGES=true
        ;;
      --skip-oh-my-zsh)
        SKIP_OH_MY_ZSH=true
        ;;
      --skip-opencode-install)
        SKIP_OPENCODE_INSTALL=true
        ;;
      --set-zsh-default)
        SET_DEFAULT_SHELL=true
        ;;
      --pacman-upgrade)
        PACMAN_UPGRADE=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage >&2
        return 1
        ;;
    esac
    shift
  done
}

validate_payload() {
  local file
  local missing=0
  local -a required_files=(
    "zsh/.zshrc"
    "zsh/ginger.zsh-theme"
    "nvim/init.lua"
    "nvim/lua/server/options.lua"
    "nvim/lua/server/colors.lua"
    "nvim/lua/server/keymaps.lua"
    "nvim/lua/server/autocmds.lua"
    "tmux/tmux.conf"
    "opencode/opencode.jsonc"
    "opencode/tui.json"
    "opencode/themes/ginger.json"
  )

  for file in "${required_files[@]}"; do
    if [[ ! -f "$PAYLOAD_DIR/$file" ]]; then
      log_error "Missing bootstrap payload: $PAYLOAD_DIR/$file"
      missing=1
    fi
  done

  return "$missing"
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER=apt
  elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER=dnf
  elif command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER=pacman
  elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER=zypper
  elif command -v apk >/dev/null 2>&1; then
    PACKAGE_MANAGER=apk
  else
    log_error "No supported package manager found (apt, dnf, pacman, zypper, apk)."
    return 1
  fi

  log_info "Detected package manager: $PACKAGE_MANAGER"
}

run_as_root() {
  if [[ $EUID -eq 0 ]]; then
    run "$@"
  elif command -v sudo >/dev/null 2>&1; then
    run sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    run doas "$@"
  else
    log_error "Neither sudo nor doas is available; package installation cannot continue."
    return 1
  fi
}

refresh_package_metadata() {
  case $PACKAGE_MANAGER in
    apt)
      run_as_root apt-get update
      ;;
    dnf)
      run_as_root dnf makecache
      ;;
    pacman)
      if [[ "$PACMAN_UPGRADE" == true ]]; then
        log_info "Pacman will refresh and upgrade the system during package installation."
      else
        # Avoid a partial upgrade or an unexpected full system upgrade.
        log_info "Pacman metadata is left untouched; the system must already be current."
      fi
      ;;
    zypper)
      run_as_root zypper --non-interactive refresh
      ;;
    apk)
      run_as_root apk update
      ;;
    *)
      log_error "Package manager detection did not complete."
      return 1
      ;;
  esac
}

verify_pacman_state() {
  local pending_updates

  [[ "$PACKAGE_MANAGER" == pacman ]] || return 0
  [[ "$PACMAN_UPGRADE" == true ]] && return 0

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] Pacman system-current check"
    return 0
  fi

  pending_updates=$(pacman -Qu 2>&1) || true
  if [[ -n "$pending_updates" ]]; then
    log_error "Pacman reports pending upgrades. Run sudo pacman -Syu first or use --pacman-upgrade."
    FAILURE_DETAILS+=("Pacman system has pending upgrades")
    return 1
  fi
}

install_package() {
  local package=$1

  case $PACKAGE_MANAGER in
    apt)
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package"
      ;;
    dnf)
      run_as_root dnf install -y "$package"
      ;;
    pacman)
      run_as_root pacman -S --needed --noconfirm "$package"
      ;;
    zypper)
      run_as_root zypper --non-interactive install --no-recommends "$package"
      ;;
    apk)
      run_as_root apk add "$package"
      ;;
    *)
      log_error "Package manager detection did not complete."
      return 1
      ;;
  esac
}

install_base_packages() {
  local package
  local status=0
  local -a packages=()

  case $PACKAGE_MANAGER in
    apt)
      packages=(ca-certificates curl fd-find git neovim nodejs npm ripgrep tmux zsh)
      ;;
    dnf)
      packages=(ca-certificates curl fd-find git neovim nodejs npm ripgrep tmux zsh)
      ;;
    pacman)
      packages=(ca-certificates curl fd git neovim nodejs npm ripgrep tmux zsh)
      ;;
    zypper)
      packages=(ca-certificates curl fd git neovim nodejs npm ripgrep tmux zsh)
      ;;
    apk)
      packages=(ca-certificates curl fd git neovim nodejs npm ripgrep tmux zsh)
      ;;
    *)
      log_error "Package manager detection did not complete."
      return 1
      ;;
  esac

  if [[ "$PACKAGE_MANAGER" == pacman ]]; then
    if [[ "$PACMAN_UPGRADE" == true ]]; then
      log_info "Refreshing and upgrading Pacman before installing requested tools."
      if ! run_as_root pacman -Syu --needed --noconfirm "${packages[@]}"; then
        FAILURE_DETAILS+=("Pacman system upgrade and package installation")
        return 1
      fi
      return 0
    fi

    verify_pacman_state || return 1
  fi

  for package in "${packages[@]}"; do
    log_info "Installing package: $package"
    if ! install_package "$package"; then
      log_error "Package installation failed: $package"
      FAILURE_DETAILS+=("Package: $package")
      status=1
    fi
  done

  return "$status"
}

install_fd_compatibility_link() {
  local fd_path

  if command -v fd >/dev/null 2>&1; then
    log_info "fd is already available."
    return 0
  fi

  if ! command -v fdfind >/dev/null 2>&1; then
    if dependencies_are_planned; then
      log_info "[dry-run] fd compatibility link will be checked after package installation."
      return 0
    fi

    log_info "fdfind is unavailable; no fd compatibility link is needed."
    return 0
  fi

  fd_path="$HOME/.local/bin/fd"
  if [[ -e "$fd_path" || -L "$fd_path" ]]; then
    log_warn "Leaving existing $fd_path unchanged."
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] create $fd_path -> $(command -v fdfind)"
    return 0
  fi

  mkdir -p -- "$HOME/.local/bin" || return 1
  ln -s -- "$(command -v fdfind)" "$fd_path"
}

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"

  if [[ -r "$omz_dir/oh-my-zsh.sh" ]]; then
    log_info "Oh My Zsh is already installed."
    return 0
  fi

  if [[ -e "$omz_dir" ]]; then
    log_error "$omz_dir exists but is not a usable Oh My Zsh installation."
    return 1
  fi

  if [[ "$DRY_RUN" == true ]] && { command -v git >/dev/null 2>&1 || dependencies_are_planned; }; then
    run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_error "git is required to install Oh My Zsh."
    return 1
  fi

  run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
}

symlinked_parent() {
  local directory

  directory=$(dirname -- "$1")
  while [[ "$directory" != "/" ]]; do
    if [[ -L "$directory" ]]; then
      printf '%s\n' "$directory"
      return 0
    fi

    [[ "$directory" == "$HOME" ]] && break
    directory=$(dirname -- "$directory")
  done

  return 1
}

create_backup_dir() {
  local parent="$STATE_HOME/server-bootstrap/backups"

  if [[ -n "$BACKUP_DIR" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    BACKUP_DIR="$parent/dry-run"
    return 0
  fi

  mkdir -p -- "$parent" || return 1
  BACKUP_DIR=$(mktemp -d "$parent/run.XXXXXX") || return 1
}

backup_file() {
  local destination=$1
  local relative_path
  local backup_path

  [[ -e "$destination" || -L "$destination" ]] || return 0
  create_backup_dir || return 1

  if [[ "$destination" == "$HOME/"* ]]; then
    relative_path=${destination#"$HOME/"}
  else
    relative_path=$(basename -- "$destination")
  fi
  backup_path="$BACKUP_DIR/$relative_path"

  log_info "Backing up $destination to $backup_path"
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi

  mkdir -p -- "$(dirname -- "$backup_path")" || return 1
  cp -a -- "$destination" "$backup_path"
}

install_managed_file() {
  local source=$1
  local destination=$2
  local mode=$3
  local linked_parent

  if [[ ! -f "$source" ]]; then
    log_error "Missing source file: $source"
    FAILURE_DETAILS+=("Missing source: $source")
    return 1
  fi

  if [[ -L "$destination" ]]; then
    log_error "Refusing to replace symlinked file: $destination"
    FAILURE_DETAILS+=("Symlinked destination: $destination")
    return 1
  fi

  if linked_parent=$(symlinked_parent "$destination"); then
    log_error "Refusing to write through symlinked directory: $linked_parent"
    FAILURE_DETAILS+=("Symlinked parent: $linked_parent")
    return 1
  fi

  if [[ -d "$destination" ]]; then
    log_error "Expected a file but found a directory: $destination"
    FAILURE_DETAILS+=("Destination is a directory: $destination")
    return 1
  fi

  if [[ -f "$destination" ]] && cmp -s -- "$source" "$destination"; then
    log_info "Already current: $destination"
    return 0
  fi

  if ! backup_file "$destination"; then
    log_error "Could not back up $destination"
    FAILURE_DETAILS+=("Backup: $destination")
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] install $source -> $destination"
    return 0
  fi

  if ! install -Dm"$mode" -- "$source" "$destination"; then
    log_error "Could not install $destination"
    FAILURE_DETAILS+=("File: $destination")
    return 1
  fi
}

deploy_zsh() {
  local status=0

  if [[ "$ZSH_CUSTOM_HOME" != /* ]]; then
    log_error "ZSH_CUSTOM must be an absolute path: $ZSH_CUSTOM_HOME"
    FAILURE_DETAILS+=("Invalid ZSH_CUSTOM: $ZSH_CUSTOM_HOME")
    status=1
  else
    install_managed_file "$PAYLOAD_DIR/zsh/ginger.zsh-theme" \
      "$ZSH_CUSTOM_HOME/themes/ginger.zsh-theme" 0644 || status=1
  fi

  if [[ "$ZSH_CONFIG_HOME" != /* ]]; then
    log_error "ZDOTDIR must be an absolute path: $ZSH_CONFIG_HOME"
    FAILURE_DETAILS+=("Invalid ZDOTDIR: $ZSH_CONFIG_HOME")
    status=1
  else
    install_managed_file "$PAYLOAD_DIR/zsh/.zshrc" "$ZSH_CONFIG_HOME/.zshrc" 0644 || status=1
  fi

  return "$status"
}

deploy_nvim() {
  local file
  local status=0
  local -a files=(
    "init.lua"
    "lua/server/options.lua"
    "lua/server/colors.lua"
    "lua/server/keymaps.lua"
    "lua/server/autocmds.lua"
  )

  for file in "${files[@]}"; do
    install_managed_file "$PAYLOAD_DIR/nvim/$file" "$CONFIG_HOME/nvim/$file" 0644 || status=1
  done

  return "$status"
}

deploy_tmux() {
  install_managed_file "$PAYLOAD_DIR/tmux/tmux.conf" "$HOME/.tmux.conf" 0644
}

deploy_opencode() {
  local status=0

  install_managed_file "$PAYLOAD_DIR/opencode/opencode.jsonc" \
    "$CONFIG_HOME/opencode/opencode.jsonc" 0644 || status=1
  install_managed_file "$PAYLOAD_DIR/opencode/tui.json" \
    "$CONFIG_HOME/opencode/tui.json" 0644 || status=1
  install_managed_file "$PAYLOAD_DIR/opencode/themes/ginger.json" \
    "$CONFIG_HOME/opencode/themes/ginger.json" 0644 || status=1

  return "$status"
}

check_nvim_version() {
  local version_output
  local major
  local minor

  NVIM_SUPPORTED=false
  if ! command -v nvim >/dev/null 2>&1; then
    if dependencies_are_planned; then
      log_info "[dry-run] Neovim will be installed before its configuration is deployed."
      NVIM_SUPPORTED=true
      return 0
    fi

    log_error "Neovim is not installed."
    return 1
  fi

  version_output=$(nvim --version 2>&1) || {
    log_error "Could not determine the Neovim version."
    return 1
  }

  if [[ ! "$version_output" =~ ^NVIM[[:space:]]v([0-9]+)\.([0-9]+) ]]; then
    log_error "Could not parse the Neovim version."
    return 1
  fi

  major=${BASH_REMATCH[1]}
  minor=${BASH_REMATCH[2]}
  if ((major > 0 || minor >= 7)); then
    log_info "Neovim v$major.$minor is supported."
    NVIM_SUPPORTED=true
    return 0
  fi

  log_error "Neovim v$major.$minor is too old; this configuration requires v0.7 or newer."
  FAILURE_DETAILS+=("Neovim v$major.$minor is unsupported")
  return 1
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/opencode" ]]; then
    log_info "OpenCode is already installed."
    return 0
  fi

  if [[ "$DRY_RUN" == true ]] && { command -v npm >/dev/null 2>&1 || dependencies_are_planned; }; then
    run npm install --global --prefix "$HOME/.local" opencode-ai
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is required to install OpenCode."
    return 1
  fi

  run npm install --global --prefix "$HOME/.local" opencode-ai
}

set_zsh_as_default_shell() {
  local account_entry=""
  local login_shell=""
  local zsh_path

  if [[ "$DRY_RUN" == true ]]; then
    if ! command -v zsh >/dev/null 2>&1 && ! dependencies_are_planned; then
      log_error "Zsh is not installed and package installation is skipped."
      return 1
    fi

    zsh_path=$(command -v zsh 2>/dev/null || printf /usr/bin/zsh)
    run chsh -s "$zsh_path"
    return 0
  fi

  if ! zsh_path=$(command -v zsh); then
    log_error "Zsh is not installed."
    return 1
  fi

  if command -v getent >/dev/null 2>&1; then
    account_entry=$(getent passwd "$(id -u)" 2>/dev/null || true)
    login_shell=${account_entry##*:}
    if [[ -n "$account_entry" && "$login_shell" == "$zsh_path" ]]; then
      log_info "Zsh is already the account login shell."
      return 0
    fi
  fi

  if ! command -v chsh >/dev/null 2>&1; then
    log_error "chsh is unavailable."
    return 1
  fi

  run chsh -s "$zsh_path"
}

print_summary() {
  local step

  printf '\nBootstrap summary\n'
  printf 'Completed steps: %s\n' "${#COMPLETED_STEPS[@]}"

  if ((${#FAILED_STEPS[@]} == 0)); then
    printf 'Failed steps: none\n'
  else
    printf 'Failed steps (%s):\n' "${#FAILED_STEPS[@]}"
    for step in "${FAILED_STEPS[@]}"; do
      printf '  - %s\n' "$step"
    done

    if ((${#FAILURE_DETAILS[@]} > 0)); then
      printf 'Failure details:\n'
      for step in "${FAILURE_DETAILS[@]}"; do
        printf '  - %s\n' "$step"
      done
    fi
  fi

  if [[ -n "$BACKUP_DIR" ]]; then
    printf 'Backups: %s\n' "$BACKUP_DIR"
  fi

  printf '\nOpen a new Zsh session with: exec zsh\n'
  if [[ "$SET_DEFAULT_SHELL" == false ]]; then
    printf 'To make Zsh the login shell later: chsh -s "$(command -v zsh 2>/dev/null || printf /usr/bin/zsh)"\n'
  fi
  printf 'OpenCode credentials are intentionally not copied. Run opencode and use /connect.\n'
}

main() {
  parse_args "$@" || return 2
  require_unprivileged_user || return 2
  normalize_xdg_paths
  validate_payload || return 2

  if [[ "$SKIP_PACKAGES" == false ]]; then
    run_step "Detecting the package manager" detect_package_manager
    if [[ -n "$PACKAGE_MANAGER" ]]; then
      if [[ "$PACMAN_UPGRADE" == true && "$PACKAGE_MANAGER" != pacman ]]; then
        log_warn "--pacman-upgrade is ignored because Pacman is not in use."
      fi
      run_step "Refreshing package metadata" refresh_package_metadata
      run_step "Installing terminal development tools" install_base_packages
      run_step "Creating fd compatibility link" install_fd_compatibility_link
    else
      log_warn "Skipping package installation because no supported package manager was found."
    fi
  else
    log_info "Skipping package installation."
  fi

  if [[ "$SKIP_OH_MY_ZSH" == false ]]; then
    run_step "Installing Oh My Zsh" install_oh_my_zsh
  else
    log_info "Skipping Oh My Zsh installation."
  fi

  run_step "Deploying Zsh configuration and Ginger theme" deploy_zsh
  run_step "Checking Neovim version compatibility" check_nvim_version
  if [[ "$NVIM_SUPPORTED" == true ]]; then
    run_step "Deploying Neovim configuration and theme" deploy_nvim
  else
    log_warn "Skipping Neovim configuration to avoid installing an incompatible config."
  fi
  run_step "Deploying tmux configuration" deploy_tmux
  run_step "Deploying OpenCode configuration and Ginger theme" deploy_opencode

  if [[ "$SKIP_OPENCODE_INSTALL" == false ]]; then
    run_step "Installing OpenCode" install_opencode
  else
    log_info "Skipping OpenCode installation."
  fi

  if [[ "$SET_DEFAULT_SHELL" == true ]]; then
    run_step "Setting Zsh as the login shell" set_zsh_as_default_shell
  fi

  print_summary

  if ((${#FAILED_STEPS[@]} > 0)); then
    return 1
  fi
}

main "$@"
