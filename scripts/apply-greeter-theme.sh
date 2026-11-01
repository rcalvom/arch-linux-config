#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: sudo bash scripts/apply-greeter-theme.sh' \
    'Requires interactive APPLY confirmation. Backs up six files, preserves KEYMAP,' \
    'installs the theme and session wrappers, and runs mkinitcpio -P.' \
    'Never changes PAM, loads console settings, restarts services, or reboots.'
}

die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_root() { [[ $EUID == 0 ]] || die 'Run this script with sudo'; }

# Refuse symlinks in destinations and their parent directories.
check_path() {
  local path=$1
  [[ ! -e $path || -f $path ]] || die "Not a regular file: $path"
  while [[ $path != / ]]; do
    [[ ! -L $path ]] || die "Refusing symlink: $path"
    path=$(dirname -- "$path")
  done
}

rollback() {
  local status=$? i failed=0
  trap - EXIT
  if [[ $status != 0 && ${changed:-0} == 1 ]]; then
    for i in "${!targets[@]}"; do
      if [[ -f $backup/$i.original ]]; then
        cp --preserve=all -- "$backup/$i.original" "${targets[i]}" || failed=1
        chmod "$(< "$backup/$i.mode")" "${targets[i]}" || failed=1
      else
        rm -f -- "${targets[i]}" || failed=1
      fi
    done
    printf '[ERROR] Update failed; config rollback failures: %s. Backup: %s\n' "$failed" "$backup" >&2
    printf '%s\n' 'Initramfs images are NOT backed up or restored. Do not reboot until mkinitcpio -P succeeds with the intended configuration.' >&2
  fi
  exit "$status"
}

