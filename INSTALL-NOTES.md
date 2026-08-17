# Second-device install log — work MacBook (Jamf-managed), 2026-08-17

What actually happened bringing this repo up on a second Mac (macOS 26.5.2 →
26.6.1, arm64, DEP-enrolled in Jamf with Jamf Protect). Every issue below was
hit for real; fixes that generalize are also in the skill's gotchas and
committed to the configs.

## Starting state

Node was provided three ways at once (nvm at v24 first in PATH, brew fnm with
`--use-on-cd`, and a curl-installed mise that wasn't activated). AI CLIs were
scattered: native-installer `claude` and `grok` binaries in `~/.local/bin`,
`codex` as a brew cask, `gh` as a brew formula. Standalone `~/.bun` and
`~/.grok` installs, plus leftover `uv`/`uvx`.

## Issues hit, in order

1. **install.sh's `brew bundle` looked dead but wasn't.** The script exited
   while its brew child kept downloading for ~20 min. A second `brew bundle`
   started in parallel collided with the first's download locks. Wait for
   `pgrep -fl brew` to clear instead.
2. **Homebrew 6 tap trust.** `brew bundle` aborted outright on the untrusted
   `nikitabobko/tap` (AeroSpace). Fixed with `brew trust` on each third-party
   tap. Deceptively, bundle's ✔︎ marks during "Fetching" mean *downloaded*,
   not installed — the run had actually installed nothing.
3. **mise transient network failures** while brew saturated the link
   ("address not available" on 5 tools). A plain rerun of
   `MISE_MINIMUM_RELEASE_AGE=0 mise install` completed them.
4. **Nine casks need sudo** (1password, chatgpt, cleanshot, cursor,
   docker-desktop, ollama-app, raycast, steam, karabiner-elements) and one
   font cask conflicted with manually-installed font files
   (`--force` fixed the font). These required an interactive `brew bundle`
   run by the user.
5. **Homebrew 6 ask-mode** stalled `macup` at a y/n prompt. Fixed: `--yes` on
   both upgrade lines (committed).
6. **Chrome is Jamf/Keystone-owned** (root-owned app, system-wide
   `/Library/Google/GoogleSoftwareUpdate`). It had self-updated to 151 while
   brew's Caskroom metadata said 141; greedy upgrades failed forever with
   "already an App at …Caskroom…". Resolution: align the metadata dir names
   once, then drop the cask from the Brewfile entirely (committed) — brew can
   never own it on this machine.
7. **Karabiner-Elements was missing from the Brewfile** (added, committed).
   Its driver then failed activation with `OSSystemExtensionErrorDomain
   error 8 "code signature invalid"` although `codesign`, `spctl`, and the
   MDM system-extension policy (user overrides allowed) were all clean, and
   the extension never appeared in `/Library/SystemExtensions/db.plist`.
   A reboot did not help. The fix (from Karabiner-Elements#4314):
   `brew uninstall --cask --zap karabiner-elements` + reinstall, after which
   the dext activated instantly. `--zap` deleted the karabiner.json symlink —
   relinked from the repo.
8. **`go` reappeared via brew** as a build dependency during the bundle,
   violating layering (caught by `test.sh layering`); uninstalled — nothing
   depended on it.
9. **Deprecated casks** flagged by brew doctor: qbittorrent (torrents already
   migrated to Transmission on device 1) and deluge — both uninstalled.
10. **herdr 0.8.0 rejects 9 config keys** that only exist in preview builds
    (resize-pane binds, tab reordering, window_title etc.). Commented out
    with a re-enable note (committed).
11. **Test-suite fixes surfaced by this device:** the Karabiner
    driver-approval check asserted on `systemextensionsctl`, but Karabiner
    v16 loads without ever listing there — now a running VirtualHIDDevice
    daemon counts as approved (committed). The osascript keystroke tests
    fail from any shell without Accessibility/Automation grants; run them
    from the user's terminal.

## Machine-local layer added

`zsh/zshrc` now sources `~/.zshrc.local` (committed) for host-specific bits
that must not enter the repo: postgresql@18 PATH (appended, not prepended —
mise doctor flags prepends that outrank its tools), lesspipe, LM Studio PATH,
ssh-add. This device also pins AeroSpace workspaces (committed): 1–7 main,
8/9 on the two external Dells, with `main` fallback when undocked.
