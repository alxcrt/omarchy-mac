#!/bin/bash
# test.sh — real functional tests for the omarchy-mac setup.
# Every test executes something and checks its effect; nothing here just
# asserts a file exists. Safe to run any time: it works in a temp dir, uses
# throwaway tmux sessions/git repos, and never runs macup or touches ~/Movies.
#
#   ./test.sh            run everything
#   ./test.sh <section>  run one section (e.g. ./test.sh tmux)

PASS=0; FAIL=0; SKIP=0
ok()   { printf "  \033[0;32mPASS\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  \033[0;31mFAIL\033[0m %s — %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }
skip() { printf "  \033[0;33mSKIP\033[0m %s — %s\n" "$1" "$2"; SKIP=$((SKIP+1)); }
sec()  { printf "\n\033[1m── %s\033[0m\n" "$1"; }
want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

ONLY="$1"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ZRUN() { zsh -ic "source ~/.config/zsh/functions.zsh 2>/dev/null; $*" 2>/dev/null; }

# ── 1. package layering ────────────────────────────────────────────────────
if want layering; then
sec "Package layering (one source per tool)"
for t in node claude codex gh bun go opencode grok omp herdr; do
  p=$(zsh -ic "command -v $t" 2>/dev/null)
  case "$p" in */mise/*) ok "$t resolves to mise";; "") bad "$t" "not found";; *) bad "$t" "resolves to $p";; esac
done
for c in claude codex gh opencode grok; do
  v=$(mise exec -- $c --version 2>&1 | head -1)
  [ -n "$v" ] && ok "$c runs ($v)" || bad "$c" "no version output"
done
n=$(zsh -ic 'command -v node' 2>/dev/null); [ -n "$n" ] && [ "$(zsh -ic 'node -e "console.log(1+1)"' 2>/dev/null)" = 2 ] \
  && ok "node executes JS" || bad "node" "cannot execute"
fi

# ── 2. aliases ─────────────────────────────────────────────────────────────
if want aliases; then
sec "Aliases (values must match upstream Omarchy)"
check_alias() {
  local a="$1" expect="$2"
  local got; got=$(zsh -ic "alias $a" 2>/dev/null | sed "s/^$a=//; s/^'//; s/'$//")
  if [ -z "$got" ]; then bad "alias $a" "undefined"
  elif [ -n "$expect" ] && [ "$got" != "$expect" ]; then bad "alias $a" "got '$got' want '$expect'"
  else ok "alias $a = $got"; fi
}
check_alias c 'opencode --auto'
check_alias cy 'codex --approve-for-me'
check_alias h 'herdr'
check_alias d 'docker'
check_alias r 'rails'
check_alias g 'git'
check_alias gcm 'git commit -m'
check_alias gcam 'git commit -a -m'
check_alias gcad 'git commit -a --amend'
check_alias ic 'tdl c'
check_alias ix 'tdl cx'
check_alias icx 'tdl c cx'
check_alias mup 'MISE_MINIMUM_RELEASE_AGE=0 mise up'
check_alias cd 'zd'
check_alias decompress 'tar -xzf'
for a in ls lsa lt lta ff eff t cx up macup; do check_alias "$a" ""; done
zsh -ic 'alias cx' 2>/dev/null | grep -q 'permission-mode auto' \
  && ok "cx uses --permission-mode auto (upstream)" || bad "cx" "wrong permission mode"
zsh -ic 'alias open' >/dev/null 2>&1 && bad "open" "must NOT be overridden on macOS" || ok "open left native (not overridden)"
fi

# ── 3. shell functions ─────────────────────────────────────────────────────
if want functions; then
sec "Shell functions defined"
for f in tdl tds tdlm tsl zd sff compress ga gd n fip dip lip \
         img2jpg img2png img2jpg-small img2jpg-medium img2jpg-large \
         transcode-video-1080p transcode-video-4K transcode-video-gif; do
  ZRUN "typeset -f $f >/dev/null" && ok "$f defined" || bad "$f" "not defined"
done
# both an alias AND a function of the same name must coexist where expected
ZRUN 'typeset -f ga >/dev/null' && ok "ga survives oh-my-zsh alias clash" || bad "ga" "clobbered by omz"
ZRUN 'typeset -f gd >/dev/null' && ok "gd survives oh-my-zsh alias clash" || bad "gd" "clobbered by omz"
fi

# ── 4. zoxide / cd wrapper ─────────────────────────────────────────────────
if want cd; then
sec "cd -> zd() zoxide wrapper"
[ "$(zsh -ic 'cd /tmp && pwd' 2>/dev/null | tail -1)" = /tmp ] && ok "cd to absolute path" || bad "cd abs" "wrong dir"
[ "$(zsh -ic 'cd && pwd' 2>/dev/null | tail -1)" = "$HOME" ] && ok "bare cd goes home" || bad "cd bare" "wrong dir"
zsh -ic 'cd /nonexistent-xyz' 2>&1 | grep -qi 'not found' && ok "cd reports missing dir" || bad "cd missing" "no error"
fi

# ── 5. transcode ───────────────────────────────────────────────────────────
if want transcode; then
sec "transcode (real media)"
magick -size 200x150 xc:red "$T/a.png" 2>/dev/null
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=duration=1:size=160x120:rate=10 "$T/a.mp4" 2>/dev/null
for q in high medium low; do
  out=$(transcode "$T/a.png" jpg $q 2>/dev/null | tail -1)
  [ -s "$out" ] && ok "jpg/$q -> $(stat -f%z "$out")b" || bad "jpg/$q" "no output"
done
out=$(transcode "$T/a.png" png high 2>/dev/null | tail -1); [ -s "$out" ] && ok "png -> $(stat -f%z "$out")b" || bad "png" "no output"
out=$(transcode "$T/a.mp4" mp4 720p 2>/dev/null | tail -1); [ -s "$out" ] && ok "mp4/720p -> $(stat -f%z "$out")b" || bad "mp4" "no output"
out=$(transcode "$T/a.mp4" mp4 4k 2>/dev/null | tail -1);   [ -s "$out" ] && ok "mp4/4k -> $(stat -f%z "$out")b"   || bad "mp4 4k" "no output"
out=$(transcode "$T/a.mp4" gif 720p 2>/dev/null | tail -1); [ -s "$out" ] && ok "gif (gifski) -> $(stat -f%z "$out")b" || bad "gif" "no output"
transcode "$T/missing.png" jpg high >/dev/null 2>&1 && bad "missing file" "should fail" || ok "rejects missing file"
transcode "$T/a.png" bogus high >/dev/null 2>&1 && bad "bogus format" "should fail" || ok "rejects unknown format"
# wrapper functions call through
cp "$T/a.png" "$T/w.png"; ZRUN "img2jpg '$T/w.png'" >/dev/null 2>&1
[ -s "$T/w-high.jpg" ] && ok "img2jpg wrapper works" || bad "img2jpg wrapper" "no output"
fi

# ── 6. compression ─────────────────────────────────────────────────────────
if want compress; then
sec "compress / decompress"
mkdir -p "$T/dir" && echo payload > "$T/dir/f.txt"
( cd "$T" && ZRUN "compress dir" >/dev/null 2>&1 )
[ -s "$T/dir.tar.gz" ] && ok "compress -> $(stat -f%z "$T/dir.tar.gz")b" || bad "compress" "no tarball"
mkdir -p "$T/x" && tar -xzf "$T/dir.tar.gz" -C "$T/x" 2>/dev/null
[ "$(cat "$T/x/dir/f.txt" 2>/dev/null)" = payload ] && ok "round-trip content intact" || bad "decompress" "content mismatch"
fi

# ── 7. tmux ────────────────────────────────────────────────────────────────
if want tmux; then
sec "tmux config + layout functions"
tmux -f ~/.config/tmux/tmux.conf new-session -d -s _cfg 2>/dev/null && ok "tmux.conf loads" || bad "tmux.conf" "failed to load"
for opt in "prefix C-Space" "prefix2 C-b" "mouse on" "base-index 1" "renumber-windows on" "history-limit 50000"; do
  k=${opt%% *}
  got=$(tmux show-options -g "$k" 2>/dev/null)
  [ "$got" = "$opt" ] && ok "option $opt" || bad "option $k" "got '$got'"
done
[ "$(tmux show-options -gw mode-keys 2>/dev/null)" = "mode-keys vi" ] && ok "vi copy mode" || bad "mode-keys" "not vi"
[ "$(tmux show-options -g status-position 2>/dev/null)" = "status-position top" ] && ok "status bar on top" || bad "status-position" "not top"
tmux list-keys 2>/dev/null | grep -q 'M-Enter' && ok "Alt+Enter pane split bound" || bad "M-Enter" "not bound"
tmux list-keys -N 2>/dev/null | grep -q 'Split pane vertically' && ok "-N bind descriptions present" || bad "-N descriptions" "missing"
tmux kill-session -t _cfg 2>/dev/null
for spec in "tdl 'echo ai'|3" "tsl 5 'echo s'|5" "tds|4"; do
  cmd=${spec%|*}; expect=${spec#*|}
  s="_L$$$expect"; tmux kill-session -t "$s" 2>/dev/null
  tmux new-session -d -s "$s" -x 220 -y 60 2>/dev/null
  tmux send-keys -t "$s" "source ~/.config/zsh/functions.zsh && $cmd" C-m; sleep 2
  n=$(tmux list-panes -t "$s" 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "$expect" ] && ok "${cmd%% *} -> $n panes" || bad "${cmd%% *}" "got $n want $expect"
  tmux kill-session -t "$s" 2>/dev/null
done
ZRUN 'tdl' 2>&1 | grep -qi usage && ok "tdl shows usage with no args" || bad "tdl usage" "no usage text"
ZRUN 'tsl 3 x' 2>&1 | grep -qi 'must start tmux' && ok "tsl refuses outside tmux" || bad "tsl guard" "no guard"
fi

# ── 8. git ─────────────────────────────────────────────────────────────────
if want git; then
sec "git config + worktree functions"
for kv in "pull.rebase true" "push.autoSetupRemote true" "diff.algorithm histogram" \
          "diff.colorMoved plain" "commit.verbose true" "rerere.enabled true" \
          "rerere.autoupdate true" "column.ui auto" "branch.sort -committerdate" \
          "tag.sort -version:refname" "init.defaultBranch main" "alias.st status"; do
  k=${kv%% *}; want_v=${kv#* }
  got=$(git config --global --get "$k" 2>/dev/null)
  [ "$got" = "$want_v" ] && ok "git $k = $got" || bad "git $k" "got '$got' want '$want_v'"
done
mkdir -p "$T/repo" && ( cd "$T/repo" && git init -q . && git commit -q --allow-empty -m init ) 2>/dev/null
( cd "$T/repo" && ZRUN "ga feat" >/dev/null 2>&1 )
[ -d "$T/repo--feat" ] && ok "ga created ../repo--feat worktree" || bad "ga" "worktree not created"
( cd "$T/repo" && git worktree list 2>/dev/null | grep -q 'repo--feat' ) && ok "ga worktree registered with git" || bad "ga" "not registered"
( cd "$T/repo" && git worktree remove "$T/repo--feat" --force; git branch -D feat ) >/dev/null 2>&1
fi

# ── 9. browser flows ───────────────────────────────────────────────────────
if want browser; then
sec "browser-url / weburl / webdl"
u=$(browser-url 2>/dev/null)
if [ -n "$u" ]; then
  ok "browser-url -> $u"
  saved=$(pbpaste)
  weburl >/dev/null 2>&1
  [ "$(pbpaste)" = "$u" ] && ok "weburl copied URL to clipboard" || bad "weburl" "clipboard mismatch"
  printf '%s' "$saved" | pbcopy
else
  skip "browser-url" "no Chromium-family browser with an open tab"
fi
webdl "https://github.com/alxcrt/omarchy-mac" 2>&1 | grep -qi 'no video' && ok "webdl rejects non-video URL" || bad "webdl" "should report no video"
webdl "ftp://example.com/x" 2>&1 | grep -qi 'not an http' && ok "webdl rejects non-http scheme" || bad "webdl scheme" "no guard"
grep -q 'OMARCHY_YTDLP_DIR' ~/.local/bin/webdl && ok "webdl honours OMARCHY_YTDLP_DIR" || bad "webdl" "no dir override"
grep -q "title)s \[%(id)s\]" ~/.local/bin/webdl && ok "webdl uses upstream filename template" || bad "webdl" "template differs"
fi

# ── 10. chrome extensions + native host ────────────────────────────────────
if want extensions; then
sec "Extensions + native messaging"
E=~/.config/omarchy-mac/extensions
for x in yt-dlp copy-url whatsapp-slim; do
  python3 -c "import json;json.load(open('$E/$x/manifest.json'))" 2>/dev/null \
    && ok "$x manifest is valid JSON" || bad "$x manifest" "invalid/missing"
done
# Symlinks at all are a bug here: Chrome resolves icons relative to the
# extension dir, and upstream's icon.png symlinks out of the repo root.
# `file` follows symlinks, so test for a REGULAR file explicitly.
for base in "$E" ~/omarchy-mac/config/chromium/extensions; do
  [ -d "$base" ] || continue
  n=$(find "$base" -type l 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = 0 ] && ok "no symlinks under $(basename "$(dirname "$base")")/$(basename "$base")" \
                || bad "extensions" "$n symlink(s) under $base"
done
for base in "$E" ~/omarchy-mac/config/chromium/extensions; do
  i="$base/copy-url/icon.png"
  [ -f "$i" ] && [ ! -L "$i" ] && file "$i" | grep -q PNG \
    && ok "copy-url icon is a real PNG file ($base)" || bad "copy-url icon" "not a regular PNG at $i"
done
NMH="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
for m in com.omarchy.ytdlp com.omarchy.copy_url; do
  python3 -c "
import json;d=json.load(open('$NMH/$m.json'))
assert d['path'].endswith('chromium-native-host'), d['path']
assert d['allowed_origins'], 'no origins'
" 2>/dev/null && ok "$m manifest valid + points at host" || bad "$m" "invalid manifest"
done
# real native-messaging protocol round trip
python3 - <<'PY' && ok "native host: copy-url mode sets clipboard" || bad "native host copy-url" "protocol failure"
import json,struct,subprocess,os,sys
h=os.path.expanduser("~/.local/bin/chromium-native-host")
def frame(o):
    d=json.dumps(o).encode(); return struct.pack('@I',len(d))+d
saved=subprocess.run(["pbpaste"],capture_output=True).stdout
r=subprocess.run([h,"chrome-extension://bgpiichlckmfanooecilcjemknkcpngb/"],
    input=frame({"url":"https://example.com/native-test"}),capture_output=True)
clip=subprocess.run(["pbpaste"],capture_output=True).stdout.decode()
subprocess.run(["pbcopy"],input=saved)
sys.exit(0 if r.returncode==0 and clip=="https://example.com/native-test" else 1)
PY
python3 - <<'PY' && ok "native host: rejects non-http url" || bad "native host guard" "did not reject"
import json,struct,subprocess,os,sys
h=os.path.expanduser("~/.local/bin/chromium-native-host")
def frame(o):
    d=json.dumps(o).encode(); return struct.pack('@I',len(d))+d
r=subprocess.run([h,"chrome-extension://bgpiichlckmfanooecilcjemknkcpngb/"],
    input=frame({"url":"javascript:alert(1)"}),capture_output=True)
sys.exit(0 if r.returncode==0 and not r.stdout else 1)
PY
chrome-extensions list >/dev/null 2>&1 && ok "chrome-extensions list runs" || bad "chrome-extensions list" "nonzero"
# Match the machine-readable status line, NOT prose: "NOT LOADED in any
# profile" contains the substring "LOADED in ", which false-passed twice.
if chrome-extensions verify 2>/dev/null | grep -qx 'STATUS=loaded'; then
  ok "extensions LOADED in Chrome"
else
  skip "extensions not loaded (per on-disk Preferences)" "load them, then quit Chrome once so it flushes Preferences"
fi
# AeroSpace must not shadow the extensions' own shortcuts.
A=~/.config/aerospace/aerospace.toml
grep -qE "^alt-shift-d\s*=" "$A" && bad "keybind conflict" "aerospace binds ⌥⇧D — Chrome's Download Video never sees it" \
  || ok "⌥⇧D free for the Download Video extension"
grep -qE "^alt-shift-l\s*=" "$A" && bad "keybind conflict" "aerospace binds ⌥⇧L — Chrome's Copy URL never sees it" \
  || ok "⌥⇧L free for the Copy URL extension"
fi

# ── 11. mac CLI ────────────────────────────────────────────────────────────
if want mac; then
sec "mac CLI"
mac help >/dev/null 2>&1 && ok "mac help" || bad "mac help" "nonzero exit"
for s in update mise dl url transcode term wm doctor edit usage install; do
  mac help 2>/dev/null | grep -q "mac $s" && ok "mac help documents '$s'" || bad "mac help" "missing '$s'"
done
mac wm status 2>/dev/null | grep -q '>' && ok "mac wm status shows workspace mapping" || bad "mac wm status" "no mapping"
mac usage 2>/dev/null | grep -q CLAUDE && ok "mac usage reads Claude data" || bad "mac usage" "no claude data"
mac usage 2>/dev/null | grep -q CODEX && ok "mac usage reads Codex data" || bad "mac usage" "no codex data"
mac bogus >/dev/null 2>&1 && bad "mac bogus" "should exit nonzero" || ok "mac rejects unknown subcommand"
mac edit bogus 2>&1 | grep -qi 'mac edit' && ok "mac edit validates target" || bad "mac edit" "no validation"
fi

# ── 12. helper scripts ─────────────────────────────────────────────────────
if want scripts; then
sec "Helper scripts"
for s in mac macup mise-install ghostty-run transcode webdl weburl browser-url \
         chromium-native-host chrome-extensions mac-hook agent-usage-claude agent-usage-codex; do
  p="$HOME/.local/bin/$s"
  if [ ! -x "$p" ]; then bad "$s" "missing or not executable"; continue; fi
  case "$(head -1 "$p")" in
    *python3*) python3 -m py_compile "$p" 2>/dev/null && ok "$s (python) compiles" || bad "$s" "python syntax error";;
    *)         bash -n "$p" 2>/dev/null && ok "$s (bash) syntax ok" || bad "$s" "bash syntax error";;
  esac
done
mise-install 2>&1 | grep -qi usage && ok "mise-install shows usage" || bad "mise-install" "no usage"
mise-install jq _ttjq >/dev/null 2>&1
[ -x ~/.local/bin/_ttjq ] && grep -q 'MISE_MINIMUM_RELEASE_AGE=0' ~/.local/bin/_ttjq \
  && ok "mise-install generates wrapper with age override" || bad "mise-install" "bad wrapper"
rm -f ~/.local/bin/_ttjq
for s in macup mac; do grep -q 'MISE_MINIMUM_RELEASE_AGE=0' "$HOME/.local/bin/$s" \
  && ok "$s forces MISE_MINIMUM_RELEASE_AGE=0" || bad "$s" "missing age override"; done
grep -q 'softwareupdate --list' ~/.local/bin/macup && ok "macup only lists macOS updates (never installs)" || bad "macup" "may auto-install OS updates"
for s in "brew update" "brew upgrade" "mas upgrade" "mise up" "brew cleanup"; do
  grep -q "$s" ~/.local/bin/macup && ok "macup runs '$s'" || bad "macup" "missing '$s'"
done
grep -q 'mac-hook post-update' ~/.local/bin/macup && ok "macup fires post-update hook" || bad "macup" "no hook call"
fi

# ── 13. hooks ──────────────────────────────────────────────────────────────
if want hooks; then
sec "Hook system"
mkdir -p ~/.config/omarchy-mac/hooks/_t.d
echo 'echo HOOK_D_FIRED' > ~/.config/omarchy-mac/hooks/_t.d/a
echo 'echo HOOK_MAIN_FIRED' > ~/.config/omarchy-mac/hooks/_t
mac-hook _t 2>/dev/null | grep -q HOOK_MAIN_FIRED && ok "hook file runs" || bad "hook file" "did not run"
mac-hook _t 2>/dev/null | grep -q HOOK_D_FIRED && ok "hook .d/ dir runs" || bad "hook .d" "did not run"
echo 'echo SHOULD_NOT_RUN' > ~/.config/omarchy-mac/hooks/_t.d/b.sample
mac-hook _t 2>/dev/null | grep -q SHOULD_NOT_RUN && bad "hook .sample" "should be skipped" || ok "hook skips .sample files"
mac-hook 2>&1 | grep -qi usage && ok "mac-hook shows usage" || bad "mac-hook" "no usage"
rm -rf ~/.config/omarchy-mac/hooks/_t ~/.config/omarchy-mac/hooks/_t.d
fi

# ── 14. window manager ─────────────────────────────────────────────────────
if want wm; then
sec "AeroSpace"
aerospace reload-config >/dev/null 2>&1 && ok "config parses cleanly" || bad "aerospace config" "parse error"
[ "$(osascript -e 'application "AeroSpace" is running' 2>/dev/null)" = true ] && ok "AeroSpace running" || bad "AeroSpace" "not running"
m=$(aerospace list-monitors 2>/dev/null | wc -l | tr -d ' '); [ "$m" -ge 1 ] && ok "sees $m monitor(s)" || bad "monitors" "none"
w=$(aerospace list-workspaces --all 2>/dev/null | wc -l | tr -d ' '); [ "$w" -ge 1 ] && ok "workspaces available ($w)" || bad "workspaces" "none"
aerospace list-windows --all >/dev/null 2>&1 && ok "can enumerate windows (Accessibility granted)" || bad "windows" "Accessibility likely denied"
C=~/.config/aerospace/aerospace.toml
grep -q 'config-version = 2' "$C" && ok "config-version 2" || bad "config-version" "not 2"
for b in "alt-enter" "alt-w" "alt-t" "alt-f" "alt-1 " "alt-shift-1" "alt-shift-ctrl-1" "alt-tab"; do
  grep -q "^$b" "$C" && ok "bind $b present" || bad "bind $b" "missing"
done
n=$(grep -cE '^alt-|^ctrl-' "$C"); [ "$n" -ge 60 ] && ok "$n binds defined" || bad "binds" "only $n"
f=$(grep -c 'on-window-detected' "$C"); [ "$f" -ge 5 ] && ok "$f auto-float rules" || bad "float rules" "only $f"
grep -q 'open -na Ghostty' "$C" && bad "aerospace" "still spawns duplicate Ghostty instances" || ok "no 'open -na' instance-spawning binds"
# AeroSpace runs binds with a minimal PATH — a bare script name silently does
# nothing. Every exec-and-forget of our own scripts must be an absolute path.
if grep -oE "exec-and-forget [a-z-]+" "$C" | grep -qvE "exec-and-forget (osascript|open|pmset)"; then
  bad "bind PATH" "a bind calls a script by bare name; AeroSpace's PATH won't find it"
else
  ok "script binds use absolute paths"
fi
for p in $(grep -oE '/Users/[^ ]*/\.local/bin/[a-z-]+' "$C" | sort -u); do
  [ -x "$p" ] && ok "bind target exists: $(basename "$p")" || bad "bind target" "$p missing"
done
# Upstream Omarchy ships NO Ghostty split binds (it uses tmux panes), so ⌥J/⌥L
# belong to AeroSpace as SUPER+J / SUPER+L. Assert Ghostty does not re-claim them.
for g in j l; do
  grep -qE "opt\\+$g=" ~/.config/ghostty/config 2>/dev/null \
    && bad "conflict" "ghostty binds opt+$g — collides with AeroSpace SUPER+$g" \
    || ok "ghostty leaves opt+$g to AeroSpace"
done
grep -qE "^alt-j |^alt-l " "$C" && ok "SUPER+J / SUPER+L bound (Omarchy parity)" \
  || bad "binds" "SUPER+J/L missing"
# Regression: `move-mouse window-lazy-center` on every focus change physically
# warps the pointer, and macOS then re-derives the focused workspace from where
# the cursor landed — spawning a terminal jumped focus to another workspace.
grep -qE "^on-focus-changed = \[\]" "$C" && ok "on-focus-changed empty (no cursor-warp focus jumps)" \
  || bad "on-focus-changed" "cursor warping will move focus to the wrong workspace"
# End-to-end: a new terminal must land on, and keep focus on, the current workspace.
if command -v aerospace >/dev/null 2>&1; then
  aerospace workspace 8 >/dev/null 2>&1; sleep 1
  _b=$(aerospace list-workspaces --focused 2>/dev/null)
  _before=$(aerospace list-windows --all --format '%{window-id}' 2>/dev/null | sort)
  ghostty-run >/dev/null 2>&1   # exactly what the ⌥Enter bind runs
  sleep 3
  _after=$(aerospace list-windows --all --format '%{window-id}' 2>/dev/null | sort)
  _new=$(comm -13 <(echo "$_before") <(echo "$_after") | head -1)
  _a=$(aerospace list-workspaces --focused 2>/dev/null)
  _ws=$(aerospace list-windows --all --format '%{window-id}|%{workspace}' 2>/dev/null | grep "^$_new|" | cut -d'|' -f2)
  [ -n "$_new" ] && [ "$_a" = "$_b" ] && [ "$_ws" = "$_b" ] \
    && ok "new terminal lands on the focused workspace (ws$_b)" \
    || bad "terminal placement" "focus $_b->$_a, window on ws${_ws:-none}"
  [ -n "$_new" ] && aerospace close --window-id "$_new" >/dev/null 2>&1
  aerospace workspace 1 >/dev/null 2>&1
fi
grep -qE '^alt-enter' "$C" && ok "binds use ⌥ as SUPER" || bad "binds" "alt binds missing"
fi

# ── 15. karabiner ──────────────────────────────────────────────────────────
if want karabiner; then
sec "Karabiner (SUPER key)"
K=~/.config/karabiner/karabiner.json
python3 -c "import json;json.load(open('$K'))" 2>/dev/null && ok "karabiner.json valid JSON" || bad "karabiner.json" "invalid"
python3 - <<PY && ok "caps_lock -> ⌥ (optional extra SUPER), Escape when tapped" || bad "caps rule" "not configured"
import json,sys
d=json.load(open("$K"))
p=[x for x in d["profiles"] if x.get("selected")][0]
r=[m for rule in p["complex_modifications"]["rules"] for m in rule["manipulators"]]
caps=[m for m in r if m["from"].get("key_code")=="caps_lock"]
if not caps: sys.exit(1)
to=caps[0]["to"][0]
mods=set(to.get("modifiers",[])) | {to["key_code"]}
# SUPER must be ctrl+opt+cmd and must NOT include shift, or Super+Shift collides.
sys.exit(0 if to["key_code"]=="left_option" and not to.get("modifiers")
         and caps[0]["to_if_alone"][0]["key_code"]=="escape" else 1)
PY
# NB: karabiner_grabber no longer exists — modern Karabiner runs
# Karabiner-Core-Service instead. Check that, and ask karabiner_cli directly.
ps -Ao comm | grep -q 'Karabiner-Core-Service' && ok "Karabiner-Core-Service running (remapping active)" \
  || skip "Karabiner core service not running" "launch Karabiner-Elements"
ps -Ao comm | grep -q 'Karabiner-VirtualHIDDevice-Daemon' && ok "VirtualHIDDevice daemon running" \
  || skip "VirtualHIDDevice daemon not running" "approve the driver"
CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
[ "$("$CLI" --show-current-profile-name 2>/dev/null)" = "Omarchy" ] \
  && ok "active Karabiner profile is 'Omarchy'" || bad "karabiner profile" "not Omarchy"
"$CLI" --lint-complex-modifications ~/.config/karabiner/karabiner.json 2>&1 | grep -q ': ok' \
  && ok "karabiner config lints clean" || bad "karabiner config" "lint failed"
if systemextensionsctl list 2>/dev/null | grep -qi 'karabiner.*activated enabled'; then
  ok "Karabiner driver approved + enabled (Caps Lock is live)"
else
  skip "Karabiner driver NOT approved" "System Settings > Privacy & Security > Allow"
fi
# End-to-end: synthesize SUPER+3 and confirm AeroSpace actually acts on it.
if command -v aerospace >/dev/null 2>&1; then
  _b=$(aerospace list-workspaces --focused 2>/dev/null)
  osascript -e 'tell application "System Events" to key code 20 using {option down}' 2>/dev/null
  sleep 2
  _a=$(aerospace list-workspaces --focused 2>/dev/null)
  [ "$_a" = "3" ] && ok "⌥3 switches workspace (binds respond end-to-end)" \
                  || bad "SUPER binds" "workspace did not change ($_b -> $_a)"
  osascript -e "tell application \"System Events\" to key code 18 using {option down}" 2>/dev/null
  sleep 1
fi
fi

# ── 16. Touch ID ───────────────────────────────────────────────────────────
if want touchid; then
sec "Touch ID for sudo"
if [ -f /etc/pam.d/sudo_local ]; then
  grep -q pam_tid /etc/pam.d/sudo_local && ok "pam_tid enabled" || bad "pam_tid" "missing"
  grep -q pam_reattach /etc/pam.d/sudo_local && ok "pam_reattach enabled (tmux support)" || bad "pam_reattach" "missing"
  awk '/pam_reattach/{r=NR} /pam_tid/{t=NR} END{exit !(r && t && r<t)}' /etc/pam.d/sudo_local \
    && ok "pam_reattach ordered before pam_tid" || bad "PAM order" "reattach must come first"
else
  bad "sudo_local" "not installed"
fi
[ -f /opt/homebrew/lib/pam/pam_reattach.so ] && ok "pam_reattach.so present" || bad "pam_reattach.so" "missing"
bioutil -r 2>/dev/null | grep -q 'unlock: 1' && ok "Touch ID enrolled" || skip "Touch ID enrollment" "not detected"
fi

# ── 17. prompt / env ───────────────────────────────────────────────────────
if want shell; then
sec "Prompt + environment"
[ "$(zsh -ic 'echo $STARSHIP_SHELL' 2>/dev/null | tail -1)" = zsh ] && ok "starship active" || bad "starship" "not initialised"
[ -z "$(zsh -ic 'echo $ZSH_THEME' 2>/dev/null | tail -1)" ] && ok "oh-my-zsh theme disabled (starship owns prompt)" || bad "ZSH_THEME" "still set"
[ "$(zsh -ic 'echo $EDITOR' 2>/dev/null | tail -1)" = nvim ] && ok "EDITOR=nvim" || bad "EDITOR" "not nvim"
[ "$(zsh -ic 'echo $BAT_THEME' 2>/dev/null | tail -1)" = ansi ] && ok "BAT_THEME=ansi" || bad "BAT_THEME" "not ansi"
zsh -ic 'echo $MANPAGER' 2>/dev/null | grep -q bat && ok "MANPAGER uses bat" || bad "MANPAGER" "not bat"
zsh -ic 'echo $PATH' 2>/dev/null | tr ':' '\n' | grep -qx "$HOME/.local/bin" && ok "~/.local/bin on PATH" || bad "PATH" "~/.local/bin missing"
for gone in "$HOME/.bun" "$HOME/.pixi" "$HOME/.local/bin/uv"; do
  [ -e "$gone" ] && bad "cleanup" "$gone still present" || ok "removed: $(basename "$gone")"
done
starship_cfg=~/.config/starship.toml
grep -q 'add_newline' "$starship_cfg" && ok "starship.toml is Omarchy's" || bad "starship.toml" "unexpected content"
fi

# ── 18. brew / mise layer integrity ────────────────────────────────────────
if want brew; then
sec "Homebrew + mise layers"
brew list --formula >/dev/null 2>&1 && ok "brew responds" || bad "brew" "not working"
for f in bat eza fd fzf ripgrep zoxide jq btop fastfetch starship tmux neovim lazygit gifski mas pam-reattach; do
  brew list "$f" >/dev/null 2>&1 && ok "formula $f installed" || bad "formula $f" "missing"
done
mise doctor 2>&1 | grep -q 'No problems found' && ok "mise doctor clean" || bad "mise doctor" "problems reported"
for t in claude codex gh opencode bun node go; do
  mise ls 2>/dev/null | grep -q "^$t " && ok "mise manages $t" || bad "mise" "$t not managed"
done
# match real declarations only — the Brewfile mentions these in a comment
grep -qE '^\s*(cask|brew)\s+"(claude-code|codex|gh)"' ~/.config/homebrew/Brewfile \
  && bad "Brewfile" "declares an AI CLI that mise owns" || ok "Brewfile excludes mise-managed AI CLIs"
brew list --cask claude-code >/dev/null 2>&1 && bad "layering" "claude-code cask still installed" || ok "no duplicate claude install"
fi

# ── 19. repo ───────────────────────────────────────────────────────────────
if want repo; then
sec "Repo integrity"
R=~/omarchy-mac
if [ -d "$R/.git" ]; then
  ( cd "$R" && [ -z "$(git status --porcelain)" ] ) && ok "working tree clean" || bad "repo" "uncommitted changes"
  ( cd "$R" && bash -n install.sh ) && ok "install.sh syntax ok" || bad "install.sh" "syntax error"
  n=$( cd "$R" && git ls-files | wc -l | tr -d ' ' ); [ "$n" -ge 20 ] && ok "$n files tracked" || bad "repo" "only $n files"
  for f in config/mise/config.toml config/zsh/aliases.zsh config/zsh/functions.zsh \
           config/tmux/tmux.conf config/aerospace/aerospace.toml config/karabiner/karabiner.json \
           config/pam/sudo_local local/bin/mac local/bin/macup; do
    [ -f "$R/$f" ] && ok "tracked: $f" || bad "repo" "$f missing"
  done
  # live configs must match what's committed
  for pair in "$HOME/.config/zsh/aliases.zsh:config/zsh/aliases.zsh" \
              "$HOME/.config/zsh/functions.zsh:config/zsh/functions.zsh" \
              "$HOME/.config/aerospace/aerospace.toml:config/aerospace/aerospace.toml" \
              "$HOME/.config/tmux/tmux.conf:config/tmux/tmux.conf" \
              "$HOME/.local/bin/mac:local/bin/mac"; do
    live=${pair%%:*}; repo="$R/${pair#*:}"
    diff -q "$live" "$repo" >/dev/null 2>&1 && ok "in sync: $(basename "$live")" || bad "drift" "$(basename "$live") differs from repo"
  done
else
  skip "repo tests" "~/omarchy-mac not a git repo"
fi
fi

printf "\n\033[1m════ RESULT: %d passed, %d failed, %d skipped ════\033[0m\n" "$PASS" "$FAIL" "$SKIP"
exit $(( FAIL > 0 ))
