# Server Bootstrap

User-level Bash bootstrap for a comfortable Linux development session on a remote server. It is intentionally self-contained so this directory can later become its own public repository.

It configures:

- Oh My Zsh and the custom `ginger` prompt.
- A lightweight Neovim configuration with the matching blue terminal theme.
- OpenCode with a safe global config and the matching `ginger` TUI theme.
- tmux, Git-aware Zsh aliases, history, `ripgrep`, and `fd`.

It does not configure Git identity, SSH keys, API keys, OpenCode credentials, disks, services, networking, or the default shell unless explicitly requested.

## Use

Clone the repository, then run the script as the regular target user. Do not run the whole script with `sudo`; it asks for `sudo` or `doas` only when package installation needs it.

```bash
git clone <repository-url>
cd <repository-directory>
bash server-bootstrap/bootstrap.sh
```

After exporting `server-bootstrap/` to its own repository, run the same script from that repository root instead:

```bash
bash bootstrap.sh
```

The supported package managers are Apt, DNF, Pacman, Zypper, and APK. The script installs `git`, `zsh`, `neovim`, `tmux`, `ripgrep`, `fd`, `curl`, Node.js, and npm when the package manager is available.

The bootstrap itself requires Bash. Minimal Alpine images usually need this first:

```bash
doas apk add bash
```

Use `sudo` instead of `doas` where appropriate, then run the script with Bash.

For Pacman, the default path does not refresh package metadata or upgrade the operating system. It only installs packages when `pacman -Qu` reports no pending upgrades. Review and opt into a full upgrade when needed:

```bash
bash server-bootstrap/bootstrap.sh --pacman-upgrade
```

After it completes:

```bash
exec zsh
opencode
```

Use OpenCode's `/connect` command to authenticate on each server. Authentication state is deliberately never copied by this bootstrap.

To change the login shell as part of the run:

```bash
bash server-bootstrap/bootstrap.sh --set-zsh-default
```

Use `bash bootstrap.sh --set-zsh-default` when running the exported standalone repository.

Useful options:

```bash
bash server-bootstrap/bootstrap.sh --dry-run
bash server-bootstrap/bootstrap.sh --skip-packages
bash server-bootstrap/bootstrap.sh --skip-oh-my-zsh --skip-opencode-install
bash server-bootstrap/bootstrap.sh --pacman-upgrade
```

## Safety And Recovery

Every managed file that differs from the bundled version is copied to:

```text
${XDG_STATE_HOME:-~/.local/state}/server-bootstrap/backups/run.XXXXXX/
```

The script then continues if a separate step fails and exits nonzero only after printing every failed step. This means a missing package manager, no sudo access, or a temporary network error does not prevent local themes and configuration files from being installed.

The bootstrap does not use `curl | bash`. Oh My Zsh is cloned through Git and OpenCode is installed with npm under `~/.local`, so no global npm permissions are required.

For safety, it refuses to replace a symlinked managed file or write through a symlinked parent directory. It honors absolute `ZDOTDIR` and `ZSH_CUSTOM` paths when selecting the Zsh config and Ginger theme destinations; relative paths are rejected because their runtime locations are ambiguous. Relative `XDG_CONFIG_HOME` and `XDG_STATE_HOME` values are ignored in accordance with the XDG specification and fall back to their standard paths under `$HOME`.

## Neovim

The bundled configuration is dependency-free and requires Neovim 0.7 or newer. This matters on distributions such as Ubuntu 22.04, whose standard repository provides Neovim 0.6. The script checks the installed version and leaves the Neovim configuration untouched instead of deploying an incompatible config.

The server profile intentionally does not set `clipboard=unnamedplus`: headless servers commonly have no clipboard provider, and that setting makes regular yanks report errors. Use your terminal's OSC52 integration or add a local provider if remote clipboard support is needed.

## OpenCode

OpenCode's visual theme belongs in `~/.config/opencode/tui.json` and `~/.config/opencode/themes/`, not in `opencode.jsonc`. The bundled `ginger` theme uses the same palette as Neovim and is selected by `tui.json`.

`opencode.jsonc` contains only safe defaults:

- `autoupdate: "notify"`
- `share: "manual"`

It contains no provider configuration, tokens, MCP credentials, or personal state. Quit and restart OpenCode after changing its configuration or theme.

## Publishing This Directory

Before publishing, review the payload, choose a license, and create a standalone repository from this directory. For example, Git can export its history as a separate branch:

```bash
git subtree split --prefix=server-bootstrap -b server-bootstrap-public
```

Push that branch to a new public repository rather than making the whole hardware-specific Arch configuration repository public.
