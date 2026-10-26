# Tracker

The running list of what is queued, what only Alex can do, and what landed.
Latest command/package comparison: official `omacom/omarchy` `f4357a3`
(2026-10-17), verified through omarchy.org. The shell aliases and three usage
collectors retain upstream behavior with the documented macOS adaptations.
Linux desktop/system commands and optional development environments are not
automatically installed on macOS. Keep this file current when scope changes.

## Needs Alex (cannot be scripted)

- **Review and empty the Trash.** The earlier estimate was ~375 GB; the
  Oct 17 audit could not measure its current contents because macOS privacy
  permissions denied access. The Oct 2026 declutter included
  (Downloads ISOs/ROMs/firmware/movies, Xcode device data, Ollama and LM Studio
  models, caches, removed apps).
- **Delete Hue Sync, Fits, Checkm8.info and Run Receipt** in Finder (needs your
  password): root-owned, `trash` can't. Adobe's ARMDC helpers in
  `/Library/PrivilegedHelperTools` are leftovers of an uninstalled Acrobat.
- **macOS 27.2 Release Candidate** is offered (4 GB, needs a restart):
  install it from System Settings > Software Update when convenient.
- **Raycast `Hyper+P`**: repoint it from Bitwarden to 1Password (Settings >
  Extensions > 1Password, or the app). Then open 1Password > Settings > Browser
  and check the Helium extension connects to the app (Touch ID unlock).
- **`claude auth login`**: the Claude CLI's saved sign-in has expired, so
  `mac usage` shows the plan (Max 5x) but no limits. `grok login` too, if
  Grok is in use.
- **Karabiner's last trace**: drag
  `~/Library/Containers/org.pqrs.Karabiner-VirtualHIDDevice-Manager` to the
  Trash in Finder (macOS protects it from scripts). The driver itself is gone (Oct 6):
  it survived a reboot, so pqrs's 8.6.0 pkg was reinstalled for its
  `deactivate_driver.sh`, which removed the dext and its files at once
  despite printing "requires reboot"; its pkg receipt is forgotten too.
- **Raycast** (16 Oct): simplified to one **Omarchy** command with a grouped
  action dropdown, following current Omarchy's shared-menu approach. If the
  Script Directory is already registered, the file change should be picked up
  automatically; live UI verification is still unavailable. `mac raycast setup`
  prints the short guide. Quicklink/Snippet imports and extra Store extensions
  are optional. Existing extension cleanup and aliases remain in-app steps.
  The earlier 16 individual launchers remain under `config/raycast/optional`.
- **Raycast hotkeys**: assign only frequently used actions. Keep the existing
  hidutil mapping and avoid Option/herdr and Control-number/Mission Control
  conflicts. No new Hyper mapping is needed for the default menu.

## Queued

Nothing queued. Parked for later:

- **Agent account switching** (`omarchy-agent-account-*`): several
  Claude/Codex/Grok subscriptions, auto-switch near limits. Not now; Alex
  may try a CLI-proxy-API console instead (Oct 2026).

Decided (Oct 2026), don't reopen without a new reason: keep `macup` over
topgrade (its App Store skip-list, Touch ID sudo, in-use-safe pruning and
lock would stay custom anyway); keep `install.sh` links over GNU stow;
`test.sh` stays plain bash (no bats); `webdl` stays on yt-dlp (cobalt is a
hosted service).

## Done (Oct 2026, newest first)

- Oct 26 cleanup: removed Sideloadly (and its login daemon), PlayTorrio,
  Hopper, RustRover, Telegram, Hermes and calibre with their leftovers;
  CuaDriver kept (OpenAI's computer-use service, still in use). 1Password is
  the only password manager (Bitwarden uninstalled). Plex HTPC, Plexamp,
  Raspberry Pi Imager and AppCleaner moved under brew (`--adopt` is blocked
  by macOS App Management protection even with sudo, so brew reinstalled them
  with `--force`; settings in ~/Library kept). `macup` completed: opencode
  2.1.4 was held by mise's low-downloads guard (npm's stats API reports 0 for
  `@opencode/cli`), so that official package is approved in mise's config;
  the interactive guard prompt is what stalled the earlier run. Purged
  pnpm/npm/go/Playwright, Hugging Face + whisper models and Chrome/Helium disk
  caches; Docker build cache and unused images pruned and the VM trimmed
  (45 → 20 GB, volumes and containers kept). The uv cache was left: a
  long-running `uv run targ serve` holds its lock. `mac-defaults` now sets
  ⌃⌘-drag-anywhere to move windows: Helium/Chrome windows seemed "stuck" on
  the built-in display because a full tab strip leaves no title bar to grab
  (moving them by script worked, so macOS was not blocking them).

- Oct 17 maintenance: pulled the repo and official upstream reference; ran
  `mac update` successfully (12 Homebrew packages/apps and four AI CLIs).
  Added the approved Python, pnpm, ShellCheck and shfmt through mise, and
  Bruno, DBeaver Community and Keka through Homebrew. CLIamp was already
  installed at 2.3.0. Keka is Alex's chosen native archive app; the official
  Mac RAR cask is disabled by Homebrew for Gatekeeper failures.
- `mac doctor` now retains all diagnostic output, finishes every layer, and
  reports failure correctly. Docker completions register before the cached
  completion setup, with no hardcoded home or second `compinit` run.
