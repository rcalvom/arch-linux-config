"""Qtile workspaces"""

# Qtile
from libqtile.config import Key, Group
from libqtile.command import lazy

# Configuration
from .keys import alt, keys

# List of Groups in the layout
groups = [
    Group(name="Console", label="   "),
    Group(name="Firefox", label="   "),
    Group(name="Development", label="   "),
    Group(name="File explorer", label="   "),
    Group(name="Messages", label="   "),
    Group(name="Entertainment", label=" 磊  "),
    Group(name="Others", label="   ")
]

# Add Keybinds for toggle groups and send tiles to other group
for i, group in enumerate(groups):
    actual_key = str(i + 1)
    keys.extend([
        Key([alt], actual_key, lazy.group[group.name].toscreen()),
        Key([alt, "control"], actual_key, lazy.window.togroup(group.name))
    ])
