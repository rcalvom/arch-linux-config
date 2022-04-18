"""Qtile widgets configuration"""

# Qtile
from libqtile import widget

# Configuration
from .theme import theme


def icon(foreground='text', background='dark', fontsize=16, text="?"):
    return widget.TextBox(
        foreground=theme['colors'][foreground],
        background=theme['colors'][background],
        fontsize=fontsize,
        text=text,
        padding=3
    )


def powerline(foreground="light", background="dark"):
    return widget.TextBox(
        foreground=theme['colors'][foreground],
        background=theme['colors'][background],
        text="",
        fontsize=37,
        padding=-3
    )


def workspaces():
    return [
        widget.GroupBox(
            foreground=theme['colors']['light'],
            background=theme['colors']['dark'],
            font='UbuntuMono Nerd Font',
            fontsize=19,
            margin_y=3,
            margin_x=0,
            padding_y=8,
            padding_x=10,
            active=theme['colors']['active'],
            inactive=theme['colors']['inactive'],
            rounded=False,
            highlight_method='block',
            urgent_alert_method='block',
            urgent_border=theme['colors']['urgent'],
            this_current_screen_border=theme['colors']['focus'],
            this_screen_border=theme['colors']['grey'],
            other_current_screen_border=theme['colors']['dark'],
            other_screen_border=theme['colors']['dark'],
            disable_drag=True
        ),
        widget.Sep(
            foreground=theme['colors']['dark'],
            background=theme['colors']['dark'],
            linewidth=0,
            padding=50
        ),
        widget.WindowName(
            foreground=theme['colors']['light'],
            background=theme['colors']['dark'],
            fontsize=14,
            padding=0
        ),
        widget.Sep(
            foreground=theme['colors']['dark'],
            background=theme['colors']['dark'],
            linewidth=0,
            padding=50
        )
    ]


primary_widgets = [
    *workspaces(),
    widget.PulseVolume(
        background=theme['colors']['color1'],
        update_interval=0.1,
        step=10,
        limit_max_volume=True,
        volume_app="pamixer",
        fmt='墳 {}',
        padding=10
    ),
    widget.CPU(
        background=theme['colors']['color1'],
        format='﬙ {load_percent}%',
        padding=10
    ),
    widget.Memory(
        background=theme['colors']['color1'],
        format=' {MemUsed:.0f}{mm}',
        padding=10
    ),
    widget.Net(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        interface='enp63s0',
        format='{down} ↓↑ {up}',
        padding=10
    ),
    widget.CurrentLayoutIcon(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        scale=0.4
    ),
    widget.CurrentLayout(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        padding=10
    ),
    widget.Clock(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        format='  %d/%m/%Y - %I:%M %p',
        padding=10
    ),
    widget.Systray(
        background=theme['colors']['dark'], 
        padding=10
    ),
]

secondary_widgets = [
    *workspaces(),
    widget.Sep(
        foreground=theme['colors']['text'],
        background=theme['colors']['dark'],
        linewidth=0,
        padding=10
    ),
    powerline('color1', 'dark'),
    widget.CurrentLayoutIcon(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        scale=0.65
    ),
    widget.CurrentLayout(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        padding=5
    ),
    powerline('color2', 'color1'),
    widget.Clock(
        foreground=theme['colors']['text'],
        background=theme['colors']['color2'],
        format='%d/%m/%Y - %I:%M %p'
    ),
    powerline('dark', 'color2'),
]

widget_defaults = theme['defaults']

extension_defaults = widget_defaults.copy()
