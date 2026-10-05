---
name: omarchy-mac
description: >-
  Work on Alex's Omarchy-on-macOS setup — the brew/mise package layering, the
  `mac` CLI and flow scripts, native macOS tiling, hidutil key remapping,
  herdr/Ghostty configs,
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
   `gh` live in `~/.config/mise/config.toml` at `latest`. Its `[settings]`
   hold `minimum_release_age = "0"` (without it mise's cooldown withholds
   today's releases and the CLIs silently lag days behind) and
   `upgrade.auto_prune = false` (auto-prune deleted versions under live
   claude/codex sessions; `macup` prunes instead, skipping versions `lsof`
   shows open). Don't reintroduce `MISE_MINIMUM_RELEASE_AGE=0` env hacks.
   grok is the registry `grok` (official binary), not `npm:@xai-official/grok`,
   whose launcher ran a stale ~/.grok/bin copy.

## Layout

| Path | Purpose |
|---|---|
| `~/.config/mise/config.toml` | dev + AI CLI layer |
| `~/.config/homebrew/Brewfile` | system + GUI layer (declarative) |
| `~/.config/zsh/aliases.zsh` | Omarchy aliases, macOS-adjusted |
| `~/.config/zsh/functions.zsh` | herdr layouts `hdl`/`hds`/`hdlm`/`hsl`, `ga`/`gd`, transcode wrappers |
| `~/.local/bin/mac-wm` | window management: native tiling + Spaces settings, and the only place the native shortcuts are written down |
| `config/launchd/com.omarchy.keyremap.plist` | login agent that reapplies the hidutil remap |
| `~/.local/bin/mac-defaults` | the macOS preferences (key repeat, Finder hidden files + path bar + status bar, instant Dock autohide, Transmission prefs + magnet/`.torrent` handler, `~/Developer`) as one list; `--status` / `--apply` |
| `~/.config/herdr/config.toml` | herdr (the multiplexer), keys mapped from Omarchy's tmux.conf. tmux itself was removed in Oct 2026; don't re-add it |
| `~/.config/ghostty/config` | upstream Omarchy, macOS-adjusted |
| `~/.local/bin/` | `mac`, `macup`, `mac-keys`, `mac-keyremap`, `mac-defaults`, `mac-hook`, `ghostty-run`, `transcode`, `webdl`, `weburl`, `browser-url`, `chrome-extensions`, `chromium-native-host`, `mise-install`, `agent-usage-*` |

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
`./test.sh <name>`: `layering aliases functions cd transcode compress herdr git
browser extensions mac scripts hooks wm keyremap defaults touchid shell brew repo`.

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
- **There is no tiling WM any more.** AeroSpace was removed along with Karabiner;
  window management is macOS 26's own tiling (`fn+⌃+arrows`, Window > Move &
  Resize) plus Mission Control Spaces (`⌃1-9`). `mac-wm` turns on what Apple
  ships disabled — edge-drag tiling, tiled margins, the ⌃1-9 hotkeys (symbolic
  hotkey ids 118-126) — and is the single source for the shortcut table, which
  `mac-keys` renders via `mac-wm --keys --porcelain`. Don't duplicate that table.
- **Dropping AeroSpace killed every `SUPER+<key>` app launcher** (`⌥Enter`,
  `⌥⇧B`, `⌥K`, the `⌥⌃` system panels…). macOS has no native global
  launch-hotkey system; Raycast is the intended home for them, and its hotkey
  config is **not scriptable** — that's a human step, report it as pending.
- **macOS will not let a script create Spaces.** `⌃1-9` only reaches Desktops
  that already exist; adding them is Mission Control (`⌃↑`, then `+`) by hand.
  **Desktops are per display** (separate Spaces is the default): `⌃N` reaches
  Desktop N of the focused screen only. `com.apple.spaces` also keeps entries
  for displays no longer connected, so count `type == 0` Spaces per Monitor
  (as `mac wm --status` does), never a total — a total of "11" once hid that
  the MacBook screen had a single Desktop.
- **Tiling shortcuts** (`fn⌃` arrows, `fn⌃F/C/R`) are Apple's documented
  macOS 27 keys (support.apple.com "Tile app windows"); they live in each
  app's Window → Move & Resize menu. Alex reports they work but "not
  perfectly" in some apps (Oct 2026, cause unconfirmed). Ghostty's
  performKeyEquivalent only claims ⌘ chords, so don't blame Ghostty for
  swallowing ⌃ without proof; reading menus needs Accessibility, which this
  setup's agent does not have.
