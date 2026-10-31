#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
NOTIFIER="$REPO_DIR/packages/calcurse/archcfg-calcurse-google-notify"
grep -Fxq 'ConditionPathExists=%E/vdirsyncer/config' \
    "$REPO_DIR/packages/calcurse/systemd/archcfg-calcurse-google-refresh.service"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export PATH="$TEST_ROOT/bin:/usr/bin"
export TEST_ROOT

mkdir -p "$TEST_ROOT/bin" "$XDG_DATA_HOME/archcfg/calcurse-google-reminders"
touch "$XDG_DATA_HOME/archcfg/calcurse-google-reminders/apts"

cat >"$TEST_ROOT/bin/calcurse" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
profile="$XDG_DATA_HOME/archcfg/calcurse-google-reminders"
[[ $# -eq 5 && $1 == -D && $2 == "$profile" && $3 == -C && $4 == "$profile" && $5 == -n ]]
printf 'next appointment:\n   [00:15] %s\n' "${TEST_TITLE:-Research meeting}"
EOF

cat >"$TEST_ROOT/bin/date" <<'EOF'
#!/usr/bin/env bash
printf '1700000000\n'
EOF

cat >"$TEST_ROOT/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_ROOT/notifications.log"
EOF

chmod 755 "$TEST_ROOT/bin/calcurse" "$TEST_ROOT/bin/date" "$TEST_ROOT/bin/notify-send"

"$NOTIFIER"
"$NOTIFIER"
[[ $(wc -l <"$TEST_ROOT/notifications.log") -eq 1 ]]
grep -Fq 'Research meeting' "$TEST_ROOT/notifications.log"
grep -Fq 'Starts in 15 minutes.' "$TEST_ROOT/notifications.log"
grep -Fq -- '--expire-time=0' "$TEST_ROOT/notifications.log"

TEST_TITLE='Office hours' "$NOTIFIER"
[[ $(wc -l <"$TEST_ROOT/notifications.log") -eq 2 ]]
