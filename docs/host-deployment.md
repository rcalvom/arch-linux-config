# Host Deployment Status

Documentation review date: September 13, 2026. This record distinguishes source implementation, historical ISO validation and physical-host application. This documentation update did not deploy files, change services or recertify the host.

## Evidence Identity

Privacy cleanup on September 14, 2026 removed 18 confirmed contaminated generated
source archives and eight custom ISOs whose hashes matched the associated
manifests. The historical ISO identified below was among those removed. Manifests
and historical test results remain provenance records, not available artifacts
or validation of the latest sources. No official ISO or registered VM was deleted.
Remaining local build trees/artifacts require further review; do not publish them.

The same cleanup sanitized three known institutional printing literals across
local reachable history: three blobs and one commit message contained matches
before rewriting. All 100 then-existing commits were preserved, including one
reflog-only commit retained under `refs/sanitized-recovery/`. Eleven commit IDs
changed, one local branch ref changed, and no signature headers were removed.
The current tree, index, worktree and Git configuration were unchanged by the
rewrite. A fresh scan of 1,757 reachable objects and current Git-selected files
found zero matches for those three literals. Reflogs were expired only after
preserving the recovery commit; no remote was contacted or rewritten.

This is not a claim that every secret or historical copy was purged. Old
unreachable Git objects remain in the owner-only `.git` directory. The repository
and E2E evidence directory now have mode 0700, restricting access to retained
root-owned `out/` and `work/` through their parent. Removing those root-owned
artifacts was blocked by unavailable non-interactive sudo. No latest-source VM
installation or ISO rebuild has been performed in this cleanup stage.

The latest recorded validated ISO run is `hardware-20260913t153745z-c`, from a dirty-worktree snapshot, not a commit or the current active worktree.

| Identity | Recorded value |
| --- | --- |
| Base commit, provenance only | `0454ed78be4e2efd72c4b8c29e36aee78613872c` |
| Source tree SHA-256 | `5dd8e527e592c3f8984996794c38b718dc6a6e2808517401ed5ac49a3280465a` |
| Source archive SHA-256 | `5c57e3d915653adacd8334ee4b23c71254c3d5fa111ffc33e76810f819633eed` |
| ISO SHA-256 | `e7701b6981a21c2f4161de6f423901e5ef84152b2947d191640216ffeb2b8a85` |
| Manifest creation | September 13, 2026, 17:37:17 UTC |
| VM-mode E2E passed | September 13, 2026, 17:52:32 UTC |
| Safe-mode E2E passed | September 13, 2026, 18:00:22 UTC |
| Final historical preservation check | September 13, 2026, 18:01:48 UTC |

Local evidence reference, outside Git: `/home/ricardo/.local/state/arch-linux-config/e2e-vbox/reports/hardware-20260913t153745z/REPORT.md`. The report identifies retained manifests, artifacts and per-mode logs. Hashes above are transcribed historical evidence, not newly computed artifact checks. The bootstrap ISO hash was recorded but not independently authenticated against an upstream detached signature in that run.

## Status Matrix

| Area | Implemented in repository | Validated in recorded ISO | Applied on physical host |
| --- | --- | --- | --- |
| Installer and source transfer | Safe/VM paths, preflight and snapshot identity checks | Both modes installed and cold-booted; safe mode preserved the partition table | No installation or deployment in that run; current host not recertified |
| Generic Wayland desktop | Native discovery, Extend default, password-only generic lock | Live and installed graphical login, monitor IPC, zero config errors and generic profile checks passed | Current template deployment not established |
| Personal display/tablet profile | Explicit `--hardware-profile ricardo` | Personal deployment deliberately absent from baseline guests | Pending confirmation of deployed revision and physical tests |
| Charge reconciliation | Oneshot, 10-second timer and 2-second sample interval | Managed configuration checked; no physical battery/threshold validation | Pending: last physical audit failed timer enabled/active expectations |
| TRIM and time synchronization | Target enablement in postinstall | Managed system checks passed; not a physical TRIM effectiveness test | TRIM pending per last physical audit; current time-sync state not rechecked |
| CPU microcode and firmware | Target-vendor automatic microcode selection; firmware maintenance remains separate | VM microcode handling only; revision unknown in both hardware reports | Historical AMD microcode/BIOS maintenance remains pending, not repaired by source changes |
| Optional extras, AUR and fingerprint | Explicit selections; fingerprint package does not enable authentication | Baseline did not test AUR or physical fingerprint authentication; do not infer extras coverage | Personal selections and provisioning pending confirmation |
| Later worktree changes | Present only as reviewed source until separately validated | Not covered merely because the earlier ISO passed | No deployment performed by this documentation update |