- The single Raycast Omarchy menu now includes developer checks, a Git
  repository picker and CLIamp. `mac dev` groups existing Git/Docker/API/DB
  tools and listening-port checks; no services start during its status check.
  PostgreSQL's keg-only clients now work in a fresh shell. Declared the
  existing git-filter-repo installation; adjusted the OpenCode check for its
  version 2 parsed configuration format. Standard uv cache pruning reclaimed
  4.7 GiB; downloads and the stopped Docker VM were preserved.
- Brewfile drift (Oct 6): 15 formulae were installed but undeclared.
  awscli, glab and exercism moved to mise (dev CLIs); the other 12 are
  declared; `test.sh brew` now fails on any undeclared formula. Docker's
  unused images pruned (35 GB). The six casks the Brewfile had dropped
  (libreoffice, kdenlive, obs, losslesscut, zed, betterdisplay) uninstalled.
  linear is declared. `linear-linear` was its pre-rename token, not a second
  install: brew resolves it to `linear`, so uninstalling it would have removed
  Linear.app. Only the stale Caskroom symlink went.
- Casks (Oct 6): retroarch-metal declared; lm-studio, microsoft-edge,
  opencode-desktop, rebased and stats uninstalled (untouched 5 weeks to a
  year; no --zap, so settings remain). Teams, 365 Copilot and AutoUpdate are
  Jamf/Microsoft-owned pkgs: only brew's records of them were removed (apps
  kept). LM Studio's PATH entry left ~/.zshrc.local. `test.sh brew` now also
  fails on any undeclared cask.
- ↑/↓ history (Oct 6): prefix search now leaves the cursor at the end of the
  recalled line (up/down-line-or-beginning-search, as oh-my-zsh had);
  history-beginning-search-* kept it at column 0 on an empty prompt. The
  test drives a real zsh in a pty instead of reading the binding's name.
- zsh-autosuggestions and zsh-syntax-highlighting (Oct 6), from brew; no
  framework. Highlighting costs ~15 ms of startup, suggestions ~0; tested by
  typing into a real zsh (→ accepts a suggestion, unknown commands are red).
- Memory (Oct 6): swap was 50 of 52 GB on 36 GB. Docker's VM is capped at
  4 GB through `mac-defaults`, which now also edits apps' JSON settings files
  with plutil (Docker's VM had held ~19 GB with 25 MB of containers). Its
  100 GB build cache was pruned. Shells start in ~50 ms again: `.zshrc.local`
  reloaded every Keychain SSH key per shell (250 ms) and prepended
  `~/.hunk/bin` ahead of mise's hunk. `install.sh` trusts `ipsw-frida` too:
  ipsw's `conflicts_with` loads it, and bundle refused ipsw without it.
- `macup`'s lock, through Codex review rounds 2–10 (gpt-6.1-sol, xhigh) until
  a round came back clean: now the standard shell lock (`exec 9>>file;
  lockf -s -t 0 9`) held by macup itself. Killing macup stops it at once (no
  traps); a step still running keeps the lock until it ends and a refused
  run names it; setup errors show as themselves; no temp files. Drive
  checks use brew's python3. Lessons in SKILL.md.
- Upstream's agent CLIs via mise: crush, agy (antigravity-cli), copilot,
  ghui (approved past mise's low-download guard after checking its
  publisher), playwright, cf (npm, not Cloud Foundry). `a` knows the first
  three's auto-approve flags.
- `mac keys` merges herdr's built-in bindings with the config's overrides;
  opencode's self-update is off (tracked config); `macup` has an update lock
  and stays awake (caffeinate); `iso2sd` / `format-drive` ported to diskutil
  (external physical disks only, confirm first, compressed images stream).
- Codex review (gpt-6.1-sol, xhigh) of the day's work: fixed the clipboard
  write that silently vanished, notification text starting with ( { < " '
  being rejected, macup pruning with no process list, partial share files,
  slow webdl kills, compinit re-auditing forever, racy shell caches, Python
  3.9 under a bare PATH, and test-isolation gaps. Buttons replaced by click
  commands. Karabiner's orphaned driver removed.
- Usage collectors re-synced from upstream (Codex limits work again; new
  Grok collector in `mac usage`); Claude's reads the macOS Keychain, where
  Claude Code keeps its live login.
- `a` passes each agent upstream's "don't stop to ask" flag and starts in
  ~/Developer when launched from $HOME.
- `rsw`/`lsw`/`dsw` (fswatch + perl setsid) and the `ssh` reconnect wrapper,
  ported from upstream.
- `ghostty-run` on Ghostty's AppleScript (no keystrokes, no AeroSpace wait).
- mise: official `grok` (was stuck on 1.0.5), `hunk` for `hds`, release
  cooldown and auto-prune policy in config; `macup` prunes unused versions.
- Notifications: terminal-notifier with Show / Copy buttons; Copy makes an
  H.264/AAC `-share.mp4` (hardware encode) and puts the file on the
  clipboard; `webdl` titles, thumbnails and failure handling.
- zsh without oh-my-zsh: ~65 ms startup (was ~132), cached starship/zoxide
  init, `try`, brew git.
- tmux removed (herdr); declutter; Brewfile declares every installed tool;
  `mac-defaults`; Caps Lock = Escape; `macup` App Store dialogs; Helium.
