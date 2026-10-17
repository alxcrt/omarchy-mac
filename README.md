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
   else — mise's config sets `minimum_release_age = "0"` so they track today's
   release, not the cooldown-delayed one.

Homebrew keeps runtime dependencies needed by its system utilities; project
runtimes take precedence through mise. For example, Homebrew's Python remains
for its own packages while `python` and `python3` in a dev shell use mise.

## Layout

```
config/mise/config.toml      → ~/.config/mise/config.toml     # the dev + AI CLI layer
config/homebrew/Brewfile     → ~/.config/homebrew/Brewfile    # the system + GUI layer (declarative)
config/zsh/aliases.zsh       → ~/.config/zsh/aliases.zsh      # ported Omarchy aliases (macOS-adjusted)
config/starship.toml         → ~/.config/starship.toml        # Omarchy's prompt
config/herdr/config.toml     → ~/.config/herdr/config.toml    # herdr: workspaces/tabs/panes (replaced tmux)
config/cmux/cmux.json        → ~/.config/cmux/cmux.json       # cmux: link routing, fleet SSH workspaces
config/launchd/com.omarchy.keyremap.plist → ~/Library/LaunchAgents/  # hidutil modifier remap at login
local/bin/macup              → ~/.local/bin/macup             # update-everything command
local/bin/mise-install       → ~/.local/bin/mise-install      # self-updating mise wrapper generator
zsh/zshrc                    → ~/.zshrc                       # minimal zsh: starship + mise + zoxide + fzf keys
```

## Install

Clone to `~/omarchy-mac` (a few scripts point there). `install.sh` is
idempotent: it symlinks every config into place (a real file it replaces is
copied to `<file>.bak` first), installs Homebrew if missing, then reconciles
both layers (`brew bundle` + `mise install`) and applies the macOS defaults.
Safe to re-run any time.

### A new Mac

1. Apple's Command Line Tools, for git (Homebrew needs them too).
   ```sh
   xcode-select --install
   ```
2. Clone (HTTPS: the repo is public, no SSH key needed yet) and install. The
   Homebrew step asks for your password once; the first run takes a while.
   ```sh
   git clone https://github.com/alxcrt/omarchy-mac.git ~/omarchy-mac
   ~/omarchy-mac/install.sh
   ```
