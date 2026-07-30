"""Qtile multimonitor support"""

# Qtile
from libqtile.config import Screen
from libqtile import bar
from libqtile.log_utils import logger

# System
import subprocess

# Configuration
from .widgets import primary_widgets, secondary_widgets
from .theme import theme
from .path import user_path


def status_bar(widgets):
    """Create a status bar"""
    return bar.Bar(
        widgets,
        size=theme['status_bar']['height'],
        opacity=theme['status_bar']['opacity']
    )


# List of Screens
screens = [
    Screen(
        top=status_bar(primary_widgets),
        wallpaper='{0}/Pictures/wallpaper.png'.format(user_path),
        wallpaper_mode='fill'
    )
]


# Command to detect multiple screens
xrandr = "xrandr | grep -w 'connected' | cut -d ' ' -f 2 | wc -l"


# Command execution
command = subprocess.run(
    xrandr,
    shell=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)


# Check the existence of multiple monitors
if command.returncode != 0:
    error = command.stderr.decode("UTF-8")
    logger.error(
        "Failed counting monitors using {0}:\n{1}".format(xrandr, error))
    connected_monitors = 1
else:
    connected_monitors = int(command.stdout.decode("UTF-8"))


# If multiple monitors avalaible, set the status bar
if connected_monitors > 1:
    for _ in range(1, connected_monitors):
        screens.append(
            Screen(
                top=status_bar(secondary_widgets)
            )
        )
