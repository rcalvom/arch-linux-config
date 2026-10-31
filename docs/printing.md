# Printing

The optional printing helper supports a departmental CUPS spooler and PaperCut
Mobility Print release queues. Site addresses, account names, queue names and
release portals must be provisioned privately for the intended institution.

## Private Provisioning

`printing/printing.conf` is an intentionally empty template, not a working site
configuration. The default invocation fails before backups, file writes, service
changes or queue creation. No institutional account or endpoint is inferred from
the local login name, environment or historical configuration.

In a separately approved setup session, copy the template to a private location
outside this repository, restrict its permissions to `0600`, and fill every field
using trusted institutional instructions. For example, use
`~/.config/archcfg/printing.conf` inside a mode-`0700` directory. Then run:

```bash
sudo bash scripts/apply-printing.sh --config "$HOME/.config/archcfg/printing.conf" --user "$(id -un)"
```

The configuration is sourced as **root shell code**. Review it before execution;
do not use an untrusted file or a downloaded script. This command changes the
system; it is not a preview or a dry run.

| Field | Required private value |
| --- | --- |
| `ECN_CUPS_SERVER` | Departmental CUPS hostname, without a URL scheme or port |
| `ECN_CAREER_ACCOUNT` | Institutional printing account, separate from the local Linux user |
| `PAPERCUT_HOST` | Mobility Print hostname, without a URL scheme or port |
| `PAPERCUT_PORT` | Integer TCP port from 1 to 65535 |
| `PAPERCUT_QUEUES` | Space-separated Mobility Print queue names |

`--user` selects the local home receiving `~/.cups/client.conf`; it does not
change the institutional account. Supply another private configuration when
configuring another institutional account. Empty fields, angle-bracket
placeholders, malformed hostnames, accounts, ports and queues are rejected without
echoing their values. Dependencies must already be installed; the helper does not
install packages.

## Routing And Queues

Departmental printers may live on a network inaccessible from the client. Use
the approved spooler rather than copying a printer's private address. mDNS is
link-local and does not discover printers across subnet boundaries. The generated
client configuration has this shape; these placeholders are not usable values:

```text
ServerName <departmental-cups-host>
User <institutional-account>
```

The spooler supplies departmental drivers and queue options. PaperCut uses local
IPP Everywhere queues pointing to the privately configured host, port and queue
path. Confirm supported protocols, transport security, release procedure and job
retention with the institution; this helper currently uses `ipp://`.

After provisioning, replace the placeholders in these examples:

```bash
lp -d <departmental-queue> file.pdf
lpoptions -p <departmental-queue> -l
lp -d <release-queue> file.pdf
lpstat -p <queue>
```

Set an optional default privately in `~/.cups/lpoptions`:

```text
Default <departmental-queue>
```

`ServerName` redirects every CUPS client command for that user, including
`lpadmin`. To administer a local queue, explicitly use the local UNIX socket:

```bash
sudo CUPS_SERVER=/run/cups/cups.sock lpadmin -p <queue> ...
```

Using `-h localhost` selects TCP instead and can trigger a different CUPS
authentication policy.

## Changes And Backups

After configuration validation, the helper:

1. Backs up and extends `/etc/nsswitch.conf` for mDNS resolution.
2. Enables `cups.socket` and `avahi-daemon.service`; CUPS is socket-activated.
3. Backs up and writes the selected user's `~/.cups/client.conf`.
4. Creates the configured PaperCut queues through the local CUPS socket.

Each run uses a unique root-only backup directory (mode `0700`) beneath
`/var/lib/arch-linux-config/printing-backups/`. Existing files retain their
metadata in backups; `absent-paths.txt` records original absence with mode `0600`.
A backup failure stops the client configuration write. Symlinked `.cups`
directories and `client.conf` files are refused. Do not change these paths
concurrently. Backups may contain private configuration and must not be committed.
There is no automatic rollback of queue or service state.

## Browser Troubleshooting

A release portal can fail because accumulated tracking cookies produce an
oversized request header, even when TLS works. The Firefox template uses strict
tracking protection. If needed, clear data for the affected site through
`about:preferences#privacy`, then retry. Review diagnostics privately: cookie
headers, URLs and account details must not be copied into repository documentation.
The historical observation is not a claim about the current portal's behavior.

## Privacy And Limits

Earlier Git revisions contained site-specific printing details. Sanitizing the
current tree does not remove those historical copies. History has not been
rewritten; assess prior distribution separately before publishing old revisions
or artifacts. This change does not read, modify or back up the host's printing
settings and does not create a local configuration containing the removed values.

The repository's personal monitor selectors are separate opt-in hardware settings;
they remain unchanged and can identify particular devices. Review them separately
before redistribution.

`scripts/verify-system-config.sh` does not yet verify printing configuration,
queues or CUPS/Avahi enablement. Queue creation requires the configured server to
be reachable. Unit tests use fictitious accounts and reserved test hostnames;
they do not contact a print server or change host services.
