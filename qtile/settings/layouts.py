"""Qtile layouts"""

# Qtile
from libqtile import layout
from libqtile.config import Match

# Configuration
from .theme import colors

# Group's layouts
layouts = [
    layout.MonadTall(
        border_focus=colors['focus'][0],
        border_width=2,
        margin=5
    ),
    layout.Max(),
    layout.Matrix(
        columns=2,
        border_focus=colors['focus'][0],
        border_width=2,
        margin=5
    ),
    layout.Zoomy(
        margin=5
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
    border_focus=colors["color4"][0]
)
