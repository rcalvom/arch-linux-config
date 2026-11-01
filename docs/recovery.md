# Recovery and First Login

The repository reconstructs managed configuration, not personal data or authenticated application state. This inventory is a recovery plan reviewed on September 13, 2026; it does not assert that any backup, encryption key or tested restore already exists. Backup destination, retention, encryption method and last restore test are pending confirmation.

## Recovery Inventory

| Category | Recovery source and handling |
| --- | --- |
| Managed configuration | Trusted Git revision or frozen source snapshot plus package manifests. Record the identity using the [configuration inventory](configuration-inventory.md) and [deployment matrix](host-deployment.md). |
| Personal documents and projects | Independent external encrypted backup, including uncommitted/untracked project work where needed. Inventory privately; verify a restore before relying on it. |
| Browser and mail data | Separately backed-up profiles, bookmarks and local-only mail as needed. Templates do not restore accounts, cookies or messages. Restore with applications closed and review version compatibility. |
| Calendar and tasks | Preserve local Calcurse appointments, TODOs and notes, plus any retained recovery sessions. Google projections are disposable, but local tasks are not. See [Calcurse](../packages/calcurse/README.md). |
| Authentication and secrets | Provision SSH/GPG keys, account recovery codes, password-manager access, Wi-Fi/VPN credentials and application tokens through a private recovery process. Keep decryption recovery material separate from the backup it unlocks. Do not put contents or secret locations in Git. |
| Account/provider configuration | Recreate private Vdirsyncer OAuth configuration, printing identity and optional tool/provider settings locally. Do not publish endpoints, tokens or account identifiers in recovery logs. |
| Machine-local state | Review boot/storage identifiers, network credentials, service overrides, display selection and fingerprint enrollment per target. Do not restore them blindly across hardware. |
| Disposable data | Caches, downloaded plugins, generated calendar projections and rebuildable container images can be regenerated only after confirming that they contain no unique work. Container volumes and workspaces need a separate data decision. |
| Deployment rollback data | If present, preserve `~/.local/state/archcfg-deploy` and applicable system migration backups privately. Local rollback copies are not independent backups and may contain private settings. |

Keep backups outside the laptop and outside this repository, encrypted at rest, with restricted access. An offline or independently protected copy reduces shared failure risk. Record backup date, scope, integrity check and a successful sample restore in a private inventory without recording keys or credentials here. Existing backup availability remains pending confirmation.

## First Login

1. Confirm the intended username, hostname and timezone against the [personal recipe](ricardo-setup.md). Test password login and recovery access before considering fingerprint enrollment.
2. Compare managed files with the documented verifiers and record drift before applying replacements. Preview user-file changes first; a successful ISO test is not proof of host deployment.
3. Configure Git identity locally using the placeholders below. Confirm the intended email, signing policy and credential method privately; the repository only supplies portable preferences.
4. Restore personal data from the verified external backup. Review ownership and permissions without importing unrelated runtime state or overwriting new work.
5. Follow [Vdirsyncer onboarding](../packages/vdirsyncer/README.md) for private OAuth setup and calendar selection, then [Calcurse behavior](../packages/calcurse/README.md) for persistent tasks and reminder limits. Calendar discovery and synchronization require explicit network authorization; do not treat them as offline checks.
6. Review optional [OpenCode](opencode.md), [notifications](opencode-notifier.md), [OpenClaw](openclaw-sandboxes.md), [printing](printing.md) and [editor extras](perfiles-portables.md) only when needed. Restore credentials privately and approve each integration separately. This checklist does not start or enable optional services automatically.
7. Review [pending maintenance](maintenance-backlog.md) and record physical validation separately. Do not mark charge/TRIM timers, firmware, audio or dock behavior complete without fresh evidence from an approved session.

These Git commands change only user configuration and are intended for a new account after the placeholders have been replaced, not for automatic execution during a documentation review:

```bash
git config --global user.name "<confirmed-name>"
git config --global user.email "<confirmed-email>"
```

Do not use a wholesale home-directory export as a configuration capture mechanism. Do not attach raw calendar, browser, mail, VPN or application logs to public recovery reports without a privacy review.
