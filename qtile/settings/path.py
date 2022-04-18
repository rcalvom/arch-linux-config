"""Qtile Path provider"""

# System
from os import path


# User folder path
user_path = path.join(path.expanduser('~'))

# Qtile config path
qtile_path = path.join(path.expanduser('~'), ".config", "qtile")
