# Validation

## Local Checks

From the repository root:

```bash
bash scripts/check.sh
bash scripts/check.sh --lint
```

The command checks Bash syntax, runs 18 isolated shell tests, four Python test
groups, and four synthetic Node tests, then checks diff whitespace. Fixtures
mock system operations; they do not install Arch or exercise physical hardware.
Dependencies include Bash, Python with Pillow, Node.js, jq, GRUB utilities, SSH
tools, iproute2, and Calcurse. `--lint` additionally requires ShellCheck and blocks on
error-level findings. Warning-level cleanup remains separate work.

GRUB asset regeneration uses the bundled PF2 fonts. A separate font-rebuild
case requires the exact UbuntuMono Nerd Font and Adwaita Mono families plus
`fc-match` and `grub-mkfont`; it reports a skip when those dependencies are absent.
The Ubuntu CI runner does not provide those fonts. It still checks bundled font
rendering, asset regeneration, and profile deployment/rollback.

GitHub Actions runs this command with `--lint` on pushes and pull requests to
`master` and `project`. A second workflow scans history with Gitleaks. Actions
are pinned by commit, checkout does not persist credentials, and workflow
permissions are read-only. VM installations run locally in disposable guests.

## November 1, 2026 Review

Source base: `03504b41e739c249d66b65a6f54708aa477e7ea8`, with the reviewed worktree
changes. This is not a claim that the base commit alone contains the fixes.

| Check | Result |
| --- | --- |
| Calcurse cache/session regression | Passed headlessly after simulating terminal lifetime and closing inherited lock descriptors in the terminal monitor |
| Full local suite | Passed: Bash syntax, 18 shell tests, four Python groups (including 13 GRUB cases), four Node cases, and whitespace checks |
| Host ShellCheck | Not run: executable unavailable on the host |
| GitHub Actions | Both workflows passed on `03575434c7dd52046bb683d0beec77f904e64c4f`; regression run `41280604096`, secret scan `41280604235` |
| Official bootstrap ISO | Signature verified against the Arch distribution keyring for `archlinux-2026.05.01-x86_64.iso` |
| VirtualBox preflight | Passed |
| Fresh ISO build | Passed, run ID `validation-20261101`; ISO size 2,411,577,344 bytes |
| Fresh VM installation | Passed: installation, UEFI reboot, graphical login, configuration checks, Docker, and deployment/rollback tests |
| Fresh safe-mode installation | Passed on a separate disposable virtual disk, including partition-table and root/ESP witness preservation |
| AUR review | All 17 pins resolved; Spotify replacement download and signed metadata verified; package builds not performed |

The successful [regression run](https://github.com/rcalvom/arch-linux-config/actions/runs/41280604096)
includes error-level ShellCheck and the Calcurse local-notification test. Of the
14 GRUB cases, 13 passed and font rebuilding was explicitly skipped because the
runner lacks the source fonts. All 14 GRUB cases passed locally. The
[secret scan](https://github.com/rcalvom/arch-linux-config/actions/runs/41280604235)
also passed.

Initial CI runs exposed ambiguous ShellCheck analysis of later test mocks, an
Arch-keyring assumption in a fixture, and missing system fonts on Ubuntu. The
fixes preserve real command calls, validate optional mocked keyring setup, and
separate bundled-asset regeneration from dependency-sensitive font rebuilding.

The build captures a worktree snapshot before creating its VM. Later changes to
documentation, test portability, license line endings, and the equivalent GRUB
timeout expansion are not part of that snapshot. The source archive SHA-256 is
`d3f48aa5f4741f92bede95d45f5df3795d70820baed0fd0720eb7fc489652a83`.
The verified build manifest records:

- Source tree SHA-256: `d4049e43da70133a893c7fdb3e0f5ab61b84296f84102f6b5687479287cc3235`.
- ISO SHA-256: `6c6278fa7f43629229e126bfe9d1caca7a0daab50bf71b1b287f679af88ce6b2`.

Both installation modes passed using this same ISO and source snapshot.

### VM Installation Result

The `virtualbox` profile installed without AUR and booted kernel
`7.2.11-arch1-1`. The installed source tree matched the build manifest. Graphical
login and monitor IPC passed with zero Hyprland configuration errors. Docker
built and ran the local fixture through `sudo`, without adding the user to the
Docker group or downloading an external image. Managed system configuration,
deployment idempotency, private-file preservation, replacement, and hardware
profile rollback checks passed.

Passive hardware verification reported 42 passes, zero failures, two unknowns
(microcode exposure and graphics acceleration), and ten skipped observations.
System and user service checks found no failed units. Dotfile verification
reported ten extra-local-file warnings for installed launchers and Calcurse
units; these warnings did not fail the runner. This result does not establish
physical-device support or AUR build compatibility.

### Safe-Mode Installation Result

The separate safe-mode VM passed the same installation, reboot, graphical login,
Docker, configuration, and deployment/rollback checks. The runner prepared the
virtual partitions before invoking the safe installer. The partition-table
comparison and checksums of witness files on root and the ESP passed after
installation, confirming preservation of those fixtures. The runner set the
temporary test user's password separately before reboot.

Hardware verification again reported 42 passes, zero failures, two unknowns,
and ten skipped observations. The same ten dotfile warnings remained. Both test
VMs and the builder VM were removed by their successful-run cleanup; private
evidence and the ISO remain in the managed state directory.

## End-to-End Evidence

Follow [VirtualBox automation](vbox-automation.md) for build, VM installation,
and safe-mode installation commands. Keep raw manifests, SSH keys, and runtime
logs in the private state directory. Publish only sanitized results and source
and ISO checksums. Historical results remain in
[host deployment records](host-deployment.md); each applies to its named source
and environment only.
