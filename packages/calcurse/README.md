# Calcurse

`calcurse` uses the local data directory for TODOs, notes, and local events.

`archcfg-calcurse-google` synchronizes the Google Calendar Vdirsyncer mirror, builds a separate Calcurse profile from every discovered `.ics` collection, and opens a temporary copy read-only. `SUPER+C` launches this Google view; run `calcurse` directly for local data.

To add a Google calendar, enable it at <https://calendar.google.com/calendar/syncselect>, then run:

```bash
vdirsyncer discover
vdirsyncer sync
```

The next `SUPER+C` includes every discovered collection automatically. The Google view never writes data back to Google. It is a best-effort Calcurse projection: Vdirsyncer remains the source of truth for iCalendar properties Calcurse does not support.
