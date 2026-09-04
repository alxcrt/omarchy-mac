---
name: omarchy-mac
description: >-
  Work on Alex's Omarchy-on-macOS setup — the brew/mise package layering, the
  `mac` CLI and flow scripts, AeroSpace tiling, Karabiner, tmux/Ghostty configs,
  and the omarchy-mac dotfiles repo. Use whenever a request touches package
  installs, updates (`macup`/`mup`), keybindings, window management, terminal
  behaviour, the AI CLIs, or any config under ~/.config that this setup owns.
---

# Omarchy-on-macOS

A port of [Omarchy](https://omarchy.org) (Arch + Hyprland) to macOS: its
philosophy and userland, not its window manager. Everything is version
controlled at **`~/omarchy-mac`** (github.com/alxcrt/omarchy-mac) and installed
into `~/.config` + `~/.local/bin`.

## The three rules that define this setup

1. **One package manager per layer, no overlap.** Homebrew owns system + GUI
   apps; **mise** owns *all* dev tooling and AI CLIs. Never `npm -g`, never
   `brew install node`, never pipx/nvm/pyenv/asdf. If a tool appears in both
   layers, that's a bug.
2. **One command updates everything.** `macup` = brew + casks + mas + mise +
   cleanup. `mup` = the fast mise-only half.
3. **AI CLIs are versioned tools.** `claude`, `codex`, `opencode`, `grok`,
   `gh` live in `~/.config/mise/config.toml` at `latest`. Every update path
   **must** set `MISE_MINIMUM_RELEASE_AGE=0`, or mise's cooldown withholds
   today's releases and the CLIs silently lag days behind.

## Layout

| Path | Purpose |
|---|---|
| `~/.config/mise/config.toml` | dev + AI CLI layer |
| `~/.config/homebrew/Brewfile` | system + GUI layer (declarative) |
| `~/.config/zsh/aliases.zsh` | Omarchy aliases, macOS-adjusted |
| `~/.config/zsh/functions.zsh` | `tdl`/`tds`/`tdlm`/`tsl`, `ga`/`gd`, transcode wrappers |
| `~/.config/aerospace/aerospace.toml` | tiling WM: binds + auto-float rules |
| `~/.config/karabiner/karabiner.json` | Caps Lock → Hyper ⌘⌃⌥⇧ (Raycast), Esc on tap |
| `~/.config/tmux/tmux.conf` | upstream Omarchy verbatim |
| `~/.config/ghostty/config` | upstream Omarchy, macOS-adjusted |
| `~/.local/bin/` | `mac`, `macup`, `mac-keys`, `mac-hook`, `ghostty-run`, `transcode`, `webdl`, `weburl`, `browser-url`, `chrome-extensions`, `chromium-native-host`, `mise-install`, `agent-usage-*` |

## Commands

`mac` is the discoverable entry point (`omarchy <verb>` equivalent):
`mac update|mise|install|usage|keys|dl|url|transcode|term|wm|doctor|edit`.

**SUPER = ⌥ (Option)**, matching Omarchy. `⌥Enter` terminal, `⌥1..9`
workspaces, `⌥W` close, `⌥⇧1..9` send window. Full generated list:
`mac keys`, or `KEYBINDINGS.md` in the repo — **regenerate it, never hand-edit**:
`mac keys --md > ~/omarchy-mac/KEYBINDINGS.md`.

## Testing — always run this

`~/omarchy-mac/test.sh` is ~265 real functional tests (it executes things and
checks effects; it does not assert files exist). Run a section with
`./test.sh <name>`: `layering aliases functions cd transcode compress tmux git
browser extensions mac scripts hooks wm karabiner touchid shell brew repo`.

**Run the relevant section after any change, and the full suite before
committing.** Two skips are expected only if the user hasn't loaded the Chrome
extensions.

## Hard-won gotchas — read before "fixing" these again

- **Tests that assert on proxies lie.** Four false-passes happened this way:
  `grep -q LOADED` matches "NOT **LOADED**"; `file x | grep PNG` follows a
  symlink; a Brewfile *comment* matched a package check; a process-name check
  used `karabiner_grabber`, which no longer exists (it's `Karabiner-Core-Service`).
  Assert on **behaviour and machine-readable status**, not prose or process names.
- **`open -na <App>` spawns a whole new application instance** (its own Dock
  icon). Use `ghostty-run`, which drives the existing instance via AppleScript.
- **AeroSpace grabs keys globally.** Any bind here shadows the same key in every
  app — that's why `⌥⇧D`/`⌥⇧L` must stay unbound (the Chrome extensions own them).
- **`on-focus-changed = ['move-mouse ...']` must stay empty.** It physically
  warps the cursor; macOS then re-derives the focused workspace from the pointer,
  so spawning a terminal jumps focus to another workspace.
- **zsh arrays are 1-indexed.** Ports of Omarchy's bash functions must use
  `${arr[1]}`, not `${arr[0]}`.
- **oh-my-zsh's git plugin aliases `ga`/`gd`.** A function can't share a name
  with an alias in zsh — it's a parse error that silently aborts the rest of the
  file. `functions.zsh` unaliases them first.
- **`cp -f` writes *through* a symlink** to its target instead of replacing it.
  Upstream's `copy-url/icon.png` is a symlink out of the repo; `rm` then copy.
- **Apple-claimed file types** (`.mp4`, `.mp3`) ignore `duti` silently; macOS
  raises one confirmation dialog per type. Don't loop over many UTIs blindly.
- Some things need a human click and cannot be automated: Accessibility and
  Input Monitoring grants, system-extension approval, loading unpacked Chrome
  extensions, and any cask whose installer runs sudo. Report them as pending —
  never claim success.
- **Homebrew 6 refuses untrusted third-party taps** and aborts the whole
  `brew bundle` run. `brew trust <tap>` first. Also: the ✔︎ marks in bundle's
  "Fetching" phase mean *downloaded*, not installed — check `brew list`.
- **Homebrew 6 asks y/n before every upgrade** ("ask mode" is the default).
  Any unattended flow must pass `--yes` (`macup` does).
- **Never run two brew bundles at once.** A second run collides with the
  first's download locks and both report spurious failures. Check
  `pgrep -fl brew` before assuming a bundle died.
- **On a Jamf/MDM-managed Mac, apps the MDM owns are root-owned** (Chrome
  here) and self-update outside brew. Brew's cask metadata goes stale and
  greedy upgrades fail forever on them — drop such casks from the Brewfile
  and let the MDM/vendor updater own them (see the google-chrome note there).
- **Karabiner driver "code signature invalid" (error 8) on Tahoe** even when
  `codesign`/Gatekeeper pass: the fix that worked was a full
  `brew uninstall --cask --zap karabiner-elements` + reinstall (per
  pqrs-org/Karabiner-Elements#4314). Note `--zap` deletes
  `~/.config/karabiner/karabiner.json` — relink it from the repo afterwards.
  If reinstall doesn't fix it, suspect the endpoint-security agent (Jamf
  Protect) and check `/Library/SystemExtensions/db.plist` for whether the
  extension is even being staged.
- **`mise up` can silently lag behind a tool's real latest release.** codex's
  aqua package enumerates alpha tags but no stable `0.153.x`, so `mise latest
  codex` resolved an older build than codex's own updater reported, while
  `mise install codex@<exact>` worked fine. Neither `mise cache clear` nor
  `MISE_AQUA_BAKED_REGISTRY=false` fixed it. When a CLI reports a newer version
  than `mup` installs, compare `mise latest <t>` against the vendor channel
  (`npm view <pkg> version`, `gh api repos/<o>/<r>/releases/latest`) and switch
  that tool to the `npm:` backend, whose dist-tag is instant.
- **`mise install` fails transiently while brew saturates the network**
  ("address not available"). Just rerun it; already-installed tools are kept.
- **brew formulae can pull `go`/`node` in as build deps**, silently violating
  the one-layer rule. After big brew operations, `test.sh layering` catches
  it; `brew uses --installed <tool>` then `brew uninstall` if nothing needs it.
- **The osascript keystroke tests** (`SUPER binds`, `terminal placement`) can
  only pass from a terminal with Accessibility/Automation grants. From other
  contexts (agents, CI) they fail with "osascript is not allowed to send
  keystrokes" — that is the runner's permission, not a real regression.

## Working rules

- Check upstream before porting: clone `basecamp/omarchy` and read the real
  file rather than reconstructing it from the manual. Delete the clone after.
- Prefer **behaviour parity** over cosmetic parity; the user does not care about
  theming. Where macOS forces a deviation, keep it and comment *why* in the file.
- After changing anything in `~/.config` or `~/.local/bin`, copy it into
  `~/omarchy-mac`, run the tests, and commit — `test.sh`'s `repo` section checks
  live configs against the committed copies and fails on drift.
- Ask before installing anything new.
