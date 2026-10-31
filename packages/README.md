# Packages

This folder groups configuration files and package lists for common tools.

- `base.txt`, `desktop.txt`, `dev.txt`, and `vm.txt` are official repository package profiles.
- `aur.txt` pins reviewed optional AUR package revisions installed only when `install.sh` receives `--aur`; `aur-deps.txt` lists their reviewed official build and runtime dependencies.
- `alacritty/` contains the Alacritty terminal config (`alacritty.toml`).
- `ai-launchers/` adds [OpenCode and Claude Code application entries](ai-launchers/README.md)
  with icons to Rofi; each opens its CLI in Alacritty.
- `calcurse/` contains the calendar configuration and keymap.
- `cliamp/` contains a blue-accented theme built only from exact Alacritty palette colors, without managing provider credentials.
- `fastfetch/` contains the terminal system summary configuration.
- `firefox/` and `thunderbird/` contain launchers and profile templates.
- `lazydocker/` contains the Docker terminal UI configuration.
- `lazygit/` contains the Git terminal UI configuration.
- `nvim/` contains the active Neovim Lua config copied into `~/.config/nvim`.
- `tmux/` contains the blue terminal status-bar config copied to `~/.tmux.conf`.
- `yazi/` contains the file manager configuration copied into `~/.config/yazi`.
  Its terminal image and spreadsheet viewers require `chafa` and
  `python-openpyxl`, included in both desktop and personal package selections.
  The optional [Yazi file chooser portal](../docs/yazi-filechooser.md) is managed
  separately and is not enabled by the installer.
- `yazi-launcher/` installs the Chafa-based Yazi launcher into `~/.local/bin/yazi` for stable image previews in transparent Alacritty/Hyprland sessions.
  It preserves the graphical session variables as `ARCHCFG_GUI_*` before hiding
  the display from Yazi. The PDF opener restores them for Evince, so Enter can
  open a graphical window while previews continue using Chafa. Restart Yazi from
  the desktop terminal after updating the launcher. The PDF filename color
  (`#fb007a`, pink/red) is a file-type rule in `yazi/theme.toml`, not an error flag.
- `oh-my-zsh/` stores `.zshrc` and the `ginger` theme copied into the user's home.
- `vscode/` contains VS Code and VS Code R settings.
- `vdirsyncer/` contains the private Google Calendar mirror setup helper used by the Calcurse Google view.
- `pacman/` keeps host inventories of explicitly installed packages, independently
  of installer selections. Refresh them from any working directory with
  `bash packages/pacman/update_packages_list.sh` (when invoking from the repository
  root), or the script's absolute path. The historical `arch-aur-packages.txt`
  filename includes all foreign packages, which are not necessarily from AUR.

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

## Portable Preferences and Extras

`gtk/`, `btop/`, and `git/` contain whitelisted portable preferences. The cliamp
config selects only the terminal theme, without provider settings. VS Code keeps
optional extension IDs and a MIME association fragment separate from editor state.

`extras/` contains opt-in official package sets for development, research,
multimedia, virtualization, AMD graphics, and fingerprint hardware support.
See [portable profiles](../docs/perfiles-portables.md) for postinstall options,
CPU microcode policy, privacy boundaries, and the outer-CLI integration contract.
