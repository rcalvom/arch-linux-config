#!/usr/bin/env python3
"""Exercise helper guards and rollback with private fixtures, never host targets."""
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/apply-greeter-theme.sh'


def run(code, *args):
    return subprocess.run(['bash', '-c', 'source "$1"; ' + code, 'test', str(HELPER), *map(str, args)], capture_output=True, text=True)


assert run('main --help').returncode == 0
assert run('main --invalid').returncode != 0
assert run('require_root() { die "mock non-root"; }; main').returncode != 0
assert run('main --help').stdout.startswith('Usage:')
with tempfile.TemporaryDirectory(prefix='greeter-helper-') as directory:
    root = Path(directory)
    backup = root / 'backup'
    backup.mkdir(mode=0o700)
    target = root / 'config'
    absent = root / 'previously-absent'
    target.write_text('new configuration')
    absent.write_text('new wrapper')
    (backup / '0.original').write_text('original configuration')
    (backup / '0.original').chmod(0o600)
    (backup / '0.mode').write_text('640\n')
    result = run('backup=$2; targets=("$3" "$4"); changed=1; trap rollback EXIT; exit 42', backup, target, absent)
    assert result.returncode == 42 and 'NOT backed up or restored' in result.stderr
    assert target.read_text() == 'original configuration'
    assert target.stat().st_mode & 0o777 == 0o640
    assert not absent.exists()
    link = root / 'link'
    link.symlink_to(target)
    assert run('check_path "$2"', link).returncode != 0
    link.unlink()
    link.symlink_to(backup, target_is_directory=True)
    assert run('check_path "$2"', link / 'missing').returncode != 0
    assert run('check_path "$2"', target).returncode == 0
    assert run('check_path "$2"', absent).returncode == 0
    # Exercise the exact embedded FONT merge against fixtures, including shell-like
    # data that must remain literal and must never be sourced.
    merge = HELPER.read_text().split('python3 - "$backup/3.original" "$backup/3.candidate" <<\'PY\'\n')[1].split('\nPY\n')[0]
    candidate = root / 'candidate'
    for text in ('KEYMAP=us\nFONT=old\nFONT_MAP=test\n', '# comment\nKEYMAP=de\n FONT =old\nFONT=duplicate\n', 'KEYMAP=$(never-execute)'):
        target.write_text(text)
        result = subprocess.run(['python3', '-c', merge, str(target), str(candidate)], capture_output=True)
        assert result.returncode == 0
        merged = candidate.read_text()
        assert merged.endswith('FONT=ter-v28b\n')
        assert next(line for line in text.splitlines() if line.startswith('KEYMAP=')) in merged
        assert 'FONT=old' not in merged and 'FONT=duplicate' not in merged
    target.unlink()
    subprocess.run(['python3', '-c', merge, str(target), str(candidate)], check=True)
    assert candidate.read_text() == 'FONT=ter-v28b\n'

print('Greeter helper argument, root guard, symlink and rollback fixture checks passed.')
