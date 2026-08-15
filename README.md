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
