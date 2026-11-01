# AUR Source Review

Review date: November 1, 2026.

## Method

All 17 distinct package pins in the generic, personal, and manual manifests were
resolved from AUR Git repositories. Their pinned `.SRCINFO` and `PKGBUILD` files
were read as data; no recipe was sourced or built on the host. The selected
package names exist in the pinned metadata, all entries have maintainers, and
the current DaVinci Resolve entry is flagged out of date.

HTTP HEAD requests checked generic and x86_64 source URLs. Local source files
were checked in the pinned Git trees. A 200 response establishes reachability,
not checksum validity or build compatibility. The review does not establish that
every pinned application can still build against current Arch libraries.

## Results

| Package | Original pin version | AUR version at review | Result |
| --- | --- | --- | --- |
| cliamp | 2.2.0-1 | 2.3.0-1 | Pinned sources reachable |
| opencode-notifier | 0.2.8-1 | 1.1.1-1 | Pinned sources reachable; generic optional profile only |
| openclaw | 2026.9.3-1 | 2026.10.3-1 | Pinned sources reachable |
| visual-studio-code-bin | 1.137.0-1 | 1.144.0-1 | Pinned sources reachable |
| google-chrome | 153.0.8010.36-1 | 156.0.8078.79-1 | Pinned sources reachable |
| zoom | 7.1.5-1 | 7.2.1-1 | Pinned sources reachable |
| zotero-bin | 10.0.2-1 | 10.0.7-1 | Pinned sources reachable |
| claude-code | 2.1.270-1 | 2.1.316-1 | Pinned sources reachable |
| chatgpt-desktop | 26.908.40834-1 | 26.1027.30824-1 | Pinned sources reachable |
| spotify | 1:1.2.96.518-2 | 1:1.3.4.258-2 | Old binary returned 404; pin updated after verification below |
| android-studio | 2026.1.4.7-1 | 2026.2.2.8-1 | Pinned sources reachable |
| google-cloud-cli | 584.0.0-1 | 591.0.0-1 | Pinned sources reachable; existing split-package restriction retained |
| gogcli | 0.40.0-1 | 0.47.1-1 | Pinned sources reachable |
| yay | 13.0.1-1 | 13.1.0-1 | Pinned sources reachable |
| davinci-resolve | 21.0.4-1 | 21.1.1-1 | Manual vendor archive and hardware/license review still required |
| flutter-bin | 3.47.2-1 | 3.47.7-1 | Sources reachable; MD5-only recipe and SDK setup remain deferred |
| verapdf | 1.30.2-1 | 1.30.3-1 | Sources reachable; MD5-only sources and Java installer remain deferred |

Versions other than Spotify were not automatically advanced. Updating a pin
requires a recipe/hook review, dependency review, and an isolated build; a newer
version number alone is not sufficient evidence.

## Spotify Repair

The personal manifest now pins AUR revision
`24ce1b811f5b4a821fa4b3ac332455933ff5e167` (`1:1.3.4.258-2`).
The new recipe and its launcher, protocol file, license, dependencies, and
signature-checking path were reviewed. The dependency list and the approved
signing fingerprint are unchanged.

Verification performed without executing the downloaded package:

1. Downloaded the official public repository key and checked its fingerprint
   against `E1096BCBFF6D418796DE78515384CE82BA52C83A`.
2. Verified the detached signature of the repository's `Release` metadata in an
   isolated temporary GnuPG home.
3. Verified the `Packages` SHA-256 against the signed release metadata.
4. Matched its binary SHA-512 to the pinned recipe.
5. Streamed the 179,241,028-byte binary archive over HTTPS and verified SHA-512.

This verifies the selected download and metadata, not a completed makepkg build
or application launch. Spotify repository metadata is mutable; a later upstream
update can invalidate an older pin's metadata checks. Do not bypass checksums or
PGP verification to work around that failure.

## Remaining Validation

- Build automatic AUR selections in a disposable target with current official
  dependencies. The baseline VirtualBox installer test intentionally omits AUR.
- Recheck proprietary download availability and Spotify signed metadata before
  a future installation.
- Review pins individually before advancing them; retain manual deferrals.
- The optional Yazi file chooser remains outside automatic recipes because its
  current AUR recipe follows a moving upstream Git branch.
