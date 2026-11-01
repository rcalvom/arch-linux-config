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
| Fresh ISO build | Started with run ID `validation-20261101`; result pending |
| Fresh VM and safe-mode installation | Pending the new ISO |
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
Record the final source
hash and results when the run completes; do not substitute older deployment
results for this run.

## End-to-End Evidence

Follow [VirtualBox automation](vbox-automation.md) for build, VM installation,
and safe-mode installation commands. Keep raw manifests, SSH keys, and runtime
logs in the private state directory. Publish only sanitized results and source
and ISO checksums. Historical results remain in
[host deployment records](host-deployment.md); each applies to its named source
and environment only.
