# Calcurse

`calcurse` uses the local data directory for TODOs, notes, and local events.

The normal configuration uses a five-minute warning for flagged local appointments. Its generic `notify-send` message directs you to the running Calcurse session for details; it never queries `calcurse --next` or invokes the Google helper. With periodic saving disabled, the on-disk calendar may differ from the running session, so querying it could show the wrong appointment. These notifications require local Calcurse to be running; the Google daemon does not monitor local appointments.

`archcfg-calcurse-google` synchronizes the Google Calendar Vdirsyncer mirror, builds a separate Calcurse profile from every discovered `.ics` collection, and opens a temporary calendar session. `SUPER+C` launches this Google view; its TODO list is linked to the normal local Calcurse data, so tasks and their notes persist and remain available when running `calcurse` directly.

Google appointments remain disposable projections: appointment changes made in this combined view are discarded when it closes and are never uploaded. Use Google Calendar to modify synchronized events.

After synchronization, the launcher fingerprints the names and contents of the mirrored `.ics` files. It reuses the last verified Calcurse generation when that fingerprint is unchanged, avoiding a full import on routine launches. A changed mirror is rebuilt atomically, while synchronization, fingerprinting, import, or validation failures keep the last verified generation available.

The reminder daemon reads the complete generated appointment database. A user timer runs `archcfg-calcurse-google --refresh` every five minutes and restarts the daemon, which uses a 15-minute warning window and `notify-send`. The helper queries only the next appointment with `calcurse --next`: simultaneous appointments can be omitted, and appointments less than 15 minutes apart may be announced late. This is best-effort notification, not a guarantee of an advance reminder for every appointment. A persistent hash suppresses repeats of the last notified occurrence after a restart or login. Mako keeps calendar reminders visible until they are dismissed with a left click.

The launcher generates a separate `conf` in the `archcfg/calcurse-google-reminders` data directory, inheriting local display settings but replacing notification settings with the Google helper, all appointments, and a 900-second warning. It refreshes this configuration even when the appointment cache is reused or synchronization fails. Both the daemon and disposable Google sessions use this configuration, never the local notification command. Existing installations need the updated local configuration, launcher, helper, and service unit applied together, followed by a refresh and daemon restart; changing repository files alone does not update a running daemon.

Google and imported Outlook calendars do not consistently expose inherited reminder settings as `VALARM`, and Calcurse does not retain the original trigger offset. The reminder profile therefore applies a fixed 15-minute warning setting to timed appointments, subject to the next-appointment limitations above. All-day events and local TODOs have no timed Calcurse appointment and do not trigger this daemon.

The interactive launch presents a colored `📅 Calendar Sync` heading with concise `↻ Syncing calendars...`, optional `• Updating calendar view...`, and `✓ Calendar ready.` status messages. Colors are enabled only on a terminal. Routine Vdirsyncer output is hidden; actionable failures still report that the last verified view will be opened.

To add a Google calendar, enable it at <https://calendar.google.com/calendar/syncselect>, then run:

```bash
vdirsyncer discover
vdirsyncer sync
```

The next `SUPER+C` includes every discovered collection automatically. The Google view never writes data back to Google. It is a best-effort Calcurse projection: Vdirsyncer remains the source of truth for iCalendar properties Calcurse does not support.

On a fresh installation, automatic refresh is skipped until the Vdirsyncer configuration exists in the user's XDG configuration directory. Credentials are not restored by this repository. Once configured, the helper retains its existing error handling and verified-cache fallback; the condition does not override its exit status.

Check the automatic refresh and reminder daemon with:

```bash
systemctl --user status archcfg-calcurse-google-refresh.timer
systemctl --user status archcfg-calcurse-google-reminder.service
```
