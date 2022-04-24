"""Qtile widgets configuration"""

# Qtile
from libqtile import widget

# Configuration
from .theme import theme


def workspaces():
    """
    Create Widgets por Workspaces.
    Include:
        - Group buttons
        - Window Name
    """
    return [
        widget.GroupBox(
            foreground=theme['colors']['light'],
            background=theme['colors']['dark'],
            font=theme['widgets']['group_box']['font'],
            fontsize=theme['widgets']['group_box']['fontsize'],
            margin_y=theme['widgets']['group_box']['margin_y'],
            margin_x=theme['widgets']['group_box']['margin_x'],
            padding_y=theme['widgets']['group_box']['padding_y'],
            padding_x=theme['widgets']['group_box']['padding_x'],
            borderwidth=theme['widgets']['group_box']['borderwidth'],
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
            linewidth=theme['widgets']['separator']['linewidth'],
            padding=theme['widgets']['separator']['padding']
        ),
        widget.WindowName(
            foreground=theme['colors']['light'],
            background=theme['colors']['dark'],
            fontsize=theme['widgets']['window_name']['fontsize'],
            padding=theme['widgets']['window_name']['padding']
        ),
        widget.Sep(
            foreground=theme['colors']['dark'],
            background=theme['colors']['dark'],
            linewidth=theme['widgets']['separator']['linewidth'],
            padding=theme['widgets']['separator']['padding']
        )
    ]


primary_widgets = [
    *workspaces(),
    widget.PulseVolume(
        background=theme['colors']['color1'],
        update_interval=theme['widgets']['pulse_volume']['update_interval'],
        step=theme['widgets']['pulse_volume']['step'],
        limit_max_volume=theme['widgets']['pulse_volume']['limit_max_volume'],
        volume_app=theme['widgets']['pulse_volume']['volume_app'],
        fmt='墳 {}',
        padding=theme['widgets']['pulse_volume']['padding'],
    ),
    widget.Backlight(
        background=theme['colors']['color1'],
        backlight_name='intel_backlight',
        format='  {percent:2.0%}',
        padding=10
    ),
    widget.Battery(
        background=theme['colors']['color1'],
        battery=2,
        format=' {percent:2.0%}',
        padding=10
    ),
    widget.Clock(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        format='  %d/%m/%Y - %I:%M %p',
        padding=theme['widgets']['clock']['padding']
    ),
    widget.Systray(
        background=theme['colors']['dark'],
        padding=theme['widgets']['systray']['padding']
    ),
]

secondary_widgets = [
    *workspaces(),
    widget.Clock(
        foreground=theme['colors']['text'],
        background=theme['colors']['color1'],
        format='  %d/%m/%Y - %I:%M %p',
        padding=theme['widgets']['clock']['padding']
    ),
]

widget_defaults = theme['widgets']['defaults']

extension_defaults = widget_defaults.copy()
