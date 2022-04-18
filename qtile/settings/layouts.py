"""Qtile layouts"""

# Qtile
from libqtile import layout
from libqtile.config import Match

# Configuration
from .theme import theme

# Group's layouts
layouts = [
    layout.MonadTall(
        border_focus=theme['colors']['focus'],
        border_width=theme['layouts']['border_width'],
        margin=theme['layouts']['margin']
    ),
    layout.Max(),
    layout.Matrix(
        columns=theme['layouts']['columns'],
        border_focus=theme['colors']['focus'],
        border_width=theme['layouts']['border_width'],
        margin=theme['layouts']['margin']
    ),
    layout.Zoomy(
        margin=theme['layouts']['margin']
    ),
]

# Floating Layout, for floating windows
floating_layout = layout.Floating(
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class='confirmreset'),
        Match(wm_class='makebranch'),
        Match(wm_class='maketag'),
        Match(wm_class='ssh-askpass'),
        Match(title='branchdialog'),
        Match(title='pinentry'),
    ],
    border_focus=theme['colors']['focus']
)
