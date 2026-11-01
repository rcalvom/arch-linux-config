# Tools Outside pacman

## Scope

This inventory was checked on November 1, 2026. It records explicitly installed
user tools, not a package profile or an instruction to install every entry.
The installer does not provision these tools, authenticate accounts, or copy
their runtime state.

## Node.js Tools

These packages are installed under `~/.npm-global`, independently of pacman:

| Package | Observed version | Purpose |
| --- | --- | --- |
| `@drawio/mcp` | `1.10.0` | Official local draw.io MCP server |
| `firebase-tools` | `15.23.0` | Firebase CLI and its MCP command |
| `@steipete/summarize` | `0.14.1` | Content summarization CLI |

To reproduce one approved package without changing npm's persistent prefix:

```bash
npm install --global --prefix "$HOME/.npm-global" @drawio/mcp@1.10.0
export PATH="$HOME/.npm-global/bin:$PATH"
```

Use the appropriate pinned package name/version from the table when installing
another tool. Check `npm list --global --prefix "$HOME/.npm-global" --depth=0`
afterwards. npm may block lifecycle scripts; review each required script instead
of enabling all installation scripts globally. draw.io's blocked optional cache
prefetch did not prevent the previously tested server handshake.

`@playwright/mcp@0.0.83` is present in the npx cache rather than the global package
list. Browser binaries and profiles are separate dependencies. The existing
Firefox browser/profile and the Chromium used by application E2E tests must not
be treated as disposable package cache.

## Standalone and Local Executables

| Tool | Observed state | Reconstruction |
| --- | --- | --- |
| GitHub MCP server | `2.0.3`, user-local executable | Obtain the matching platform asset from the [official release](https://github.com/github/github-mcp-server/releases/tag/v2.0.3), verify the published checksum, then install it in `~/.local/bin`. Account authorization is separate. |
| VectorCraft CLI | Configured as a local MCP command | Its installation source/version is not established by this inventory. Review it separately before provisioning another machine. |

An executable's presence or version output is not a current authentication or
integration test. The GitHub version was checked without connecting to its MCP.

## User Python Packages

The user Python 3.14 environment contains:

| Distribution | Observed version | Intended maintenance path |
| --- | --- | --- |
| `pulsectl` | `24.11.0` | Review migration to AUR `python-pulsectl` |
| `pulsectl-asyncio` | `1.2.2` | Review migration to AUR `python-pulsectl-asyncio` |
| `python-pptx` | `1.0.2` | Review migration to AUR `python-pptx` |
| `xlsxwriter` | `3.2.9` | Review migration to official `python-xlsxwriter` |
| `rzstyle` | `1.0.0` | Local editable LaTeX/Pygments style; project-local environment design remains pending |

Do not reinstall these globally as part of the system recipe. User-site copies
can hide pacman-managed versions. A migration requires checking consumers,
installing the replacement, and explicitly removing the overlapping user copy.
No migration was performed in this review. `uv` is installed through pacman; its
tool inventory was empty at review time.

## Integration State

The configured `drawio`, `firebase`, `github`, `playwright`, and `vectorcraft`
MCP servers were all disabled by default when inspected. Authorization is per
integration and task; installation alone does not enable them.

OAuth tokens, API keys, browser profiles, calendar mirrors, model caches,
OpenCode state, and private project paths are not reconstruction inputs stored
in this repository. Google Drive MCP remains deferred. Zotero and Thunderbird
MCP servers were investigated but not installed.