- **zsh arrays are 1-indexed.** Ports of Omarchy's bash functions must use
  `${arr[1]}`, not `${arr[0]}`.
- **A function can't share a name with an alias in zsh** — it's a parse error
  that silently aborts the rest of the file. oh-my-zsh's git plugin used to
  alias `ga`/`gd`; it is gone, but `functions.zsh` still unaliases them first.
- **No oh-my-zsh (removed Oct 2026).** `~/.zshrc` is self-contained and must
  stay under the 100ms startup budget `test.sh shell` enforces. Do not cache
  `mise activate` output: it hard-codes the PATH of the moment it ran. starship
  and zoxide init ARE cached in `~/.cache/zsh/`; starship's RPROMPT is dropped
  (Omarchy's config has no right side, and it cost a process per prompt) and
  PROMPT2 is baked once with `STARSHIP_SHELL=zsh` so its escapes get `%{ %}`.
  `[[ ]]` never expands globs: `[[ -n f(N.mh+24) ]]` is always true. Profile
  with `zmodload zsh/zprof`, not by guessing.
- **Claude Code on macOS keeps its login in the Keychain** ("Claude
  Code-credentials", same JSON as `~/.claude/.credentials.json`, which is
  only a stale leftover here). `agent-usage-claude` reads it read-only via
  `/usr/bin/security`; the collectors are upstream copies with "macOS port"
  markers, so re-sync by re-copying and re-applying those.
- **Clipboard writes from a short-lived process.** `NSPasteboard writeObjects`
  from `osascript` lost the data 4 times in 5 once the process exited, while
  still reporting success ("Copied" with an empty clipboard). `mac-clip` and
  `mac-pbsnap` use `declareTypes` + `setString`/`setData` (synchronous, like
  `pbcopy`). Verify clipboard work on the REAL general pasteboard after the
  writer exits; a named pasteboard read in-process hides the bug.
- **terminal-notifier: click commands, not buttons.** An `-action` button
  needs a waiting process per notification, and with two pending macOS hands
  the click to the wrong one (Copy on one download copied another). Use
  `-execute` (stored in the notification). Its argument parser treats a value
  starting with `( { < " ' - [` as a plist/option and exits 2 with no
  notification; `mac-notify` backslash-escapes both title and message.
  `-execute` runs under launchd's bare PATH. Tests must never post real
  notifications (test.sh exports a silent `MAC_NOTIFY_BIN`).
- **Chrome extensions are staged copies** in `~/.config/omarchy-mac/extensions`
  (never symlinks). Edit them in `config/chromium/extensions`, run
  `chrome-extensions sync` (install.sh does), then reload them in
  chrome://extensions. Rename the service-worker file when its code changes:
  Chrome caches workers by URL. Nothing synced them before Oct 2026, so the
  yt-dlp extension ran an August copy for weeks; `test.sh extensions` now
  fails on drift. Download outcomes are webdl's notifications; the extension
  only shows progress.
- **mise's supply-chain guard** refuses npm packages under 1000 weekly
  downloads. Check the publisher and repo, then approve that one package with
  `{ version = "latest", allow_low_downloads = true }` (ghui is). Never
  disable the guard globally.
- **opencode's config schema has no `theme` key** any more (upstream still
  sets one); verify settings with `opencode debug config`, not the file.
- **`/usr/bin/git` is an xcrun stub** that adds ~10ms per call (every prompt in
  a repo pays it via starship). The Brewfile installs git so /opt/homebrew/bin
  wins on PATH.
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
- **`mas update` needs root, and can't touch apps another Apple Account
  owns.** Developer and TestFlight here were bought under a different account:
  every update attempt pops a modal "Redownload Unavailable with This Apple
  Account" dialog and mas prints "No downloads initiated for ADAM ID <id>".
  That is NOT "Apple's bundled apps" (an old wrong comment in macup). `macup`
  now pre-auths sudo (Touch ID) and remembers such IDs in
  `~/.local/state/macup/mas-skip`, keyed to the app's receipt mtime, so the
  dialog shows once and a reinstall clears the entry. The real fix is per app:
  `mas uninstall <id> && mas get <id>` under the signed-in account. Don't run
  `mas update` to "reproduce" it: each run pops the dialogs on the user's screen.
