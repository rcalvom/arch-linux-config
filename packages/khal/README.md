# Google Calendar View

`archcfg-google-calendar` refreshes the local Vdirsyncer mirror and opens it with Khal. The Khal configuration is read-only, so Google Calendar remains the source of truth.

Khal frames are disabled while Arch ships Khal 0.14.0 with Urwid 4 because that combination crashes when creating a frame. Restore `frame = color` in `config` after Arch packages the upstream fix from <https://github.com/pimutils/khal/pull/1475>.
