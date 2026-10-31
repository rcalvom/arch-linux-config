#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
LAUNCHER="$REPO_DIR/packages/calcurse/archcfg-calcurse-google"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export PATH="$TEST_ROOT/bin:/usr/bin"

mkdir -p \
  "$TEST_ROOT/bin" \
  "$XDG_CONFIG_HOME/calcurse" \
  "$XDG_CONFIG_HOME/vdirsyncer" \
  "$XDG_DATA_HOME/vdirsyncer/calendars/example"
cp "$REPO_DIR/packages/calcurse/conf" "$XDG_CONFIG_HOME/calcurse/conf"
touch "$XDG_CONFIG_HOME/calcurse/keys"
touch "$XDG_CONFIG_HOME/vdirsyncer/config"

cat >"$TEST_ROOT/bin/vdirsyncer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sync\n' >>"$TEST_ROOT/sync.log"
printf 'internal sync detail\n'
printf 'internal sync warning\n' >&2
[[ ${CALCURSE_TEST_SYNC_FAIL:-false} != true ]]
EOF

cat >"$TEST_ROOT/bin/calcurse" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

data_dir=
import_file=
export_view=false
read_only=false
while (($#)); do
  case "$1" in
    -D)
      data_dir=$2
      shift 2
      ;;
    -i)
      import_file=$2
      shift 2
      ;;
    -G)
      export_view=true
      shift
      ;;
    --read-only)
      read_only=true
      shift
      ;;
    -C)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n "$import_file" ]]; then
  mkdir -p "$data_dir"
  printf '%s\n' "${import_file##*/}" >>"$data_dir/apts"
  printf 'import\n' >>"$TEST_ROOT/import.log"
elif "$export_view"; then
  [[ -s "$data_dir/apts" ]]
else
  grep -Fxq 'notification.command="$HOME/.local/bin/archcfg-calcurse-google-notify"' "$data_dir/conf"
  grep -Fxq 'notification.notifyall=all' "$data_dir/conf"
  grep -Fxq 'notification.warning=900' "$data_dir/conf"
  [[ $(grep -c '^notification\.' "$data_dir/conf") -eq 3 ]]
  grep -Fxq 'appearance.defaultpanel=calendar' "$data_dir/conf"
  printf 'interactive\n' >>"$TEST_ROOT/interactive.log"
  if "$read_only"; then
    printf 'test failure: interactive calendar is read-only\n' >&2
    exit 1
  fi
  if [[ ${CALCURSE_TEST_ADD_TODO:-false} == true ]]; then
    note_hash=0123456789abcdef0123456789abcdef01234567
    printf '[1]>%s Persistent task\n' "$note_hash" >>"$data_dir/todo"
    printf 'Persistent task note\n' >"$data_dir/notes/$note_hash"
  fi
  if [[ ${CALCURSE_TEST_RECOVERY_NOTES:-false} == true ]]; then
    for note_hash in 1111111111111111111111111111111111111111 2222222222222222222222222222222222222222; do
      printf '[1]>%s Recovery task\n' "$note_hash" >>"$data_dir/todo"
      printf 'Recovery note %s\n' "$note_hash" >"$data_dir/notes/$note_hash"
    done
    printf '%s\n' "$data_dir" >"$TEST_ROOT/recovery-session.path"
  fi
fi
EOF

chmod 755 "$TEST_ROOT/bin/vdirsyncer" "$TEST_ROOT/bin/calcurse"

cat >"$TEST_ROOT/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TEST_ROOT/local-notification.log"
EOF
chmod 755 "$TEST_ROOT/bin/notify-send"
local_command=$(sed -n 's/^notification.command=//p' "$XDG_CONFIG_HOME/calcurse/conf")
[[ $local_command != *google* ]]
TEST_ROOT=$TEST_ROOT sh -c "$local_command"
grep -Fxq 'Local calendar' "$TEST_ROOT/local-notification.log"
grep -Fxq 'An appointment is coming up. Check your running Calcurse session for details.' "$TEST_ROOT/local-notification.log"
grep -Fxq 'notification.notifyall=flagged-only' "$XDG_CONFIG_HOME/calcurse/conf"
grep -Fxq 'notification.warning=300' "$XDG_CONFIG_HOME/calcurse/conf"
local_config_hash=$(sha256sum "$XDG_CONFIG_HOME/calcurse/conf")