main() {
  if [[ $# == 1 && $1 == --help ]]; then usage; return; fi
  [[ $# == 0 ]] || die 'Unknown arguments; use --help'
  require_root
  export PATH=/usr/bin:/bin
  umask 077
  local repo command confirmation source i path
  repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  for command in python3 tuigreet mkinitcpio flock setvtrgb start-hyprland startx; do
    command -v "$command" >/dev/null || die "Missing prerequisite: $command"
  done
  python3 -c 'import tomllib'
  id greeter >/dev/null || die 'Missing greeter account'
  [[ -r /usr/share/kbd/consolefonts/ter-v28b.psf.gz ]] || die 'Install terminus-font first'
  [[ -d /etc/mkinitcpio.d && -f /etc/pam.d/greetd ]] || die 'Expected installed greetd/mkinitcpio setup'
  compgen -G '/etc/mkinitcpio.d/*.preset' >/dev/null || die 'No mkinitcpio presets'
  local -a sources=(config.toml vtrgb greetd-vtrgb.conf vconsole.conf archcfg-wayland-session-wrapper archcfg-xsession-wrapper)
  targets=(/etc/greetd/config.toml /etc/vtrgb /etc/systemd/system/greetd.service.d/10-vtrgb.conf /etc/vconsole.conf /usr/local/libexec/archcfg-wayland-session-wrapper /usr/local/libexec/archcfg-xsession-wrapper)
  for path in "${targets[@]}" /var/lib/arch-linux-config/greeter-backups/.probe; do check_path "$path"; done
  for source in "${sources[@]}"; do
    [[ -f $repo/greetd/$source && ! -L $repo/greetd/$source ]] || die "Missing regular source: $source"
  done
  bash -n "$repo/greetd/archcfg-wayland-session-wrapper"
  bash -n "$repo/greetd/archcfg-xsession-wrapper"
  tuigreet --version
  # Parse data only; never source or evaluate either host or repository configs.
  python3 - "$repo/greetd" <<'PY'
import pathlib, re, shlex, subprocess, sys, tomllib
root = pathlib.Path(sys.argv[1])
config = tomllib.loads((root / 'config.toml').read_text())
assert set(config) == {'terminal', 'default_session'}
assert config['terminal'] == {'vt': 1}
assert set(config['default_session']) == {'command', 'user'}
assert config['default_session']['user'] == 'greeter'
command = config['default_session']['command']
assert not any(c in command for c in '\n\r`$\\')
args = shlex.split(command)
assert args[0] == 'tuigreet'
lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
lexer.whitespace_split = True
assert not any(re.fullmatch(r'[;&|<>()]+', token) for token in lexer)
help_text = subprocess.check_output(['tuigreet', '--help'], text=True)
flags = set(re.findall(r'--[a-z][a-z-]*', help_text))
assert all(arg in flags for arg in args if arg.startswith('--'))
for flag, value in {'--cmd': 'Hyprland', '--session-wrapper': '/usr/local/libexec/archcfg-wayland-session-wrapper', '--xsession-wrapper': '/usr/local/libexec/archcfg-xsession-wrapper', '--sessions': '/usr/share/wayland-sessions', '--xsessions': '/usr/share/xsessions'}.items():
    assert args.count(flag) == 1 and args[args.index(flag) + 1] == value
for directory in ('/usr/share/wayland-sessions', '/usr/share/xsessions'):
    assert pathlib.Path(directory).is_dir(), directory
palette = (root / 'vtrgb').read_text().splitlines()
assert len(palette) == 16 and all(re.fullmatch(r'#[0-9a-fA-F]{6}', c) for c in palette)
assert (root / 'vconsole.conf').read_text() == 'KEYMAP=la-latin1\nFONT=ter-v28b\n'
assert (root / 'greetd-vtrgb.conf').read_text().splitlines() == ['[Service]', '# Theme-only step; never block login if console palette setup fails.', 'ExecStartPre=-/usr/bin/setvtrgb /etc/vtrgb']
PY
  exec 9>/run/lock/arch-linux-config-greeter.lock
  flock -n 9 || die 'Another greeter update is running'
  printf '%s\n' 'Replace theme/session configuration and rebuild initramfs. PAM and KEYMAP remain unchanged.'
  printf 'Type APPLY to continue: '
  read -r confirmation
  [[ $confirmation == APPLY ]] || die 'Cancelled'
  install -dm700 /var/lib/arch-linux-config/greeter-backups
  backup=$(mktemp -d /var/lib/arch-linux-config/greeter-backups/"$(date +%Y%m%dT%H%M%S)".XXXXXXXX)
  printf '[INFO] Private backup: %s\n' "$backup"
  for i in "${!targets[@]}"; do
    path=${targets[i]}
    printf '%s\n' "$path" > "$backup/$i.path"
    if [[ -e $path ]]; then
      stat -c %a "$path" > "$backup/$i.mode"
      cp --preserve=all -- "$path" "$backup/$i.original"
      chmod 600 "$backup/$i.original"
    else
      : > "$backup/$i.absent"
    fi
    install -m600 "$repo/greetd/${sources[i]}" "$backup/$i.candidate"
  done
  python3 - "$backup/3.original" "$backup/3.candidate" <<'PY'
import pathlib, re, sys
original, candidate = map(pathlib.Path, sys.argv[1:])
text = original.read_text() if original.exists() else ''
lines = [line for line in text.splitlines(keepends=True) if not re.match(r'^\s*FONT\s*=', line)]
text = ''.join(lines)
candidate.write_text(text + ('' if not text or text.endswith('\n') else '\n') + 'FONT=ter-v28b\n')
PY
  changed=0
  trap rollback EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  changed=1
  for i in "${!targets[@]}"; do
    local mode=644
    [[ $i -lt 4 ]] || mode=755
    install -Dm"$mode" -o root -g root "$backup/$i.candidate" "${targets[i]}"
  done
  printf '%s\n' '[INFO] Rebuilding initramfs; images are not included in the config backup.'
  mkinitcpio -P > "$backup/mkinitcpio.log" 2>&1 || die "mkinitcpio failed; diagnostics: $backup/mkinitcpio.log"
  changed=0
  printf '[INFO] Applied for a future reboot; no services restarted. Backup: %s\n' "$backup"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
