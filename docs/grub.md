# GRUB Profiles

The repository keeps two GRUB profiles. Activating one does not delete the graphical theme directory.

## Graphical

`grub/grub` and `grub/theme/` preserve the existing icon-based graphical theme. Its timeout remains `-1`, requiring explicit user input before boot.

## Classic

`grub/classic/grub` uses a minimal gfxterm theme that retains GRUB's traditional terminal presentation while allowing its font, palette, and spacing to match the greeter:

- Black background with white text.
- A blue selected entry, without a menu frame, icons, or artwork.
- `Choose the operating system` in blue.
- Terminus Bold 22 px, generated for GRUB from the same Terminus font family as the greeter's `ter-v22b` font.
- Greeter palette: black `#000000`, white `#e0e0e0`, and blue `#008ec4`.
- An 8 px menu-entry padding.
- A three-second textual countdown: `Booting in %d seconds`.
- Terminus Bold 18 px for GRUB's `Loading Linux` and `Loading initial ramdisk` messages.

It keeps the same kernel command line and boot-entry behavior as the other profiles. The included nine-slice assets only draw the traditional square menu frame and selection; they do not add background art.

Applying the classic profile removes the retired graphical TUI theme at `/usr/share/grub/themes/arch-tui` only after generating a valid new `grub.cfg`. A copy is kept in that profile switch's backup directory.

## Switching Profiles

Run the selector from the repository with root privileges. It asks for `APPLY`, saves the previous `/etc/default/grub` under `/var/lib/arch-linux-config/grub-backups/`, installs the selected profile, and regenerates `/boot/grub/grub.cfg`.

Restore the existing graphical profile with:

```bash
sudo ./scripts/apply-grub-profile.sh --profile graphical
```

Activate the classic terminal profile with:

```bash
sudo ./scripts/apply-grub-profile.sh --profile classic
```

Review the generated menu on the next reboot. The classic profile uses GRUB's graphical terminal so it can load the Terminus font, exact RGB palette, and textual countdown.
