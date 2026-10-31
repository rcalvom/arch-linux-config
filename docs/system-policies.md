# Installed System Policies

## Battery Limits

`archcfg-charge-limit.timer` reconciles the policy every 10 seconds after the
previous service invocation finishes, with one second of timer accuracy. The
helper samples the dock/AC policy twice, two seconds apart. If the samples
disagree, it leaves thresholds unchanged and retries on the next timer tick.
Repeated stable evaluations do not rewrite unchanged thresholds. Systemd
serializes invocations of the oneshot service.

The udev rules are only initial-activation hints. `SYSTEMD_WANTS` does not reliably
restart an already activated device's dependencies on change or removal. The
timer handles repeated AC transitions, USB dock removal, missed events, and
resume without depending on those hints. Brief transitions between samples may
be coalesced; this is an eventually consistent policy, not a real-time guarantee.
Unsupported battery hardware is a successful no-op. Existing thresholds remain
0/50 for a powered dock and 0/90 for direct AC or battery operation.

## Maintenance

Postinstall enables `fstrim.timer` and `systemd-timesyncd.service` in the installed
target, not in the live ISO. It does not start either unit or run TRIM during
installation. TRIM uses the distribution's weekly timer and filesystem/device
support checks; no continuous-discard mount option or encrypted-device discard
passthrough is added. Unsupported disks and VM storage do not require special
host configuration. Time synchronization starts on the installed system's boot.

PipeWire and PipeWire Pulse use global user socket activation. Verification also
accepts directly enabled services; WirePlumber still requires its user service.

## Source Transfer

The installer reuses `lib/source-snapshot.sh` to copy a dirty Git worktree's
tracked and non-ignored untracked files, excluding known secret paths and
rejecting recognizable secret contents. Git history and ignored files are not
copied. This filter is defense in depth, not a general secret detector.

An ISO source without Git must carry a valid `.archcfg-source.files` manifest and
`.archcfg-source.sha256`. Only listed files and snapshot metadata are transferred;
extra files are not copied. Verification occurs before replacing the destination.
These checksums establish integrity, not publisher authentication: the ISO or
checkout must already be trusted. The snapshot helper is shared with ISO tooling
and is not duplicated or modified by the installation integration.

## Verification Privacy

`scripts/verify-system-config.sh --root PATH` checks an installed target offline.
It checks maintenance and charge timer enablement as well as managed files.
A `resolv.conf.vpnbackup` marker produces a warning rather than rejecting a
temporary VPN resolver. A stale backup is indistinguishable from an active VPN
using that marker alone, so the warning explicitly says so. A missing resolver
still fails. Resolver contents, backup contents, and alternate link targets are
never printed, including with `--diff`. Without the marker, the managed resolved
stub symlink remains required.

## Fixture Checks

Run `bash tests/power-transitions.sh`, `bash tests/power-system-config.sh`, and
`bash tests/source-install.sh`. These use temporary trees and mocks, without
sudo, host service changes, deployment, PAM changes, or microcode installation.
Full hardware timing, suspend/resume, and first-boot checks still require a VM
or an explicitly authorized installed target.
