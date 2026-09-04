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
config/launchd/com.omarchy.keyremap.plist → ~/Library/LaunchAgents/  # hidutil modifier remap at login
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

See **[KEYBINDINGS.md](KEYBINDINGS.md)** for every keybinding (generated from the
live configs with `mac keys`).

## Claude Code skill

`skills/omarchy-mac/SKILL.md` is a Claude Code skill (linked to
`~/.claude/skills/`). It teaches a Claude session the layering rules, the flow
commands, how to run `test.sh`, and the gotchas that have already cost time —
cursor-warp focus jumps, `open -na` spawning duplicate app instances, zsh
1-indexed arrays, oh-my-zsh's `ga`/`gd` alias clash, and why tests must assert
on behaviour rather than prose.

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
mac usage               # AI token usage + rate limits (from Omarchy)
mac doctor              # mise + brew + window mgmt + keyremap health
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

## Window management (macOS native)

There is **no tiling window manager here any more.** AeroSpace was removed;
macOS 26 tiles windows itself and Mission Control provides the workspaces, so
the setup uses what the OS ships rather than a third-party WM that has to be
granted Accessibility and restarted after every upgrade.

`~/.local/bin/mac-wm` turns on the parts Apple ships switched off and reports
the state — it is the only "config" there is:

```sh
mac wm              # what tiling / Spaces are set to
mac wm --apply      # edge-drag tiling, tiled margins, ⌃1-9 Spaces
mac wm --keys       # the native shortcuts
```

| Keys | Action |
|---|---|
| `fn ⌃ ←/→/↑/↓` | tile window to a half |
| `fn ⌃ ⇧ ←/→/↑/↓` | arrange this window and the next |
| `fn ⌃ ⌥ ⇧ ←/→/↑/↓` | arrange half + quarters |
| `fn ⌃ F` / `fn ⌃ C` / `fn ⌃ R` | fill / centre / previous size |
| drag to screen edge | tile (hold ⌥ while dragging for the preview) |
| `⌃ 1..9` | switch to Desktop 1-9 |
| `⌃ ←/→` | previous / next Desktop |
| `⌃ ↑` | Mission Control — add Desktops here with **+** |

**What this costs, stated plainly.** Omarchy's `SUPER+<key>` app launchers
(`⌥Enter` terminal, `⌥⇧B` browser, `⌥⇧N` nvim, `⌥⌃T` btop, the `⌥⌃` system
panels, `⌥K` cheat sheet…) were AeroSpace binds and **are gone** — macOS has no
native global launch-hotkey system. Raycast is installed and is the natural
home for them (Raycast → Extensions → assign a hotkey, or a Script Command
pointing at `ghostty-run <cmd>`). The flows themselves all still work from the
shell: `mac term`, `mac keys`, `mac dl`, `mac transcode`, and so on.

Two more things macOS will not let a script do: **creating Desktops** (add them
by hand in Mission Control) and assigning Raycast hotkeys.

## Touch ID in the terminal (Omarchy's fingerprint auth)

`config/pam/sudo_local` makes `sudo` accept Touch ID. `pam_reattach` is listed
**first** on purpose — without it Touch ID silently fails inside tmux/screen,
because those processes aren't attached to the GUI session. One-time install
(needs sudo; `/etc/pam.d/sudo_local` survives macOS updates):

```sh
brew install pam-reattach
sudo cp config/pam/sudo_local /etc/pam.d/sudo_local
sudo chmod 444 /etc/pam.d/sudo_local
sudo -k && sudo true      # test — should prompt for fingerprint
```

## The SUPER key (hidutil)

Omarchy's binds are all `SUPER+…`. On macOS ⌘ is unusable for that (it owns
⌘W/⌘Q/⌘1-9), so **SUPER is ⌥**. Two more keys are remapped onto ⌥ so it is
reachable without contorting your left hand:

- **Caps Lock** → ⌥
- **Right ⌘** → ⌥

This used to be Karabiner-Elements. It is now `~/.local/bin/mac-keyremap`,
which drives **`hidutil`** — Apple's own HID remapper, built into macOS. No
kernel driver, no DriverKit system extension to approve, no Input Monitoring
grant, no menu-bar app, nothing to re-approve after a macOS upgrade.

```sh
mac keyremap            # apply
mac keyremap --show     # what the HID system currently holds
mac keyremap --clear    # back to stock keys
```

`hidutil` remaps live in the HID system rather than on disk, so they are lost
on reboot; `config/launchd/com.omarchy.keyremap.plist` is installed to
`~/Library/LaunchAgents` and reapplies the mapping at login.

**The trade-off, stated plainly:** `hidutil` is strictly key → key. It cannot
do dual-role keys, so **tap-Caps-Lock-for-Escape is gone** — Caps Lock is now
purely a second ⌥. It also cannot emit a multi-modifier Hyper (⌘⌃⌥⇧) from one
key; if you want Hyper chords for Raycast, use Raycast → Settings → Advanced →
**Hyper Key** rather than reinstalling a driver.

The remap is a convenience, not a requirement: ⌥ is the real Super, so every
binding works with the mapping cleared.

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
brew trust --formula anomalyco/tap/opencode
brew trust --cask   anomalyco/tap/cmux
brew trust --formula bjarneo/cliamp/cliamp
```
