"""Qtile theme loading"""

# System
from os import path
import json

# Configuration
from .path import qtile_path


def load_theme():
    """Load the theme corresponding to theme.json file"""

    theme_config_path = path.join(qtile_path, 'theme.json')
    try:
        with open(theme_config_path) as f:
            return json.load(f)
    except Exception as e:
        raise Exception(
            'Failed loading theme from "theme.json" file.', e)


if __name__ == 'settings.theme':
    theme = load_theme()