cat >"$XDG_DATA_HOME/vdirsyncer/calendars/example/event.ics" <<'EOF'
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:example
BEGIN:VALARM
TRIGGER:-PT15M
END:VALARM
END:VEVENT
END:VCALENDAR
EOF


cat >"$XDG_DATA_HOME/vdirsyncer/calendars/example/no-alarm.ics" <<'EOF'
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:no-alarm
END:VEVENT
END:VCALENDAR
EOF

CALCURSE_TEST_ADD_TODO=true TEST_ROOT=$TEST_ROOT "$LAUNCHER" >"$TEST_ROOT/first.out"
[[ $(wc -l <"$TEST_ROOT/import.log") -eq 2 ]]
[[ -f "$XDG_DATA_HOME/archcfg/calcurse-google/current/.archcfg-mirror-fingerprint" ]]
[[ $(wc -l <"$XDG_DATA_HOME/archcfg/calcurse-google/current/apts") -eq 2 ]]
[[ -L "$XDG_DATA_HOME/archcfg/calcurse-google-reminders/apts" ]]
grep -Fq 'event.ics' "$XDG_DATA_HOME/archcfg/calcurse-google-reminders/apts"
grep -Fq 'no-alarm.ics' "$XDG_DATA_HOME/archcfg/calcurse-google-reminders/apts"
grep -Fq 'Persistent task' "$XDG_DATA_HOME/calcurse/todo"
[[ -f "$XDG_DATA_HOME/calcurse/notes/0123456789abcdef0123456789abcdef01234567" ]]
grep -Fq '📅 Calendar Sync' "$TEST_ROOT/first.out"
grep -Fq 'Syncing calendars...' "$TEST_ROOT/first.out"
grep -Fq 'Updating calendar view...' "$TEST_ROOT/first.out"
grep -Fq 'Calendar ready.' "$TEST_ROOT/first.out"
if grep -Fq 'internal sync' "$TEST_ROOT/first.out"; then
  printf 'test failure: routine synchronization details were shown\n' >&2
  exit 1
fi

# Old generated profiles must gain the isolated configuration without reimporting.
rm "$XDG_DATA_HOME/archcfg/calcurse-google-reminders/conf"
TEST_ROOT=$TEST_ROOT "$LAUNCHER" --refresh >"$TEST_ROOT/refresh.out"
grep -Fxq 'notification.command="$HOME/.local/bin/archcfg-calcurse-google-notify"' \
  "$XDG_DATA_HOME/archcfg/calcurse-google-reminders/conf"
[[ ! -s "$TEST_ROOT/refresh.out" ]]
[[ $(wc -l <"$TEST_ROOT/import.log") -eq 2 ]]
[[ $(wc -l <"$TEST_ROOT/interactive.log") -eq 1 ]]

TEST_ROOT=$TEST_ROOT "$LAUNCHER" >"$TEST_ROOT/second.out"
[[ $(wc -l <"$TEST_ROOT/import.log") -eq 2 ]]
grep -Fq '📅 Calendar Sync' "$TEST_ROOT/second.out"
grep -Fq 'Syncing calendars...' "$TEST_ROOT/second.out"
grep -Fq 'Calendar ready.' "$TEST_ROOT/second.out"
if grep -Fq 'Updating calendar view...' "$TEST_ROOT/second.out"; then
  printf 'test failure: unchanged calendar triggered a rebuild\n' >&2
  exit 1
fi

printf 'X-TEST:changed\n' >>"$XDG_DATA_HOME/vdirsyncer/calendars/example/event.ics"
TEST_ROOT=$TEST_ROOT "$LAUNCHER" >"$TEST_ROOT/third.out"
[[ $(wc -l <"$TEST_ROOT/import.log") -eq 4 ]]