3. Open a new terminal (Ghostty), then do the parts only you can do:
   - **Touch ID for sudo**: see [below](#touch-id-in-the-terminal-omarchys-fingerprint-auth).
   - **Sign in**: the App Store (so `macup` can update its apps),
     `gh auth login` (pick HTTPS: gh then handles git pushes too),
     `claude auth login`, `codex login`, and any other agent CLI you use.
   - **Git identity** lives in `~/.gitconfig`, not the repo:
     `git config --global user.name "…"` and `git config --global user.email "…"`.
   - **Chrome extensions**: `chrome-extensions install` opens Load unpacked
     with the folders revealed; `chrome-extensions verify` checks them.
   - **Raycast**: `mac raycast setup` prepares imports and shows the
     Script Directory, extension, alias, and settings steps.
   - **Desktops**: add the ones you want per display in Mission Control
     (`mac wm --status` shows the current layout).
   - **A Jamf-managed Mac** skips the Cursor and 1Password casks (Jamf
     installs them root-owned, which breaks `brew upgrade`); everywhere else
     the Brewfile installs them.
   - **Machine-only settings** (extra PATH entries, work aliases, `ssh-add`)
     go in `~/.zshrc.local`, which the repo never touches.
4. Check it: `mac doctor` for a quick health check, `./test.sh` in the repo
   for the full suite (a few checks need the sign-ins above).

### A Mac already set up some other way

Run the same two steps (Command Line Tools, clone + `install.sh`), then:

- Move anything machine-specific from `~/.zshrc.bak` (your old `.zshrc`) into
  `~/.zshrc.local`. oh-my-zsh is no longer loaded; `~/.oh-my-zsh` can go.
- One manager per tool: remove nvm/pyenv/asdf/rbenv, and brew copies of
  anything mise now owns (node, gh, the AI CLIs). `./test.sh layering` lists
  every tool that resolves somewhere other than mise.
- Quit and uninstall Karabiner-Elements and AeroSpace if present: `mac
  keyremap` (hidutil) and macOS's own tiling replace them, and both fight them.
- See what is installed but not declared:
  `brew bundle cleanup --file ~/.config/homebrew/Brewfile` only lists it
  (`--force` removes it). Add anything you want to keep to the Brewfile.

### A Mac already on omarchy-mac

The live configs are symlinks into the repo, so edits are made in the repo:
commit and push on one Mac, then on the other pull and re-run the installer.

```sh
git -C ~/omarchy-mac pull && ~/omarchy-mac/install.sh
macup
```

`install.sh --links` only repairs the symlinks (fast); `macup` warns when they
have drifted into plain copies.

## Update

```sh
mup      # mise tools + AI CLIs only (fast)
macup    # everything: brew, casks, Mac App Store, mise, cleanup
```

See **[KEYBINDINGS.md](KEYBINDINGS.md)** for every keybinding (generated from the
live configs with `mac keys`).

## Shared agent skill

`skills/omarchy-mac/SKILL.md` is linked into both `~/.claude/skills/` and
`~/.codex/skills/`. It teaches future sessions the layering rules, the flow
commands, how to run `test.sh`, and the gotchas that have already cost time —
cursor-warp focus jumps, `open -na` spawning duplicate app instances, zsh
1-indexed arrays, why aliases and functions can't share a name, and why tests must assert
on behaviour rather than prose.

## Flows (the point of this repo)

Omarchy's *behaviours*, ported — not its looks. One entry point:

```sh
mac                     # discoverable list of everything below
mac update              # brew + casks + mas + mise + cleanup   (= omarchy update)
mac mise                # just mise tools + AI CLIs             (= mup)
mac dl [url]            # yt-dlp the selected browser video -> ~/Movies
mac url                 # copy selected browser tab URL
mac transcode f.mov mp4 1080p     # also gif / jpg / png
mac wm --status         # native tiling / Mission Control state
mac usage               # AI token usage + rate limits (from Omarchy)
mac doctor              # mise + brew + window mgmt + keyremap health
mac raycast setup       # prepare launcher/import files and show the in-app checklist
mac dev doctor          # runtimes, Git, containers, database and API clients
mac dev git ui          # lazygit here, or pick a repository in ~/Developer
mac dev ports 3000      # inspect a listening development server
mac edit aliases|functions|mise|brew|herdr
```

For web/full-stack work, mise also manages Python, pnpm, ShellCheck and shfmt.
Bruno keeps API collections with project code; DBeaver Community browses
databases. Keka opens RAR archives and creates ZIP/7z archives on macOS.
`mac doctor` prints complete diagnostics, checks every layer, and exits
nonzero when any health check fails.
See [Developer workflows](config/dev/README.md) for the Git, Docker, database,
API and port commands. Raycast's single **Omarchy** menu includes the
environment check, Git repository picker, Docker and CLIamp music; Bruno,
DBeaver and Keka appear in normal app search.

Shell flows in `config/zsh/functions.zsh` (zsh ports of Omarchy's bash fns):

| Command | Does |
|---|---|
| `hdl <ai> [ai2]` | herdr dev layout: editor + AI pane(s) + terminal strip |
| `hdlm <ai> [ai2]` | one such layout per subdirectory |
| `hsl <n> <cmd>` | swarm layout — `<cmd>` in n tiled panes |
| `hds` | editor + diff watch + terminal + opencode |
| `ga <branch>` / `gd` | git worktree add+cd / remove worktree+branch |
| `rsw <src> <dest>` / `lsw` / `dsw` | sync a folder to a host on every change (fswatch + rsync) / list / stop |
| `iso2sd <image> [disk]` | write an image (also .gz/.xz/.zst/.zip) to an SD card / USB stick; external disks only, confirms first |
| `format-drive <disk> <name>` | erase an external disk to one exFAT partition (GPT); confirms first |
| `ssh …` | wraps ssh: clears stuck mouse/alt-screen modes and reconnects a dropped interactive session |
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

## Raycast

The default pack adds one **Omarchy** command. Search it, choose an action
from its dropdown, and press Return. Choices are grouped by Update, Learn,
System, Developer, Media and Fleet. Raycast's normal app search handles app
launching. No Store extension or JSON import is required for this menu.

The installer links `config/raycast/scripts/omarchy.sh` into
`~/.config/raycast/scripts`; register that Script Directory once in Raycast.
It migrates the earlier 16-command pack by removing only its own old symlinks,
preserving other scripts. Standalone commands remain in `config/raycast/optional`
for any individual hotkeys you want later. Terminal tools, keybindings and AI
usage open in the existing Ghostty instance; fleet entries use `cmux-fleet`.

`mac raycast setup` prints the short [setup guide](config/raycast/SETUP.md).
`mac raycast status` checks the menu's link without claiming private settings
or registration are verified. Optional: `mac raycast prepare` builds the
Quicklinks JSON for import, merging public defaults with the private
`~/.config/raycast/omarchy-quicklinks.local.json`. Snippets are also optional.
Private links, credentials and full Raycast exports stay outside this repo.

`browser-url` supports Helium and prefers the configured supported default
browser when it is running, with fallback to another running supported browser.
`OMARCHY_BROWSER` remains an explicit override. Raycast may require its own
Automation grant on the first browser or Ghostty command.

## Touch ID in the terminal (Omarchy's fingerprint auth)

`config/pam/sudo_local` makes `sudo` accept Touch ID. `pam_reattach` is listed
**first** on purpose — without it Touch ID silently fails inside herdr (or tmux/screen),
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
⌘W/⌘Q/⌘1-9), so **SUPER is ⌥**. Two keys are remapped:

- **Caps Lock** → Escape
- **Right ⌘** → ⌥, so SUPER is under the right thumb too

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
do dual-role keys, so Caps Lock is a plain Escape rather than tap-Escape /
hold-modifier. It also cannot emit a multi-modifier Hyper (⌘⌃⌥⇧) from one
key; if you want Hyper chords for Raycast, use Raycast → Settings → Advanced →
**Hyper Key** rather than reinstalling a driver.

The remap is a convenience, not a requirement: ⌥ is the real Super, so every
binding works with the mapping cleared.

## Notes

- Prompt is **starship** (Omarchy's config). There is no oh-my-zsh: `~/.zshrc`
  mirrors upstream's bash layer (history, inputrc-style keys, mise, zoxide, fzf
  key bindings, lazy `try`) and caches the starship/zoxide init scripts, so an
  interactive shell starts in ~70ms (was ~132ms with oh-my-zsh).
- Reports available macOS updates but never auto-installs them.
- **Docker Desktop** is in the Brewfile; its install/upgrade prompts for an admin
  password (`brew install --cask docker-desktop`).
- **Adobe Acrobat Reader** was intentionally dropped — the `26.001.21662` cask has a
  broken pkg install script that fails under `installer` even with sudo. macOS Preview
  handles PDFs; grab Reader from adobe.com directly if you truly need it.
- Third-party taps: Homebrew 6 refuses formulae from untrusted taps, so
  `install.sh` taps and trusts the Brewfile's three (cliamp, blacktop, unleash)
  before `brew bundle`.
