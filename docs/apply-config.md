# Apply User Configuration

`apply-config.sh` deploys repository configuration into the invoking user's
`HOME`. It does not install packages, use sudo, change system configuration,
initialize browser profiles, or enable/reload/restart services. Root and sudo
invocations are rejected. Run it only for the account whose files you intend
to configure.

```bash
bash apply-config.sh                         # Desktop plan; no writes
bash apply-config.sh --module alacritty      # One package's configuration
bash apply-config.sh --module desktop --module nvim --dry-run
bash apply-config.sh --module all --apply
bash apply-config.sh --hardware-profile ricardo  # Personal display plan, opt-in
```

The default module is `desktop`, using `wayland/files.conf`. Other module names
are directory names with `packages/NAME/files.conf`; `all` includes both. These
are configuration selections, not package installation profiles. Existing
four-column `user_file` and `user_tree` manifests remain supported; tree entries
exclude files named `files.conf`. System entries are explicitly skipped. Missing
sources, malformed entries and duplicate destinations fail before file deployment.

`--hardware-profile ricardo` adds `hardware/ricardo/files.conf`; the default is
`none`. Neither `desktop` nor `all` imposes personal monitor layouts. The same
option is accepted by the desktop installer and uses the same manifest.
Existing Cliamp provider configuration is preserved by default; `--replace`
backs up then replaces whole files, so review its plan rather than expecting a merge.

## Preservation And Backups

Identical content and permissions are left untouched. Missing files are created
only with `--apply`. Differing existing files, including permission-only changes,
are reported as `PRESERVE` and left untouched, even when rerunning after repository
updates. Files outside the mappings are never pruned. To replace differences:

```bash
bash apply-config.sh --module alacritty --replace --dry-run
bash apply-config.sh --module alacritty --replace --apply
```

Each writing run prints a `run.ID` backup identifier. Private backups reside at
`~/.local/state/archcfg-deploy/run.ID` and retain original content, permission bits,
original absence and the deployed content/mode fingerprint. No-op runs create no
backup. Dry runs create neither directories nor lock files. Explicit apply runs
may create the state directory and lock even when no configuration changes.

```bash
bash apply-config.sh --rollback run.ID          # Preview restoration
bash apply-config.sh --rollback run.ID --apply  # Restore files or original absence
```

Rollback validates the whole backup and all current destinations first. If any
file's content or permissions changed since deployment (including deletion), it
aborts rather than overwriting subsequent work. Restore newer overlapping runs
first. Backups are retained after rollback, but completed rollbacks cannot be
repeated. Do not edit or move backup records between homes.

## Safety Limits

- Source and destination symlinks, including parent symlinks, are rejected.
- Source files may belong to the invoking user or root (the installed repository
  under `/opt`); destination and backup files must still belong to the user.
- Special files, hard-linked destinations and path traversal are rejected.
- `HOME` must be an existing, owned, absolute directory without symlink components.
  For isolated trials, set `HOME` to a temporary directory you own.
- Mappings use paths relative to `HOME`; custom XDG directory overrides are not used.
- Backups restore regular-file content and permission bits, not ACLs, extended
  attributes or directory metadata. Newly created directories remain after rollback.
- A lock serializes this tool, not editors or applications. Stop applications that
  write selected files while applying or rolling back. This is not a security
  boundary against concurrent filesystem mutation by another process.
- There is no automatic transaction rollback on I/O failure or interruption. The
  journal is written before each destination; inspect the backup after a failed
  run. A partially written or not-yet-written file can require manual recovery
  because conservative rollback rejects fingerprint mismatches.

## Deployment Contexts

Fresh installation, live initialization, verification and user apply share the
desktop mapping, including `hypr-share-picker`, `waybar.service` and portal
overrides. Package manifests remain unchanged.

Fresh installation retains its shipped timer enablement. Live enables only the
Hyprsunset timers; calendar unit files are copied but its refresh timer is not
enabled because live has no calendar credentials. Live also retains its startup
terminal overlay and browser initialization. User apply only copies unit files;
it does not create timer enablement links or configure credentials.

After applying `all` into a clean home, use:

```bash
bash scripts/verify-dotfiles.sh --context user
```

The default verification context is `installed`, which also checks shipped timer
links. Verification checks the full mapping, not only modules selected for apply;
preserved differences are therefore expected to be reported. MIME associations
remain local-state warnings. Live's intentional Hyprland overlay differs from the
source and is not a byte-identical verification target.

## Tests

```bash
bash tests/apply-config.sh
bash tests/apply-config-integration.sh
bash tests/deploy-mappings.sh
```

Tests use temporary homes and mocks; they do not install packages or control host
services. Full installed/live session behavior still requires a disposable VM.

For a script-only VM trial, use an existing ISO only to bootstrap the guest,
transfer a checksum-verified snapshot of the current source, and run these tests
as an unprivileged guest user with temporary homes. This validates the transferred
script, not the ISO's bundled source or an installation/desktop session. Battery
system deployment is separate: `scripts/apply-charge-limits.sh` requires root and
must only be exercised in an explicitly disposable guest for this trial. Without
physical charge-control interfaces, that trial proves timer deployment and the
hardware no-op path, not battery thresholds or suspend behavior.
