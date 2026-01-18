"""Qtile main configuration"""

# Configuration
from settings.keys import mod, keys
from settings.groups import groups
from settings.layouts import layouts, floating_layout
from settings.widgets import widget_defaults, extension_defaults
from settings.screens import screens
from settings.mouse import mouse

follow_mouse_focus = False
bring_front_click = True
focus_on_window_activation = 'never'