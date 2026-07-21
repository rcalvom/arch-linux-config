# Redshift on Qtile/X11

This documents the automatic color-temperature setup used by the existing
Qtile/X11 fallback session. The active desktop profile uses Hyprland and
`hyprsunset`; do not run Redshift and Hyprsunset at the same time.

## Behavior

Redshift keeps the display at 6500 K during the day and 3000 K at night. It
does not change the physical backlight brightness. Location comes from GeoClue,
which estimates it from network data rather than from a manually maintained
latitude and longitude.

## Prerequisites

Install the official packages:

```sh
sudo pacman -S --needed redshift geoclue
```

Authorize the local Redshift process in `/etc/geoclue/geoclue.conf`. Replace
`<uid>` with the numeric result of `id -u` for the intended desktop user:

```ini
[redshift]
allowed=true
system=false
users=<uid>
```

Restart GeoClue after changing its configuration:

```sh
sudo systemctl restart geoclue.service
```

## Redshift Configuration

Create `~/.config/redshift/redshift.conf`:

```ini
[redshift]
temp-day=6500
temp-night=4000
transition=1
location-provider=geoclue2
adjustment-method=randr
```

`randr` is appropriate for the Qtile/X11 session. Redshift does not support
Wayland, so Hyprland should use `hyprsunset` instead.

## GeoClue Agent

GNOME starts a GeoClue authorization agent itself. Qtile does not, so run the
agent provided by the `geoclue` package as a user service. Create
`~/.config/systemd/user/geoclue-agent.service`:

```ini
[Unit]
Description=GeoClue authorization agent
Before=redshift.service

[Service]
ExecStart=/usr/lib/geoclue-2.0/demos/agent
Restart=on-failure

[Install]
WantedBy=redshift.service
```

Enable the agent and Redshift:

```sh
systemctl --user daemon-reload
systemctl --user enable geoclue-agent.service
systemctl --user enable --now redshift.service
```

No reboot is required. The Qtile configuration imports `DISPLAY` and
`XAUTHORITY` into the user systemd environment, allowing the service to use
RandR immediately and at subsequent logins.

## Verification

Check both user services:

```sh
systemctl --user status geoclue-agent.service redshift.service
```

Confirm that GeoClue returned a location without changing the display:

```sh
redshift -c "$HOME/.config/redshift/redshift.conf" -p -v
```

The output should include `Location:` and show 3000 K during the night period.
For failures, inspect the service logs:

```sh
journalctl --user-unit geoclue-agent.service --user-unit redshift.service -b
```

## Privacy

GeoClue network providers can use the public IP address and nearby Wi-Fi data.
This is used to estimate a location. Review `/etc/geoclue/geoclue.conf` before
enabling it on a system where that is not acceptable.

To disable the setup and reset the X11 color ramp:

```sh
systemctl --user disable --now redshift.service geoclue-agent.service
redshift -x
```
