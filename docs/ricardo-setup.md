# Ricardo's Setup Recipe

This is a reconstruction worksheet, not an export of the active host. Reviewed on September 13, 2026 using repository sources, the historical evidence linked below and Ricardo's supplied historical timezone. No host settings were inspected or deployed for this documentation update.

See [package selections](package-selection.md) for Ricardo's closed choices and future exclusions, and the [executable recipe](recipe-ricardo.md) for `--recipe ricardo`, reviewed pins and explicit manual deferrals. Disposable validation is authorized; host installation and deployment are not. Private settings below still require confirmation on the intended installation target.

## Installation Decisions

| Setting | Current repository default | Personal reconstruction decision and evidence |
| --- | --- | --- |
| Hostname | `archlinux` | Pending confirmation; no historical personal hostname established by the reviewed evidence. Do not infer it from the installer default. |
| Initial user | `ricardo` | Use `ricardo` for this worksheet; the request's repository/evidence paths and `lib/args.sh` agree. Confirm before installation. |
| Timezone | `America/Bogota` | Historical personal value: `America/Indiana/Indianapolis`, supplied in this documentation request. Confirm the intended location before installation. |
| Profile and recipe | `developer`, no recipe | Use `--profile developer --recipe ricardo` for the closed personal package selection; `virtualbox` additionally includes guest integration. |
| Hardware profile | `none` | Select `ricardo` only for the matching personal displays/tablet; see [desktop hardware](desktop-hardware.md). |
| CPU microcode | `auto` | Keep automatic target detection for a new physical installation; this does not remediate the existing host. |
| Extras | None | The recipe contains the approved development/research/multimedia/virtualization selections; only optional `fingerprint` may extend it. GPU policy is separate. |
| AUR | Off | Use `--aur` for reviewed automatic pins; `--defer-manual` explicitly acknowledges the three blocked selections. No claim of full AUR build validation. |
| Storage and boot | Safe mode, `/mnt` | Target disk, mounts and partition plan are pending confirmation. Existing encryption, shared ESPs and dual boot are outside the current installer scope. |

The CLI authority is [lib/args.sh](../lib/args.sh), not this worksheet. See [portable preferences](perfiles-portables.md) for extras and authentication limits and [safe install](safe-install.md) for target prerequisites.

## Personal Home Automation

Home Assistant Container is an optional, host-specific deployment for the two
IoT light bulbs and one IoT fan. It uses Docker host networking because bridge
networking did not provide host access on this machine. A dedicated nftables
policy restricts its UI on TCP/8123 to loopback only; LAN, Wi-Fi, Tailscale,
VPN, and Internet access are denied. Device brands, models, applications, and
integration credentials remain unrecorded until they are deliberately supplied,
and credentials must never be committed. See [Home Assistant](home-assistant.md).

## Read-Only Planning

Run from the repository root. These help commands do not install or deploy anything:

```bash
bash install.sh --help
bash install.sh --recipe ricardo --dry-run
bash apply-config.sh --help
```

The following argument worksheet is intentionally not an installation command. Replace the pending hostname and confirm the other decisions before assembling a command in a separately approved installation session:

```text
--target /mnt
--profile developer
--recipe ricardo
--hostname <pending-confirmation>
--username ricardo
--timezone America/Indiana/Indianapolis
--microcode auto
--hardware-profile ricardo
```

The hardware profile is a conditional personal choice, not a generic default. Use `--dry-run` for a write-free package plan. Models, private settings and SDK licenses are not included. Do not run `postinstall.sh` without `--dry-run` on the existing host; it is a full target installation phase. Do not use VM disk-erasure options as a host recovery shortcut.

For an existing account, this optional preview reports a user-file deployment plan without writes; it is not a package or system-service migration:

```bash
bash apply-config.sh --dry-run --module all --hardware-profile ricardo
```

`all` alone never selects the personal hardware profile. Review conflicts and private application settings before any later application; see [apply configuration](apply-config.md).

## Reconstruction Order

1. Complete the decision table and the [recovery inventory](recovery.md), including an independently restorable external backup.
2. Select a trusted source revision or frozen snapshot and record its identity. Compare it with the [deployment evidence](host-deployment.md); the latest recorded ISO is not the current worktree.
3. In a separately approved installation session, follow the safe-install prerequisites on the intended target. Do not copy old `fstab`, initramfs images or generated bootloader files blindly.
4. Complete the [first-login checklist](recovery.md#first-login) before enabling optional integrations.
5. Record target verification and any actual deployment separately. Keep physical hardware and maintenance items pending until directly tested.
