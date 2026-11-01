#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../scripts/apply-printing.sh
source "$REPO_DIR/scripts/apply-printing.sh"
TEST_DIR=$(mktemp -d)
trap 'command rm -rf -- "$TEST_DIR"' EXIT
HOME_DIR="$TEST_DIR/home"
ECN_CUPS_SERVER=example.test
ECN_CAREER_ACCOUNT=tester
mkdir -p "$HOME_DIR/.cups"
getent() { printf 'tester:x:1000:1000::%s:/bin/bash\n' "$HOME_DIR"; }
chown() { :; }
systemctl() { exit 99; }
lpadmin() { exit 99; }

BACKUP_DIR=$(mktemp -d "$TEST_DIR/backup.XXXXXX")
printf 'Original private settings\n' > "$HOME_DIR/.cups/client.conf"
chmod 600 "$HOME_DIR/.cups/client.conf"
write_cups_client_conf tester
SAVED="$BACKUP_DIR/files$HOME_DIR/.cups/client.conf"
[[ "$(<"$SAVED")" == 'Original private settings' ]]
[[ "$(stat -c %a "$SAVED")" == 600 ]]
[[ "$(stat -c %a "$BACKUP_DIR")" == 700 ]]
[[ "$(stat -c %a "$(dirname "$SAVED")")" == 700 ]]
grep -qx 'ServerName example.test' "$HOME_DIR/.cups/client.conf"

BACKUP_DIR=$(mktemp -d "$TEST_DIR/backup.XXXXXX")
write_cups_client_conf tester
grep -qx 'ServerName example.test' "$BACKUP_DIR/files$HOME_DIR/.cups/client.conf"

HOME_DIR="$TEST_DIR/new-home"
mkdir "$HOME_DIR"
BACKUP_DIR=$(mktemp -d "$TEST_DIR/backup.XXXXXX")
write_cups_client_conf tester
[[ "$(<"$BACKUP_DIR/absent-paths.txt")" == "$HOME_DIR/.cups/client.conf" ]]
[[ "$(stat -c %a "$BACKUP_DIR/absent-paths.txt")" == 600 ]]

printf 'Do not replace\n' > "$HOME_DIR/.cups/client.conf"
if (cp() { return 1; }; write_cups_client_conf tester); then
  printf 'Backup failure did not stop the write\n' >&2
  exit 1
fi
[[ "$(<"$HOME_DIR/.cups/client.conf")" == 'Do not replace' ]]
HOME_DIR="$TEST_DIR/absent-failure-home"
mkdir "$HOME_DIR"
BACKUP_DIR=$(mktemp -d "$TEST_DIR/backup.XXXXXX")
mkdir "$BACKUP_DIR/absent-paths.txt"
if (write_cups_client_conf tester) > /dev/null 2>&1; then
  printf 'Absence recording failure did not stop the write\n' >&2
  exit 1
fi
[[ ! -e "$HOME_DIR/.cups/client.conf" ]]
HOME_DIR="$TEST_DIR/linked-home"
mkdir "$HOME_DIR"
ln -s "$TEST_DIR/home/.cups" "$HOME_DIR/.cups"
if (write_cups_client_conf tester) > /dev/null 2>&1; then
  printf 'Accepted a symlinked CUPS directory\n' >&2
  exit 1
fi
# All provisioning fixtures are synthetic; never load the host's configuration.
require_root() { :; }
require_command() { printf 'dependency\n' >> "$TEST_DIR/side-effects"; }
reject_config() {
  if (main "$@") > "$TEST_DIR/rejected" 2>&1; then
    printf 'Accepted an invalid printing configuration\n' >&2
    exit 1
  fi
  [[ ! -e "$TEST_DIR/side-effects" ]]
}
PRINTING_CONFIG="$REPO_DIR/printing/printing.conf"
reject_config
grep -q 'provision a private file and pass --config PATH' "$TEST_DIR/rejected"
reject_config --config
reject_config --config "$TEST_DIR/missing"
reject_config --unknown
fixture="$TEST_DIR/printing.conf"
cat > "$fixture" <<'EOF'
ECN_CUPS_SERVER=spooler.example.test
ECN_CAREER_ACCOUNT=fixture-account
PAPERCUT_HOST=release.example.test
PAPERCUT_PORT=9163
PAPERCUT_QUEUES="fixture-mono fixture-color"
EOF
parse_args --config "$fixture" --user tester
[[ "$PRINTING_CONFIG" == "$fixture" && "$TARGET_USER" == tester ]]
load_printing_conf
[[ "$ECN_CUPS_SERVER" == spooler.example.test && "$ECN_CAREER_ACCOUNT" == fixture-account ]]
[[ "$PAPERCUT_HOST" == release.example.test && "$PAPERCUT_PORT" == 9163 ]]
lpadmin() { printf '%s\n' "$*" >> "$TEST_DIR/queues"; }
ensure_papercut_queues > "$TEST_DIR/queue-output"
[[ $(wc -l < "$TEST_DIR/queues") == 2 ]]
grep -q 'ipp://release.example.test:9163/printers/fixture-mono' "$TEST_DIR/queues"
! grep -q 'release.example.test\|fixture-mono' "$TEST_DIR/queue-output"
for field in ECN_CUPS_SERVER ECN_CAREER_ACCOUNT PAPERCUT_HOST PAPERCUT_PORT PAPERCUT_QUEUES; do
  sed "/^$field=/d" "$fixture" > "$TEST_DIR/incomplete.conf"
  # Existing values from a prior load must not satisfy a missing field.
  reject_config --config "$TEST_DIR/incomplete.conf"
  grep -q "$field" "$TEST_DIR/rejected"
done
for value in '' '<required>' 'https://invalid.example.test' $'bad\nInjected'; do
  cp "$fixture" "$TEST_DIR/invalid.conf"
  printf 'ECN_CUPS_SERVER=%q\n' "$value" >> "$TEST_DIR/invalid.conf"
  reject_config --config "$TEST_DIR/invalid.conf"
done
for value in 0 65536 -1 abc; do
  cp "$fixture" "$TEST_DIR/invalid.conf"
  printf 'PAPERCUT_PORT=%q\n' "$value" >> "$TEST_DIR/invalid.conf"
  reject_config --config "$TEST_DIR/invalid.conf"
done
for value in ' ' '*' '-invalid' 'bad/path'; do
  cp "$fixture" "$TEST_DIR/invalid.conf"
  printf 'PAPERCUT_QUEUES=%q\n' "$value" >> "$TEST_DIR/invalid.conf"
  reject_config --config "$TEST_DIR/invalid.conf"
done
cp "$fixture" "$TEST_DIR/invalid.conf"
printf 'ECN_CAREER_ACCOUNT="fixture-account invalid"\n' >> "$TEST_DIR/invalid.conf"
reject_config --config "$TEST_DIR/invalid.conf"
! grep -q 'fixture-account invalid' "$TEST_DIR/rejected"
printf 'printing backup and private provisioning tests passed\n'