: >"$XDG_DATA_HOME/archcfg/calcurse-google/current/apts"
TEST_ROOT=$TEST_ROOT "$LAUNCHER" >"$TEST_ROOT/fourth.out"
[[ $(wc -l <"$TEST_ROOT/import.log") -eq 6 ]]
[[ $(wc -l <"$TEST_ROOT/sync.log") -eq 5 ]]

# Offline fallback must also repair stale notification settings without touching local data.
printf 'notification.command=wrong\n' >"$XDG_DATA_HOME/archcfg/calcurse-google-reminders/conf"
CALCURSE_TEST_SYNC_FAIL=true TEST_ROOT=$TEST_ROOT "$LAUNCHER" >"$TEST_ROOT/offline.out" 2>"$TEST_ROOT/offline.err"
grep -Fq 'sync failed' "$TEST_ROOT/offline.err"
[[ $(wc -l <"$TEST_ROOT/import.log") -eq 6 ]]
[[ $(sha256sum "$XDG_CONFIG_HOME/calcurse/conf") == "$local_config_hash" ]]
grep -Fq 'Persistent task' "$XDG_DATA_HOME/calcurse/todo"
[[ -f "$XDG_DATA_HOME/calcurse/notes/0123456789abcdef0123456789abcdef01234567" ]]

service="$REPO_DIR/packages/calcurse/systemd/archcfg-calcurse-google-reminder.service"
grep -Fxq 'ExecStart=/usr/bin/calcurse -D %h/.local/share/archcfg/calcurse-google-reminders -C %h/.local/share/archcfg/calcurse-google-reminders --daemon' "$service"
grep -Fxq 'ConditionPathExists=%h/.local/share/archcfg/calcurse-google-reminders/conf' "$service"

# Only the first of two notes fails to copy; cleanup must retain both for recovery.
cat >"$TEST_ROOT/bin/cp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${CALCURSE_TEST_COPY_FAIL:-false} == true &&
      ${!#} == "$XDG_DATA_HOME/calcurse/notes/1111111111111111111111111111111111111111" ]]; then
  printf 'copy failed\n' >>"$TEST_ROOT/copy-fail.log"
  exit 1
fi
exec /usr/bin/cp "$@"
EOF
chmod 755 "$TEST_ROOT/bin/cp"
CALCURSE_TEST_COPY_FAIL=true CALCURSE_TEST_RECOVERY_NOTES=true TEST_ROOT=$TEST_ROOT \
  "$LAUNCHER" >"$TEST_ROOT/recovery.out" 2>"$TEST_ROOT/recovery.err"
recovery_session=$(<"$TEST_ROOT/recovery-session.path")
grep -Fq 'keeping recovery session:' "$TEST_ROOT/recovery.err"
[[ $(wc -l <"$TEST_ROOT/copy-fail.log") -eq 1 ]]
for note_hash in 1111111111111111111111111111111111111111 2222222222222222222222222222222222222222; do
  [[ -f "$recovery_session/notes/$note_hash" ]]
done

# A failed stale-session recovery must also keep the session; a later retry recovers both notes.
CALCURSE_TEST_COPY_FAIL=true TEST_ROOT=$TEST_ROOT "$LAUNCHER" --refresh \
  >"$TEST_ROOT/retry.out" 2>"$TEST_ROOT/retry.err"
grep -Fq 'keeping recovery session:' "$TEST_ROOT/retry.err"
[[ -d "$recovery_session" ]]
[[ $(wc -l <"$TEST_ROOT/copy-fail.log") -eq 2 ]]
TEST_ROOT=$TEST_ROOT "$LAUNCHER" --refresh >"$TEST_ROOT/recovered.out"
[[ ! -e "$recovery_session" ]]
for note_hash in 1111111111111111111111111111111111111111 2222222222222222222222222222222222222222; do
  grep -Fxq "Recovery note $note_hash" "$XDG_DATA_HOME/calcurse/notes/$note_hash"
done
