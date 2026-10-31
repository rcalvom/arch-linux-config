#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if ! command -v calcurse >/dev/null; then
    printf 'SKIP: calcurse is not installed.\n'
    exit 0
fi

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export LC_ALL=C
export TEST_ROOT
export PATH="$TEST_ROOT/bin:/usr/bin"

mkdir -p "$TEST_ROOT/bin" "$XDG_CONFIG_HOME/calcurse" "$XDG_DATA_HOME/calcurse"
cp "$REPO_DIR/packages/calcurse/conf" "$XDG_CONFIG_HOME/calcurse/conf"
touch "$XDG_DATA_HOME/calcurse/todo"
start=$(date -d '+5 minutes' '+%m/%d/%Y @ %H:%M')
end=$(date -d '+35 minutes' '+%m/%d/%Y @ %H:%M')
printf '%s -> %s !Local appointment\n' "$start" "$end" >"$XDG_DATA_HOME/calcurse/apts"

cat >"$TEST_ROOT/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TEST_ROOT/notification.log"
EOF
chmod 755 "$TEST_ROOT/bin/notify-send"

# Parse the shipped configuration without starting a UI or daemon.
calcurse --read-only -G >"$TEST_ROOT/config.out"
# Notification commands must not query stale on-disk data, even if Calcurse is available.
cat >"$TEST_ROOT/bin/calcurse" <<'EOF'
#!/usr/bin/env bash
touch "$TEST_ROOT/unexpected-query"
printf 'Stale appointment\n'
exit 1
EOF
chmod 755 "$TEST_ROOT/bin/calcurse"
command=$(sed -n 's/^notification.command=//p' "$XDG_CONFIG_HOME/calcurse/conf")
sh -c "$command"
grep -Fxq 'Local calendar' "$TEST_ROOT/notification.log"
grep -Fxq 'An appointment is coming up. Check your running Calcurse session for details.' "$TEST_ROOT/notification.log"
[[ ! -e "$TEST_ROOT/unexpected-query" ]]
[[ ! -e "$XDG_STATE_HOME/archcfg/calcurse-google-reminder.sha256" ]]
