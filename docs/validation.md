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
tools, and iproute2. `--lint` additionally requires ShellCheck and blocks on
error-level findings. Warning-level cleanup remains separate work.

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
| GitHub Actions | Workflows prepared; remote results pending publication |
| Official bootstrap ISO | Signature verified against the Arch distribution keyring for `archlinux-2026.05.01-x86_64.iso` |
| VirtualBox preflight | Passed |
| Fresh ISO build | Started with run ID `validation-20261101`; result pending |
| Fresh VM and safe-mode installation | Pending the new ISO |
| AUR review | All 17 pins resolved; Spotify replacement download and signed metadata verified; package builds not performed |

The build captures a worktree snapshot before creating its VM. Documentation
edits made afterwards are not part of that snapshot. Record the final source
hash and results when the run completes; do not substitute older deployment
results for this run.

## End-to-End Evidence

Follow [VirtualBox automation](vbox-automation.md) for build, VM installation,
and safe-mode installation commands. Keep raw manifests, SSH keys, and runtime
logs in the private state directory. Publish only sanitized results and source
and ISO checksums. Historical results remain in
[host deployment records](host-deployment.md); each applies to its named source
and environment only.
