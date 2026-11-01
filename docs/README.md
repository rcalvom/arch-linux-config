# Documentation

Use the operational guides for current commands. Historical records describe
specific past runs and do not certify the current checkout or host.

## Installation and Maintenance

| Task | Guide |
| --- | --- |
| Prepare an existing target mount | [Safe installation](safe-install.md) |
| Install on a disposable virtual disk | [VM installation](vm-install.md) |
| Check supported hardware and storage | [Hardware support](hardware-support.md) |
| Select packages | [Package manifests](../packages/README.md), [portable profiles](perfiles-portables.md) |
| Apply or roll back user configuration | [Configuration deployment](apply-config.md) |
| Recover a system | [Recovery](recovery.md) |
| Review external tools | [Tools outside pacman](external-tools.md) |
| Review AUR sources | [AUR review](aur-review.md) |
| Run checks and interpret CI | [Validation](validation.md) |
| Review asset redistribution terms | [Third-party assets](assets.md) |

## Desktop and Optional Integrations

- [Wayland configuration](../wayland/README.md)
- [Greeter](greeter.md), [GRUB](grub.md), and [lock screen](lock-screen.md)
- [Yazi file chooser](yazi-filechooser.md)
- [Printing](printing.md), [networking](networking.md), and [power policy](system-policies.md)
- [OpenCode](opencode.md), [OpenClaw](openclaw-sandboxes.md), and [Home Assistant](home-assistant.md)
- [Remote server bootstrap](../server-bootstrap/README.md)

## Personal Profile

These are opt-in selections, not requirements for a generic installation:

- [Personal package recipe](recipe-ricardo.md)
- [Package selection decisions](package-selection.md)
- [Reconstruction worksheet](ricardo-setup.md)
- [Hardware-specific configuration](desktop-hardware.md)

## Evidence and Historical Records

- [Host deployment records](host-deployment.md): source identities and results
  from individual runs, including earlier host-specific changes.
- [Configuration inventory](configuration-inventory.md): reconstruction and
  drift-review boundaries.
- [Hardware verification](hardware-verification.md): reported observations and
  the limits of those observations.
- [Historical maintenance backlog](maintenance-backlog.md): dated findings to
  recheck before changing an existing machine.

The [roadmap](roadmap.md) tracks current implementation and validation work.
Keep new run results in the validation record, and keep credentials, account
identifiers, private endpoints, and raw runtime logs outside Git.
