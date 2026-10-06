# Tracker

The running list of what is queued, what only Alex can do, and what landed.
Last full upstream audit: basecamp/omarchy `81145eb` (2026-10-05). Keep this
file current whenever a request arrives mid-task.

## Needs Alex (cannot be scripted)

- **Empty the Trash.** ~375 GB of the Oct 2026 declutter sits there
  (Downloads ISOs/ROMs/firmware/movies, Xcode device data, Ollama and LM Studio
  models, caches, removed apps).
- **Delete Hue Sync and Fits** in Finder: root-owned, `trash` can't.
- **`claude auth login`**: the Claude CLI's saved sign-in has expired, so
  `mac usage` shows the plan (Max 5x) but no limits. `grok login` too, if
  Grok is in use.
- **Two LM Studio PATH lines** in `~/.zshrc.local` (harmless, point at nothing).
- **Karabiner's last trace**: drag
  `~/Library/Containers/org.pqrs.Karabiner-VirtualHIDDevice-Manager` to the
  Trash in Finder (macOS protects it from scripts). The driver itself was
  deactivated and its files removed on Oct 6; it drops out at the next reboot.
- **Text snippets** (upstream's XCompose: `<Multi> m s` → 😄, two spaces →
  "—", name/email) as Raycast Snippets: Raycast has no scriptable import.
- **Raycast hotkeys** for the SUPER launchers (macOS has no scriptable global
  launch-hotkey system). Mind the ⌥ clash: SUPER = ⌥ = herdr's `alt` layer
  (`alt+enter`, `alt+1..9`, `alt+arrows`), so pick other chords or Raycast's
  Hyper key. Candidates: `ghostty-run herdr`, `ghostty-run nvim`,
  `ghostty-run btop`, `ghostty-run cliamp`, `ghostty-run lazydocker`,
  `mac keys`, `transcode-pick`, plus upstream's 11 web apps as Quicklinks.

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
