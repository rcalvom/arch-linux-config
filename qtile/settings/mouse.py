"""Qtile mouse actions"""

# Qtile
from libqtile.config import Drag, Click
from libqtile.command import lazy

# Configuration
from .keys import windows_key

# Mouse Actions
mouse = [
    Drag([windows_key], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([windows_key], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([windows_key], "Button2", lazy.window.bring_to_front())
]