## Personal Home Assistant Deployment

On September 25, 2026, Ricardo approved and applied the optional Home Assistant
loopback policy from a dirty worktree based on `83335fa`. This is host-specific
deployment evidence, not installer or ISO validation.

- `home-assistant-loopback.service` was enabled and active.
- Its `nft` syntax check and rule installation both completed successfully.
- The active `inet home_assistant_loopback` table accepts TCP/8123 from `lo` and
  drops all other TCP traffic to that port, ahead of the managed filter chains.
- The sanitized Compose definition uses Docker host networking. Home Assistant
  initial onboarding was completed locally at `http://127.0.0.1:8123`.
- The Home Assistant runtime `config/` directory, accounts, device data,
  integration credentials and database are intentionally outside Git.
- Passive mDNS discovery did not identify the two IoT light bulbs or the Dreo
  fan. The Dreo integration remains pending separate approval because its
  current official custom component uses cloud polling and requires the Dreo
  application account.
- The Dreo device was subsequently identified as Tower Fan 307S (`DR-HTF007S`,
  firmware `V 3.8.8_3.0.8`), a supported Nomad One S model in the official
  Dreo custom component. Integration remains pending approval because it is
  cloud-mediated.
- With approval, the official `hass-dreoverse` `v2.2.1` release was manually
  installed at `config/custom_components/dreo` after verifying release-asset
  SHA-256 `5894282659f1379c382ef60808907cf4235761040a74ae1538bf601372fabee4`.
  Home Assistant restarted and loaded the custom component; local UI readiness
  was verified. The Dreo account configuration flow and its managed
  `pydreo-cloud==1.0.0` dependency installation remain pending user entry in
  the local UI.
- An approved limited local-network scan did not identify the devices either;
  no external MAC-vendor lookup, authentication attempt, or broad port scan was
  performed. Router inventory or vendor applications are required to establish
  device identity.
- Ricardo later identified both light bulbs as TP-Link Kasa KL125. They are
  pending configuration through Home Assistant's built-in local-polling
  TP-Link Smart Home integration. Their local addresses are intentionally not
  recorded in Git.
- Their first Home Assistant configuration attempt was blocked by the known
  `python-kasa` KLAP v2 authentication-challenge bug; credentials are not
  recorded and no device reset, firmware change, password rotation, or custom
  workaround was applied.
- With approval, the reviewed temporary `tplink_klapv2_fix` component was
  installed from the repository source and activated through
  `configuration.yaml`. Its scoped KLAP v2 transport-selection test passed
  against the installed `python-kasa` 0.10.2 API. Home Assistant restarted,
  logged that the workaround was applied, and the loopback UI readiness check
  passed. The two bulb configuration flows remain pending user entry of the
  TP-Link account in the local UI.

The host's two IoT light bulbs and one IoT fan have not yet been integrated.
Their brands, models and current control applications must be identified before
adding an integration. Do not infer a cloud provider, device address, token, or
local-control protocol from discovery alone.

The [physical baseline](hardware-verification.md) records 41 pass, 5 fail, 1 unknown and 7 skipped checks: 4 failures concerned `fstrim.timer` and `archcfg-charge-limit.timer` enablement/activity, and 1 concerned failed user units. The older [maintenance backlog](maintenance-backlog.md), dated August 3, 2026, also leaves TRIM pending. Neither record establishes the current state or explains the timer failures.

## Validation Limits

Both ISO guests returned hardware-verifier exit 3: 42 pass, 0 fail, 2 unknown and 10 skipped checks each. Unknown microcode revision and passive GPU acceleration remain unknown. VirtualBox audio and 3D acceleration were disabled; service/socket presence does not prove audible output.

The tests used SATA VDIs, not physical NVMe installation. Physical Wi-Fi, Bluetooth, charge thresholds, fingerprint readers, audio playback, suspend/resume, displays and GPU acceleration remain unvalidated. See [hardware notes](desktop-hardware.md#historical-personal-hardware) and [VM automation](vbox-automation.md) for scope.

For a future approved deployment, record the exact source identity, date, target scope, changed files/units, verification exit codes and rollback reference. Keep implementation, artifact validation and host application as separate entries; do not replace historical failures with assumed success.
