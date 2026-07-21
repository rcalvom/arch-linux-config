# Packages

This folder groups configuration files and package lists for common tools.

- `base.txt`, `desktop.txt`, `dev.txt`, and `vm.txt` are official repository package profiles.
- `aur.txt` lists optional AUR packages installed only when `install.sh` receives `--aur`.
- `alacritty/` contains the Alacritty terminal config (`alacritty.toml`).
- `calcurse/` contains the calendar configuration and keymap.
- `firefox/` and `thunderbird/` contain launchers and profile templates.
- `nvim/` contains the active Neovim Lua config copied into `~/.config/nvim`.
- `yazi/` contains the file manager configuration copied into `~/.config/yazi`.
- `oh-my-zsh/` stores `.zshrc` and the `ginger` theme copied into the user's home.
- `vscode/` contains VS Code and VS Code R settings.
- `pacman/` keeps package lists and a helper script for updating them.

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
