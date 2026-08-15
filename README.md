# omarchy-mac

The good parts of [Omarchy](https://omarchy.org) (Arch + Hyprland) ported to macOS —
the operating philosophy and the userland, not the tiling WM.

## Philosophy

1. **One package manager per layer, no overlap.**
   [Homebrew](https://brew.sh) owns system + GUI apps. [mise](https://mise.jdx.dev)
   owns all dev tooling + AI CLIs. Nothing is installed twice. Never `npm -g`,
   never `brew install node`, never nvm/pyenv/asdf.
2. **One command updates everything.** `macup` runs brew + casks + Mac App Store +
   mise + cleanup in sequence. `mup` is the fast, mise-only half.
3. **AI CLIs are versioned tools, not blessed globals.** `claude`, `codex`, `grok`,
   `gh` live in mise pinned to `latest`, bumped by the same command as everything
   else — with `MISE_MINIMUM_RELEASE_AGE=0` so they track today's release, not the
   cooldown-delayed one.

## Layout

```
config/mise/config.toml      → ~/.config/mise/config.toml     # the dev + AI CLI layer
config/homebrew/Brewfile     → ~/.config/homebrew/Brewfile    # the system + GUI layer (declarative)
config/zsh/aliases.zsh       → ~/.config/zsh/aliases.zsh      # ported Omarchy aliases (macOS-adjusted)
config/starship.toml         → ~/.config/starship.toml        # Omarchy's prompt
config/tmux/tmux.conf        → ~/.config/tmux/tmux.conf
config/aerospace/aerospace.toml → ~/.config/aerospace/aerospace.toml  # tiling WM binds
local/bin/macup              → ~/.local/bin/macup             # update-everything command
local/bin/mise-install       → ~/.local/bin/mise-install      # self-updating mise wrapper generator
zsh/zshrc                    → ~/.zshrc                       # oh-my-zsh + starship + mise
```

## Install

```sh
git clone git@github.com:alxcrt/omarchy-mac.git ~/omarchy-mac
cd ~/omarchy-mac && ./install.sh
```

`install.sh` is idempotent: it symlinks the configs into place (backing up anything
it would overwrite to `*.bak`), ensures Homebrew + mise, then reconciles both layers
(`brew bundle` + `mise install`). Safe to re-run.

## Update

```sh
mup      # mise tools + AI CLIs only (fast)
macup    # everything: brew, casks, Mac App Store, mise, cleanup
```

## Flows (the point of this repo)

Omarchy's *behaviours*, ported — not its looks. One entry point:

```sh
mac                     # discoverable list of everything below
mac update              # brew + casks + mas + mise + cleanup   (= omarchy update)
mac mise                # just mise tools + AI CLIs             (= mup)
mac dl [url]            # yt-dlp the video on the current Chrome tab -> ~/Movies
mac url                 # copy current Chrome tab URL
mac transcode f.mov mp4 1080p     # also gif / jpg / png
mac wm status|reload    # window manager state
mac doctor              # mise + brew + aerospace health
mac edit aliases|functions|wm|mise|brew|tmux
```

Shell flows in `config/zsh/functions.zsh` (zsh ports of Omarchy's bash fns):

| Command | Does |
|---|---|
| `tdl <ai> [ai2]` | tmux dev layout: editor + AI pane(s) + terminal strip |
| `tdlm <ai> [ai2]` | one such layout per subdirectory |
| `tsl <n> <cmd>` | swarm layout — `<cmd>` in n tiled panes |
| `ga <branch>` / `gd` | git worktree add+cd / remove worktree+branch |
| `compress <dir>` | tar.gz a directory |
| `img2jpg`, `transcode-video-1080p`, … | transcoding wrappers |

`ghostty-run <cmd>` opens a new window in the **existing** Ghostty — never
`open -na`, which spawns a duplicate app instance per launch.

## Window management (AeroSpace)

[AeroSpace](https://github.com/nikitabobko/AeroSpace) is an i3-style tiling WM that
does **not** require disabling SIP. `config/aerospace/aerospace.toml` ports Omarchy's
Hyprland binds. **Mod is Alt (⌥)** as the stand-in for Omarchy's SUPER — ⌘ would
clobber macOS shortcuts.

First run needs **Accessibility permission**: System Settings → Privacy & Security →
Accessibility → enable **AeroSpace**. It starts at login thereafter.

| Omarchy (SUPER) | Here (Alt ⌥) | Action |
|---|---|---|
| `SUPER+Enter` | `⌥+Enter` | terminal (Ghostty) |
| `SUPER+B` / `O` / `N` / `T` / `D` | `⌥+B/O/N/T/D` | browser / Obsidian / nvim / btop / lazydocker |
| `SUPER+W` | `⌥+W` | close window |
| `SUPER+arrows` | `⌥+arrows` | move focus |
| `SUPER+Shift+arrows` | `⌥+Shift+arrows` | move window |
| `SUPER+1..9` | `⌥+1..9` | switch workspace |
| `SUPER+Shift+1..9` | `⌥+Shift+1..9` | send window to workspace |
| `SUPER+J` | `⌥+J` | toggle split orientation |
| `SUPER+Shift+V` | `⌥+Shift+V` | toggle floating |
| — | `⌥+F` | fullscreen |
| `SUPER+-` / `=` | `⌥+-` / `=` | resize (or `⌥+R` for resize mode) |
| — | `⌥+Shift+C` | reload config |

## Notes

- Prompt is **starship** (Omarchy's config); oh-my-zsh is kept for plugins/completion
  with its own theme disabled.
- Reports available macOS updates but never auto-installs them.
- **Docker Desktop** is in the Brewfile; its install/upgrade prompts for an admin
  password (`brew install --cask docker-desktop`).
- **Adobe Acrobat Reader** was intentionally dropped — the `26.001.21662` cask has a
  broken pkg install script that fails under `installer` even with sudo. macOS Preview
  handles PDFs; grab Reader from adobe.com directly if you truly need it.

### First-run: trust third-party casks/formulae

Homebrew now requires trusting third-party taps or it silently ignores their
casks/formulae during upgrades. After `install.sh`, run once:

```sh
brew trust --cask   nikitabobko/tap/aerospace
brew trust --formula anomalyco/tap/opencode
brew trust --cask   anomalyco/tap/cmux
brew trust --formula bjarneo/cliamp/cliamp
```
