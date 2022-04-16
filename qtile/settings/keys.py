"""Qtile key configuration"""

# Qtile
from libqtile.config import Key
from libqtile.command import lazy

# Reference to Windows key
mod = "mod4"

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
    Key([mod], "Tab", lazy.next_layout()),
    Key([mod, shift], "Tab", lazy.prev_layout()),

    # Kill window
    Key([mod], "w", lazy.window.kill()),
    Key([alt], "F4", lazy.window.kill()),

    # Switch focus of monitors
    Key([mod], "period", lazy.next_screen()),
    Key([mod], "comma", lazy.prev_screen()),

    # Logout Qtile
    Key([mod], "l", lazy.shutdown()),

    # Restart Qtile
    Key([mod, shift], "l", lazy.restart()),

    # Menu
    Key([mod], "m", lazy.spawn("rofi -show drun")),

    # Window Nav
    Key([mod, shift], "m", lazy.spawn("rofi -show")),

    # Browser
    Key([mod], "b", lazy.spawn("firefox")),

    # Terminal
    Key([mod], "Return", lazy.spawn("alacritty")),

    # File explorer
    Key([mod], "e", lazy.spawn("ranger")),

    # Redshift
    Key([mod], "r", lazy.spawn("redshift -O 4500")),
    Key([mod, shift], "r", lazy.spawn("redshift -x")),

    # Volume Control
    Key([], "XF86AudioLowerVolume", lazy.spawn("pamixer --decrease 10")),
    Key([], "XF86AudioRaiseVolume", lazy.spawn("pamixer --increase 10")),
    Key([], "XF86AudioMute", lazy.spawn("pamixer --toggle-mute")),

    # Brightness
    Key([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +10%")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 10%-")),

    # Screenshot
    Key([], "Print", lazy.spawn('maim --format png --quality 5 --hidecursor /home/ricardo/Pictures/screenshots/screenshot_"$(date +%Y-%M-%d_%H-%m-%S)".png', shell=True)),
    Key([control], "Print", lazy.spawn('maim --format png --quality 5 --hidecursor | xclip -selection clipboard -t image/png', shell=True)),
    Key([shift], "Print", lazy.spawn('maim --select --format png --quality 5 --hidecursor /home/ricardo/Pictures/screenshots/screenshot_"$(date +%Y-%M-%d_%H-%m-%S)".png', shell=True)),
    Key([control, shift], "Print", lazy.spawn("maim --select --format png --quality 5 --hidecursor | xclip -selection clipboard -t image/png", shell=True)),
]
