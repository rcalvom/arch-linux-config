# Packages

This folder groups configuration files and package lists for common tools.

- `base.txt`, `desktop.txt`, `dev.txt`, and `vm.txt` are official repository package profiles.
- `aur.txt` pins reviewed optional AUR package revisions installed only when `install.sh` receives `--aur`; `aur-deps.txt` lists their reviewed official build and runtime dependencies.
- `alacritty/` contains the Alacritty terminal config (`alacritty.toml`).
- `calcurse/` contains the calendar configuration and keymap.
- `cliamp/` contains the Archcfg Ocean custom theme without managing provider credentials.
- `fastfetch/` contains the terminal system summary configuration.
- `firefox/` and `thunderbird/` contain launchers and profile templates.
- `lazydocker/` contains the Docker terminal UI configuration.
- `lazygit/` contains the Git terminal UI configuration.
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

The developer and VirtualBox profiles install Docker, Docker Compose, and LazyDocker. The initial user joins the `docker` group, whose members have root-equivalent control over the Docker daemon.

Example:

```text
user_file|0644|alacritty.toml|.config/alacritty/alacritty.toml
user_tree|0644|.|.config/nvim
```
