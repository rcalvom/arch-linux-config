"""Qtile multimonitor support"""

# Qtile
from libqtile.config import Screen
from libqtile import bar
from libqtile.log_utils import logger

# System
import subprocess

# Configuration
from .widgets import primary_widgets, secondary_widgets


def status_bar(widgets):
    return bar.Bar(widgets, 28, opacity=0.92)


screens = [
    Screen(
        top=status_bar(primary_widgets), 
        wallpaper='~/Pictures/wallpaper.png', 
        wallpaper_mode='fill'
    )
]

xrandr = "xrandr | grep -w 'connected' | cut -d ' ' -f 2 | wc -l"

command = subprocess.run(
    xrandr,
    shell=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)

if command.returncode != 0:
    error = command.stderr.decode("UTF-8")
    logger.error("Failed counting monitors using {0}:\n{1}".format(xrandr, error))
    connected_monitors = 1
else:
    connected_monitors = int(command.stdout.decode("UTF-8"))

if connected_monitors > 1:
    for _ in range(1, connected_monitors):
        screens.append(
            Screen(
                top=status_bar(secondary_widgets)
            )
        )
