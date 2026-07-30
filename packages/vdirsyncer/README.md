# Google Calendar Mirror

`archcfg-vdirsyncer-setup` creates a private Vdirsyncer configuration from a Google Desktop OAuth client JSON file. The generated config and OAuth refresh token stay outside the repository.

After deployment, initialize the mirror once:

```bash
archcfg-vdirsyncer-setup /path/to/client_secret.json
vdirsyncer discover
vdirsyncer sync
vdirsyncer metasync
```

Select every Google calendar to mirror at <https://calendar.google.com/calendar/syncselect>. The remote storage is configured as read-only, so local changes are reverted rather than uploaded. `archcfg-calcurse-google` imports every discovered local collection into its separate read-only Calcurse view.
