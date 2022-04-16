"""Qtile key configuration"""

# Qtile
from libqtile.config import Key
from libqtile.command import lazy

# Reference to Windows key
windows_key = "mod4"

# Reference to Alt key
alt = "mod1"

# Reference to Shift key
shift = "shift"

# Reference to Control key
control = "control"

# List of Keybinds
keys = [

    # Switch focus between windows in current stack pane
    Key([alt], "Tab", lazy.layout.up()),
    Key([alt, shift], "Tab", lazy.layout.down()),

    # Change window sizes (MonadTall)
    Key([alt], "Up", lazy.layout.grow()),
    Key([alt], "Down", lazy.layout.shrink()),

    # Toggle floating
    Key([alt], "f", lazy.window.toggle_floating()),

    # Move windows up or down in current stack
    Key([alt, shift], "Up", lazy.layout.shuffle_up()),
    Key([alt, shift], "Down", lazy.layout.shuffle_down()),

    # Toggle between different layouts as defined below
    Key([windows_key], "Tab", lazy.next_layout()),
    Key([windows_key, shift], "Tab", lazy.prev_layout()),

    # Kill window
    Key([windows_key], "w", lazy.window.kill()),
    Key([alt], "F4", lazy.window.kill()),

    # Switch focus of monitors
    Key([windows_key], "period", lazy.next_screen()),
    Key([windows_key], "comma", lazy.prev_screen()),

    # Restart Qtile
    Key([windows_key], "l", lazy.shutdown()),

    # Menu
    Key([windows_key], "r", lazy.spawn("rofi -show drun")),

    # Window Nav
    Key([windows_key, shift], "m", lazy.spawn("rofi -show")),

    # Browser
    Key([windows_key], "b", lazy.spawn("firefox")),

    # Terminal
    Key([windows_key], "Return", lazy.spawn("alacritty")),

    # Redshift
    Key([windows_key], "r", lazy.spawn("redshift -O 4500")),
    Key([windows_key, shift], "r", lazy.spawn("redshift -x")),

    # Screenshot
    Key([], "Print", lazy.spawn("maim --format png --quality 1 --hidecursor ~/Pictures/screenshots/screenshot_\"$(date +%Y-%M-%d_%H-%m-%S)\".png")),
    Key([control], "Print", lazy.spawn("maim --format png --quality 1 --hidecursor | xclip -selection clipboard -t image/png")),
    Key([shift], "Print", lazy.spawn("maim --select --format png --quality 1 --hidecursor ~/Pictures/screenshots/screenshot_\"$(date +%Y-%M-%d_%H-%m-%S)\".png")),
    Key([control, shift], "Print", lazy.spawn("maim --select --format png --quality 1 --hidecursor | xclip -selection clipboard -t image/png"))
]