- **An app deleted by hand leaves brew's cask record behind.** brew then
  lists it as outdated on every `--greedy` run and never fixes it (zed and
  betterdisplay did this). `brew uninstall --cask <c>` clears the record. The
  reverse, an app installed outside brew (Claude.app), makes `brew bundle`
  fail on "already an App at"; `brew install --cask --adopt <c>` takes it
  over in place without replacing the app, which matters when it's running.
- **Locks: use `lockf`, never a hand-rolled one.** `macup` takes it as
  `lockf -s -k -t 0 file caffeinate -i -w $$`, started from a process
  substitution that reports "locked" (or lockf's error and status) back. The
  kernel lock lives in that lockf process alone (lockf closes it for its
  child), and caffeinate exits when macup does, so the lock lasts exactly as
  long as macup and no child of macup can inherit it. An mkdir/owner-record
  lock went through three Codex review rounds (Oct 2026) and every fix opened
  a narrower race; then re-exec under `lockf file "$0"` made `kill` hit only
  the wrapper, and an fd held in macup's own shell leaked into every child.
  Exit status 75 means "already held"; anything else is a real setup error.
- **No EXIT trap in a script that must die on `kill`.** bash 3.2 with an
  EXIT trap defers SIGTERM until a running `$(...)` finishes (measured: 5s
  versus 0.5s). Clean up temp files explicitly instead.
- **`/usr/bin/python3` is Xcode's launcher, not a Python.** Without the
  Command Line Tools it fails (or pops an install dialog), and with them it
  is 3.9 (no `tomllib`). Scripts here call `/opt/homebrew/bin/python3`.
- **Never run two brew bundles at once.** A second run collides with the
  first's download locks and both report spurious failures. Check
  `pgrep -fl brew` before assuming a bundle died.
- **On a Jamf/MDM-managed Mac, apps the MDM owns are root-owned** (Chrome
  here) and self-update outside brew. Brew's cask metadata goes stale and
  greedy upgrades fail forever on them — drop such casks from the Brewfile
  and let the MDM/vendor updater own them (see the google-chrome note there).
- **Karabiner is gone — the modifier remap is `mac-keyremap` (hidutil).** It was
  removed because its DriverKit extension kept breaking on Tahoe ("code
  signature invalid", error 8) and needed re-approval after every macOS bump.
  `hidutil` is Apple's own HID remapper: no driver, no extension, no Input
  Monitoring grant. The price is that it is strictly **key → key** — no
  dual-role keys and no multi-modifier Hyper. Caps Lock is a plain Escape
  (Oct 2026; it was a second ⌥ before) and right ⌘ is ⌥. Route Hyper chords
  through Raycast's own Hyper Key setting instead.
- **hidutil mappings are HID-system state, not files.** They vanish on reboot
  and can drop when a keyboard re-enumerates, so the mapping only persists via
  `~/Library/LaunchAgents/com.omarchy.keyremap.plist`. That plist is **copied,
  not symlinked** (launchd is fussy about plist ownership) — so `install.sh`
  must re-copy it, and the test asserts it matches the repo.
- **An orphaned system extension survives reboots.** Removing a driver-based
  app (Karabiner) leaves its dext `activated enabled` and loaded; it outlived
  three reboots here, so "macOS reaps it at boot" is false.
  `systemextensionsctl uninstall` refuses while SIP is on, and only an app
  signed by the same team can request deactivation. For Karabiner: install
  the Karabiner-DriverKit-VirtualHIDDevice pkg from pqrs-org's GitHub
  releases, then run `deactivate_driver.sh` and `sudo remove_files.sh` from
  `/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/`
  and `sudo killall Karabiner-VirtualHIDDevice-Daemon`. Remove a driver app
  with its own uninstaller first, never by deleting the .app.
- **Live configs drift out of symlink into real files.** `--zap` (and manual
  edits) replaced `~/.config/karabiner/karabiner.json`,
  `~/.config/aerospace/aerospace.toml` and `~/.claude/skills/omarchy-mac/SKILL.md`
  with plain copies, so committed changes silently never reached the machine —
  a Caps-Lock-to-Hyper commit sat unused for weeks. `ls -l` the live path before
  trusting that a repo edit is live. In Sept 2026, 21 of 24 linked paths had
  become copies (a stale `macup` without `--yes` kept hitting brew's y/n prompt).
  `test.sh repo` now asserts every `install.sh` link is a real symlink, and
  `install.sh --links` repairs them (backing up each copy to `.bak`) without
  running the rest of the installer. Diff the `.bak`s afterwards: live copies
  can hold edits the repo lacks, e.g. installer-appended `.zshrc` lines, which
  belong in `~/.zshrc.local`.
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
