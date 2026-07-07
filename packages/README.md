# Packages

This folder groups configuration files and package lists for common tools.

- `base.txt`, `desktop.txt`, `dev.txt`, and `vm.txt` are official repository package profiles.
- `aur.txt` lists optional AUR packages installed only when `install.sh` receives `--aur`.
- `alacritty/` contains the Alacritty terminal config (`alacritty.toml`).
- `nvim/` contains the active Neovim Lua config copied into `~/.config/nvim`.
- `oh-my-zsh/` stores the Oh My Zsh theme used here (`ginger.zsh-theme`).
- `pacman/` keeps package lists and a helper script for updating them.
- `xorg/` holds legacy Xorg session settings (`.xprofile`).

## Config Manifests

Tool folders under `packages/` can include a `files.conf` manifest. Each non-comment line uses this format:

```text
kind|mode|source|destination
```

Supported kinds:

- `user_file`: copy one file from the package folder into the created user's home.
- `user_tree`: copy a directory tree from the package folder into the created user's home.

Example:

```text
user_file|0644|alacritty.toml|.config/alacritty/alacritty.toml
user_tree|0644|.|.config/nvim
```
