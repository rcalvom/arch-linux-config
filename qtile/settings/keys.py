"""Qtile key configuration"""

# Qtile
from libqtile.config import Key
from libqtile.command import lazy

# Configuration
from .path import user_path

# Reference to Windows key
mod = 'mod4'

# Reference to Alt key
alt = 'mod1'

# Reference to Shift key
shift = 'shift'

# Reference to Control key
control = 'control'

# List of Keybinds
keys = [
    # Switch focus between windows in current stack pane
    Key([alt], 'Tab', lazy.layout.down(), desc='Change to next window'),
    Key([alt, shift], 'Tab', lazy.layout.up(),
        desc='Change to previous window'),

    # Change window sizes (MonadTall)
    Key([alt], 'Up', lazy.layout.grow(), desc='Grow current window'),
    Key([alt], 'Down', lazy.layout.shrink(), desc='Shrink current window'),

    # Toggle floating
    Key([alt], 'f', lazy.window.toggle_floating(),
        desc='Toggle floating window'),

    # Move windows up or down in current stack
    Key([alt, shift], 'Up', lazy.layout.shuffle_up(), desc='Move window up'),
    Key([alt, shift], 'Down', lazy.layout.shuffle_down(), desc='Move window up'),

    # Toggle between different layouts as defined below
    Key([mod], 'Tab', lazy.next_layout(), desc='Next layout'),
    Key([mod, shift], 'Tab', lazy.prev_layout(), desc='Previous layout'),

    # Kill window
    Key([mod], 'w', lazy.window.kill(), desc='Close window'),
    Key([alt], 'F4', lazy.window.kill(), desc='Close window'),

    # Switch focus of monitors
    Key([mod], 'period', lazy.next_screen(), desc='Focus next screen'),
    Key([mod], 'comma', lazy.prev_screen(), desc='Focus previous screen'),

    # Logout Qtile
    Key([mod], 'l', lazy.shutdown(), desc='Log out'),

    # Restart Qtile
    Key([mod, shift], "l", lazy.restart(), desc='Reload Qtile'),

    # Menu
    Key([mod], "m", lazy.spawn("rofi -show drun"), desc='Open menu'),

    # Browser
    Key([mod], "b", lazy.spawn("firefox"), desc='Open browser'),

    # Terminal
    Key([mod], "Return", lazy.spawn("alacritty"), desc='Open terminal'),

    # File explorer
    Key([mod], "e", lazy.spawn("alacritty -e ranger"), desc='Open file explorer'),

    # Redshift
    Key([mod], "r", lazy.spawn("redshift -O 4500"),
        desc='Apply night screen filter'),
    Key([mod, shift], "r", lazy.spawn("redshift -x"),
        desc='Remove night screen filter'),

    # Volume Control
    Key([], "XF86AudioRaiseVolume", lazy.spawn(
        "pamixer --increase 10"), desc='Increace volumne'),
    Key([], "XF86AudioLowerVolume", lazy.spawn(
        "pamixer --decrease 10"), desc='Decreace volumne'),
    Key([], "XF86AudioMute", lazy.spawn(
        "pamixer --toggle-mute"), desc='Toggle mute volumne'),

    # Brightness
    Key([], "XF86MonBrightnessUp", lazy.spawn(
        "brightnessctl set +10%"), desc='Increace brightness'),
    Key([], "XF86MonBrightnessDown", lazy.spawn(
        "brightnessctl set 10%-"), desc='Decreace brightness'),

    # Screenshot
    Key([], "Print", lazy.spawn(
        'maim --format png --quality 5 --hidecursor {0}/Pictures/screenshots/screenshot_"$(date +%Y-%M-%d_%H-%m-%S)".png'.format(user_path), shell=True), desc='Save a screenshot'),
    Key([control], "Print", lazy.spawn(
        'maim --format png --quality 5 --hidecursor | xclip -selection clipboard -t image/png', shell=True), desc='Copy to clipboard a screenshot'),
    Key([shift], "Print", lazy.spawn(
        'maim --select --format png --quality 5 --hidecursor {0}/Pictures/screenshots/screenshot_"$(date +%Y-%M-%d_%H-%m-%S)".png'.format(user_path), shell=True), desc='Save a snip'),
    Key([control, shift], "Print", lazy.spawn(
        "maim --select --format png --quality 5 --hidecursor | xclip -selection clipboard -t image/png", shell=True), desc='Copy to clipboard a snip'),
]
