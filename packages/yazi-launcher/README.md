# Yazi desktop integration

`yazi` keeps the Chafa preview setup and preserves the graphical environment for
document openers. `archcfg-file-manager` opens a new Alacritty window with Yazi
for each requested local path. File paths select the item in its parent folder.

The user `yazi.desktop` overrides the packaged terminal-only entry. Configure the
directory association with `xdg-mime default yazi.desktop inode/directory`.
The D-Bus activation file serves `org.freedesktop.FileManager1` for applications
using ShowFolders or ShowItems (including browser download reveal buttons).
ShowItemProperties reveals the item; Yazi has no graphical properties dialog.
Remote file URIs are rejected. Arguments are passed without shell interpolation.

Dependencies: Alacritty, Yazi, Python, python-dbus and python-gobject. The desktop
session PATH must include `~/.local/bin` for the desktop entry. D-Bus activation
resolves the bridge through `$HOME`, independent of the bus PATH. Activation starts the
bridge on demand; no manually enabled service is required.

Deploy through `files.conf`, then run `update-desktop-database
~/.local/share/applications`. Existing alternative FileManager1 owners must exit
before this bridge can own the name.
