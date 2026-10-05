# Tracker

The running list of what is queued, what only Alex can do, and what landed.
Last full upstream audit: basecamp/omarchy `81145eb` (2026-10-05). Keep this
file current whenever a request arrives mid-task.

## Needs Alex (cannot be scripted)

- **Empty the Trash.** ~375 GB of the Oct 2026 declutter sits there
  (Downloads ISOs/ROMs/firmware/movies, Xcode device data, Ollama and LM Studio
  models, caches, removed apps).
- **Delete Hue Sync and Fits** in Finder: root-owned, `trash` can't.
- **Two LM Studio PATH lines** in `~/.zshrc.local` (harmless, point at nothing).
- **Karabiner's orphaned driver** is still loaded (`test.sh keyremap` fails on
  it). Reinstall its driver pkg so its own uninstaller can deactivate it:
  ```sh
  curl -fsSLo /tmp/kvhd.pkg https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v8.6.0/Karabiner-DriverKit-VirtualHIDDevice-8.6.0.pkg
  sudo installer -pkg /tmp/kvhd.pkg -target /
  bash '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh'
  sudo bash '/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/remove_files.sh'
  sudo killall Karabiner-VirtualHIDDevice-Daemon
  ```
  Then delete `~/Library/Containers/org.pqrs.Karabiner-VirtualHIDDevice-Manager`
  in Finder.
- **Raycast hotkeys** for the SUPER launchers (macOS has no scriptable global
  launch-hotkey system). Mind the ⌥ clash: SUPER = ⌥ = herdr's `alt` layer
  (`alt+enter`, `alt+1..9`, `alt+arrows`), so pick other chords or Raycast's
  Hyper key. Candidates: `ghostty-run herdr`, `ghostty-run nvim`,
  `ghostty-run btop`, `ghostty-run cliamp`, `ghostty-run lazydocker`,
  `mac keys`, `transcode-pick`, plus upstream's 11 web apps as Quicklinks.

## Queued

1. **Agent usage collectors**: re-copy upstream `omarchy-agent-usage-{claude,codex}`
   (7 fixes since Aug, incl. Codex 0.149 limits) and add the new `-grok` one.
2. **`mac keys` × herdr defaults**: merge `herdr --default-config` so built-in
   binds (prefix+s settings, prefix+w picker, prefix+g goto, …) show too.
3. **opencode config**: track `config/opencode/opencode.json` with
   `"autoupdate": false` (mise owns opencode).
4. **Replace-with-existing-tool candidates** (decide per item):
   `macup` → topgrade; `install.sh` symlinks → GNU stow; `test.sh` → bats
   (likely not worth it); `webdl` → cobalt (rejected: hosted service, yt-dlp
   is the local engine).
5. **More AI CLIs upstream installs** (pick): ghui, crush, agy, copilot,
   playwright, ori, muse, hey, basecamp, cf.
6. **Agent account switching** (`omarchy-agent-account-*`): several
   Claude/Codex/Grok subscriptions, auto-switch near limits. Bash-4 code;
   bigger port.
7. **Smaller**: `macup` update lock + `caffeinate`, `fns/drives`
   (`diskutil` rewrite), XCompose-style text snippets via Raycast.

## Done (Oct 2026, newest first)

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
