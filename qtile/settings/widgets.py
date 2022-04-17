"""Qtile widgets configuration"""

# Qtile
from libqtile import widget

# Configuration
from .theme import colors


def base(fg='text', bg='dark'):
    return {
        'foreground': colors[fg],
        'background': colors[bg]
    }


def icon(fg='text', bg='dark', fontsize=16, text="?"):
    return widget.TextBox(
        **base(fg, bg),
        fontsize=fontsize,
        text=text,
        padding=3
    )


def powerline(fg="light", bg="dark"):
    return widget.TextBox(
        **base(fg, bg),
        text="",
        fontsize=37,
        padding=-3
    )


def workspaces():
    return [
        widget.GroupBox(
            **base(fg='light'),
            font='UbuntuMono Nerd Font',
            fontsize=19,
            margin_y=3,
            margin_x=0,
            padding_y=8,
            padding_x=10,
            borderwidth=1,
            active=colors['active'],
            inactive=colors['inactive'],
            rounded=False,
            highlight_method='block',
            urgent_alert_method='block',
            urgent_border=colors['urgent'],
            this_current_screen_border=colors['focus'],
            this_screen_border=colors['grey'],
            other_current_screen_border=colors['dark'],
            other_screen_border=colors['dark'],
            disable_drag=True
        ),
        widget.Sep(
            **base(), 
            linewidth=0, 
            padding=30
        ),
        widget.WindowName(**base(fg='focus'), fontsize=14, padding=5),
        widget.Sep(
            **base(), 
            linewidth=0, 
            padding=10
        ),
    ]


primary_widgets = [
    *workspaces(),
    widget.Sep(
       **base(),
       linewidth=0, 
       padding=10
    ),

    powerline('color4', 'dark'),
    icon(bg="color4", text='墳 '),
    widget.PulseVolume(
        background=colors['color4'],
        update_interval=0.1,
        step=10,
        limit_max_volume=True,
        volume_app="pamixer"
    ),
    powerline('color4', 'dark'),
    icon(bg="color4", text='﬙ '),
    widget.CPU(
        background=colors['color4'],
        format='{load_percent}%'
    ),

    powerline('color4', 'dark'),
    icon(bg="color4", text=' '),
    widget.Memory(
        background=colors['color4'],
        format='{MemUsed:.0f} {mm}'
    ),

    powerline('color3', 'color4'),
    icon(bg="color3", text=' '),  # 
    widget.Net(
        **base(bg='color3'), 
        interface='enp63s0',
        format='{down} ↓↑ {up}'
    ),
    powerline('color2', 'color3'),
    widget.CurrentLayoutIcon(**base(bg='color2'), scale=0.65),
    widget.CurrentLayout(**base(bg='color2'), padding=5),
    powerline('color1', 'color2'),
    icon(bg="color1", fontsize=17, text=' '),  # Icon: nf-mdi-calendar_clock
    widget.Clock(**base(bg='color1'), format='%d/%m/%Y - %I:%M %p'),
    powerline('dark', 'color1'),
    widget.Systray(background=colors['dark'], padding=5),
]

secondary_widgets = [
    *workspaces(),
    widget.Sep(
        **base(), 
        linewidth=0, 
        padding=10
    ),
    powerline('color1', 'dark'),
    widget.CurrentLayoutIcon(**base(bg='color1'), scale=0.65),
    widget.CurrentLayout(**base(bg='color1'), padding=5),
    powerline('color2', 'color1'),
    widget.Clock(**base(bg='color2'), format='%d/%m/%Y - %I:%M %p'),
    powerline('dark', 'color2'),
]

widget_defaults = {
    'font': 'UbuntuMono Nerd Font Bold',
    'fontsize': 14,
    'padding': 1,
}

extension_defaults = widget_defaults.copy()
