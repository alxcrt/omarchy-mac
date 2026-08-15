# Gaps vs upstream Omarchy

From an audit against upstream `4.0.0.alpha` (HEAD `dd9dee4`). Everything here
is **genuinely portable** — Linux-only things (Hyprland groups, mouse binds,
`XF86*` media keys, the bar/theme/menu system) are deliberately excluded.

Note: upstream moved Hyprland config from `bindings.conf` to Lua
(`default/hypr/bindings.lua` + `bindings/*.lua`).

## Ranked by value per effort

1. **11 web-app launcher bindings** (`applications.lua`) — the largest single
   omission. Each is one `open -na "Google Chrome" --args --app=<url>` line:
   `SUPER+SHIFT+` C Calendar, E Email, ALT+E new email, Y YouTube, ALT+A Grok,
   ALT+G WhatsApp, CTRL+G Google Messages, P Photos, S Maps, X X, ALT+X X post.
   Requires moving `alt-shift-c` (currently reload-config) — it collides with
   upstream's Calendar bind.
2. **`fns/herdr`** — `hdl` / `hds` / `hdlm` / `hsl`. 100% portable; herdr, jq
   and gum are all installed and the port already aliases + key-binds herdr.
3. **`fns/ssh-reconnect`** — `ssh()` wrapper + helpers. Pure shell; prevents a
   dropped SSH session leaving mouse-tracking/alt-screen armed in Ghostty.
4. **Two env exports**: `SUDO_EDITOR="$EDITOR"` and `BROWSER` (`export
   BROWSER=open` on macOS). Also restore the `${EDITOR:-…}` guard so a pre-set
   `EDITOR` isn't clobbered.
5. **AeroSpace commands that exist but were never bound**:
   `move-workspace-to-monitor` (SUPER+SHIFT+ALT+arrows), `focus-monitor
   next/prev` (CTRL+ALT+TAB), window cycling (`focus dfs-next/dfs-prev` — ⌥Tab
   is spent on *workspace* next, so there is no window-cycling bind at all),
   and **workspace 10** (upstream loops 1..10, the port stops at 9).
6. **Bind tools the port already ships**: `mac-keys` on `SUPER+K` (upstream's
   keybindings cheat sheet — the script and KEYBINDINGS.md exist but nothing
   launches them), `transcode` on `SUPER+CTRL+PERIOD`.
7. **`window-theme = ghostty`** in `config/ghostty/config` — one line, supported
   on macOS, currently leaves window chrome on the system default.
8. **Bug: `lip()` uses `pgrep -af`.** On macOS `-a` means "include ancestors",
   not "print command line", so `lip` prints bare PIDs and never shows
   host/port. Use `pgrep -fl`.
9. **Shell hygiene** from `default/bash/shell` / `init`: `HISTSIZE=32768` +
   dup-ignore (`setopt hist_ignore_all_dups hist_ignore_space`), `unsetopt
   hash_cmds` (the zsh equivalent of upstream's `set +h` — stops stale mise
   shim paths), and `source <(fzf --zsh)` for Ctrl-R/Ctrl-T (fzf is installed).
10. **`SUPER+ALT+RETURN` → `ghostty-run tmux`**, and `SUPER+SHIFT+B` as a
    second browser bind.

## Smaller notes

- `alt-ctrl-l` runs `pmset displaysleepnow`, which only *locks* if "require
  password immediately" is set; otherwise it just sleeps the display.
- Spotify has no binding: upstream has `SUPER+SHIFT+M` = Spotify and
  `SUPER+SHIFT+ALT+M` = cliamp; the port collapsed both into cliamp.
- `CTRL+ALT+DELETE` (close all) is `alt-shift-w` here *and* means
  "close all **but current**" — different key and different semantics.
- Resize steps are smaller than upstream (±50/±10 vs ±100/±25), and upstream's
  ±300 "resize a lot" pair is missing.
- Upstream ships git config as a managed `~/.config/git/config` so `~/.gitconfig`
  can override it; the port bakes values into `~/.gitconfig`, so there's no
  override layer and upstream changes can't be pulled in cleanly.
- `fns/rsyncing` (`rsw`/`lsw`/`dsw`) needs `fswatch` instead of `inotifywait`.
- `fns/drives` (`iso2sd`, `format-drive`) needs a `diskutil` rewrite, not a copy.
- Clipboard `SUPER+C/V/X` and all `XF86*` media binds are correctly omitted —
  macOS already handles both natively.

## Fidelity scorecard

| Area | Fidelity |
|---|---|
| starship.toml | 100% (byte-identical) |
| tmux.conf | 99% (1 justified substitution) |
| git config | 16/17 settings |
| aliases | 13/14 |
| ghostty config | ~85% |
| envs | ~60% |
| shell functions | ~50% (4 of 8 upstream fns files absent) |
| AeroSpace bindings | ~45% of portable upstream binds |
