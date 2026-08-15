# Script audit findings

From an adversarial audit of every helper script and the zsh functions. Each
finding below was **reproduced**, not inferred. Items marked ✅ are fixed;
the rest are open, ranked by severity.

## Fixed

- ✅ **`gd` could destroy uncommitted work in the wrong repo.** It derived the
  target from `basename $PWD`, so a plain directory named `notes--drafts`
  would `git worktree remove --force` + `git branch -D drafts` against
  `../notes`. Worse, `.zshrc` sources `aliases.zsh` *before* `functions.zsh`,
  so `alias cd=zd` was live when the function was parsed and got **baked into
  the body** — on a bad path zoxide fuzzy-jumps to an unrelated directory and
  returns 0, so the force-remove ran somewhere the user never named.
  Proven loss: an unpushed commit and a modified file, both gone.
  Now git-verified (`rev-parse --show-toplevel`, refuses the main checkout,
  refuses detached HEAD), shows `git status --short` before confirming, and
  uses `builtin cd`.
- ✅ **AppleScript injection → arbitrary command execution** in `webdl`,
  `weburl`, `chromium-native-host`. `display notification "$2" with title "$1"`
  interpolated untrusted text into AppleScript source; a crafted URL executed
  `do shell script`. The `^https?://` guard does not reject quotes. Now passed
  as `argv`, never as source.
- ✅ **⌥Enter and every `ghostty-run` bind silently did nothing.** AeroSpace
  launches binds with a minimal PATH (no `~/.local/bin`, no `/opt/homebrew`),
  so the bare script name never resolved. All binds now use absolute paths,
  and `ghostty-run` exports its own PATH so the internal `aerospace` calls
  (which do the workspace correction) can't silently no-op either.

## Open — high severity

1. **`mise-install` silently overwrites any existing script, and `/` in the
   name escapes `~/.local/bin`.** `rm -f "$HOME/.local/bin/$command"` with no
   checks: `mise-install transcode` clobbers the hand-written `transcode`;
   `mise-install pkg '../../.zshrc'` overwrites `~/.zshrc`. Fix: reject names
   containing `/`, and refuse to overwrite a file that isn't already a mise
   wrapper.
2. **`webdl` never reports a failed download.** `set -euo pipefail` plus
   `filepath=$(yt-dlp … | tail -1)` means a yt-dlp failure exits the script
   before the "Download failed" notification — lines 60-66 are dead code. Worst
   on the extension path, where `chromium-native-host` sends stdout+stderr to
   DEVNULL: the user gets "Downloading…" and then permanent silence.
3. **`transcode` writes to the wrong directory.** `base="${file%.*}"` strips the
   last dot-segment of the *whole path*: `transcode My.Project/clip mp4 720p`
   writes `My-720p.mp4` into the parent. With `./video` (no extension) the base
   is empty and ffmpeg reads `-1080p.mp4` as a flag. Fix: `dirname`/`basename`
   first.
4. **`tdlm` breaks (and can execute) on directory names with quotes.**
   `send-keys "cd '$dirpath' && …"` — a directory named `Bob's Project` throws
   `unmatched '`; one named `x'; rm -rf ~; '` executes. Fix: zsh `${(q)dirpath}`.

## Open — medium

5. `macup` — `command -v mas && mas upgrade || echo "not installed"`: the `||`
   binds to the whole list, so a genuine `mas upgrade` failure is misreported as
   "mas not installed". Also `set -e` means one bad cask aborts mise, cleanup,
   doctor and hooks with no summary of what was skipped.
6. `ga` — no `&&` chaining: when `git worktree add` fails, `mise trust` still
   runs and resolves *upward*, writing a trust entry for a directory the user
   never asked to trust.
7. `zd` — only handles "no args" and "is a directory". `cd -`, `cd --`, and any
   flag fall through to zoxide, which fuzzy-jumps and returns 0. This is what
   silently swallows typos (`cd ../doesnotexist` → somewhere unrelated, rc 0).
8. `ghostty-run` — `cmd="$*"` flattens argv, so `ghostty-run ls "my dir"` types
   three words; the not-running branch uses `"$@"`, so the two disagree. The
   fixed `delay` values are also a race: if activation is slow, the command text
   plus Return is typed into whatever app was frontmost.
9. `chromium-native-host` — `json.dumps` escapes non-ASCII as `\uXXXX`, which
   AppleScript rejects, so any title with an accent produces no notification at
   all (hidden by `capture_output`). Fix: `ensure_ascii=False`.
10. `lip` — `pgrep -af` is a GNU-ism. On macOS `-a` means "include ancestors",
    so it prints bare PIDs and can match its own shell. Fix: `ps -axo pid,command`.
11. `mac-keys --md` exits 1 (last line is `[ $MD = 0 ] && printf …`), so the
    documented regeneration command fails under `set -e`.
12. `mac-keys` modifier sed misses `control+`, `super+`, `alt+` (the config uses
    those spellings), and `s/opt+/⌥/` lacks the `g` flag.
13. `chrome-extensions` — `set -e` plus an unguarded `json.load` means one stray
    folder aborts the whole `list`; `mac-keys` guards this exact case, this
    doesn't. The `relaunch` path also assumes Chrome quits within `sleep 3`.
14. `mac-hook` — always exits 0, prints failures to stdout, and forces `bash`,
    so hooks with a python/zsh shebang break. Combined with `macup`'s `|| true`,
    a broken hook is invisible.
15. `webdl` exits 0 on "no video found", so callers see success.
16. `compress` with no argument creates a stray `.tar.gz`, and overwrites an
    existing archive without asking.

## Known upstream/platform behaviour (not our bug)

- **Closing the last window on a workspace jumps focus to another workspace.**
  Reproduced; disabling `on-focused-monitor-changed` does not help, so this is
  AeroSpace's own behaviour when a workspace empties. No config toggle exists.
- `⌥⇧Enter` (Chrome) has the same window-placement race `ghostty-run` was fixed
  for — `make new window` runs before `activate`.

## Verified clean

`mac` argument handling and exit codes · `weburl` (apart from the shared notify
issue, now fixed) · `tsl`'s zsh 1-indexing (`${panes[1]}`, `${panes[-1]}`) ·
`sff`'s `stat -f '%m%t%N'` (BSD does support `%t`) · `chromium-native-host`
framing (`struct '@I'`, 4 bytes) · no bash-4-only idioms anywhere (macOS ships
bash 3.2.57).
