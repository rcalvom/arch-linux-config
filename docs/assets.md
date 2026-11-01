# Third-Party Asset Review

Reviewed November 1, 2026. The repository's MIT license covers original code and
configuration, not every bundled image or font.

| Asset | Established terms or source | Remaining work |
| --- | --- | --- |
| AI launcher SVG paths | Simple Icons, CC0 1.0; bundled license in `packages/ai-launchers/icons/` | Brand and trademark rights remain separate |
| Classic Terminus PF2 fonts | Terminus, SIL OFL 1.1; full license copied from the installed font package to `grub/classic/theme/Terminus-FONT-LICENSE.txt` | Preserve the copyright and reserved-name terms when modifying fonts |
| Ubuntu Mono Nerd Font PF2s | Ubuntu Font Licence; bundled in graphical variants and now also the classic theme | Preserve upstream notices with distributed copies |
| Adwaita Mono arrow PF2s | SIL OFL 1.1; `grub/theme/Adwaita-FONT-LICENSE.txt` | Preserve the license in generated variants |
| `wayland/wallpapers/wallpaper.png` | Original author and redistribution permission not established | Identify the original source and license or replace with an authorized asset |
| `qtile/wallpapers/*` | Original sources and licenses not established | Review each image, including legacy assets |
| Graphical GRUB backgrounds | `grub/generate-theme.py` derives them from `qtile/wallpapers/wallpaper2.png` | Resolve the source wallpaper's terms; conversion does not establish permission |
| GRUB icon masks and recolored copies | Generator transforms existing masks; original attribution not established | Identify upstream sources and licenses or replace the masks |

The generator creates panel and selection geometry directly. That does not
resolve the provenance of the wallpaper, fonts, or icon masks used with it.
Git history records introduction of assets but does not establish authorship or
permission to redistribute them.

This review adds missing font license copies and records unresolved assets. It
does not certify all bundled resources for redistribution. Before distributing
a release containing the unresolved assets, obtain their terms or replace them.
See [third-party notices](../THIRD_PARTY_NOTICES.md).
