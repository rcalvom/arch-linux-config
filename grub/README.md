Custom GRUB theme for this setup.

The `grub/grub` file in this folder is the exact configuration you should place at `/etc/default/grub`. That file is the base configuration used by `grub-mkconfig` to generate `/boot/grub/grub.cfg`.

Install the configuration file:

```sh
sudo cp grub/grub /etc/default/grub
```

Font creation from a regular TTF:

```sh
grub-mkfont -o <Output font> -s 24 <Path to font>
```

Remove the old installed theme:

```sh
sudo rm -rf /usr/share/grub/themes/arch
```

Copy the new theme into place:

```sh
sudo cp -r grub/theme /usr/share/grub/themes/arch
```

Regenerate the GRUB config after updating `/etc/default/grub` or the theme:

```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

One list commands:
```
sudo rm -rf /usr/share/grub/themes/arch
sudo cp -r grub/theme /usr/share/grub/themes/arch
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Todo:
- Update `info.png` with native labels.
- Rename GRUB entries in `/etc/grub.d` to change entry names and add terminal messages.
- Fix the title placement so it is not at the top of the page.
