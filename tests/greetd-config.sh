#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
CONFIG="$REPO_DIR/greetd/config.toml"

grep -Fq -- '--remember' "$CONFIG"
if grep -Fq -- '--user-menu' "$CONFIG"; then
  printf 'test failure: tuigreet 0.11 starts duplicate sessions with --remember and --user-menu\n' >&2
  exit 1
fi

python3 - "$CONFIG" <<'PY'
import datetime
import locale
import shlex
import sys
import tomllib
from pathlib import Path

with open(sys.argv[1], "rb") as source:
    config = tomllib.load(source)
assert config["terminal"] == {"vt": 1}
assert config["default_session"]["user"] == "greeter"
args = shlex.split(config["default_session"]["command"])
assert args.pop(0) == "tuigreet"
switches = {"--time", "--remember", "--remember-session", "--asterisks"}
options = {}
while args:
    key = args.pop(0)
    assert key not in options, key
    options[key] = True if key in switches else args.pop(0)
assert options == {
    **dict.fromkeys(switches, True),
    "--time-format": "%A, %B %d, %Y - %I:%M %p",
    "--greeting": "Sign in to your session",
    "--theme": "border=blue;text=white;prompt=green;time=white;action=white;button=blue;container=black;input=white;greet=lightcyan;title=lightcyan",
    "--width": "60",
    "--window-padding": "2",
    "--container-padding": "2",
    "--prompt-padding": "1",
    "--greet-align": "center",
    "--sessions": "/usr/share/wayland-sessions",
    "--xsessions": "/usr/share/xsessions",
    "--session-wrapper": "/usr/local/libexec/archcfg-wayland-session-wrapper",
    "--xsession-wrapper": "/usr/local/libexec/archcfg-xsession-wrapper",
    "--cmd": "Hyprland",
}
locale.setlocale(locale.LC_TIME, "C")
for day in range(366):
    date = datetime.datetime(2028, 1, 1, 23, 59) + datetime.timedelta(days=day)
    assert len(date.strftime(options["--time-format"])) < 85
greetd = Path(sys.argv[1]).parent
palette = greetd.joinpath("vtrgb").read_text().splitlines()
assert len(palette) == 16
assert all(len(color) == 7 and color.startswith("#") for color in palette)
assert all(0 <= int(color[1:], 16) <= 0xFFFFFF for color in palette)
assert palette[4] == "#033e8c"
assert palette[2] == "#10a778"
assert palette[14] == "#4fb8cc"
assert palette[15] == "#f1f1f1"
assert greetd.joinpath("vconsole.conf").read_text() == "KEYMAP=la-latin1\nFONT=ter-v28b\n"
print("Greeter theme, console and session configuration checks passed.")
PY
