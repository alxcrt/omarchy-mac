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
         hdl hds hdlm hsl _herdr_ratio _herdr_split \
         img2jpg img2png img2jpg-small img2jpg-medium img2jpg-large \
         transcode-video-1080p transcode-video-4K transcode-video-gif; do
  ZRUN "typeset -f $f >/dev/null" && ok "$f defined" || bad "$f" "not defined"
done
# both an alias AND a function of the same name must coexist where expected
ZRUN 'typeset -f ga >/dev/null' && ok "ga survives oh-my-zsh alias clash" || bad "ga" "clobbered by omz"
ZRUN 'typeset -f gd >/dev/null' && ok "gd survives oh-my-zsh alias clash" || bad "gd" "clobbered by omz"
# grep the CODE, not comments — the fix is documented in a comment that
# mentions the very string we're banning.
grep -vE '^\s*#' ~/.config/zsh/functions.zsh | grep -q 'pgrep -af' \
  && bad "lip" "uses GNU-only 'pgrep -af'" || ok "lip avoids the GNU-only pgrep -af"
for e in SUDO_EDITOR BROWSER; do
  [ -n "$(zsh -ic "echo \$$e" 2>/dev/null | tail -1)" ] && ok "$e exported" || bad "$e" "not set"
done
zsh -ic '[[ -o hash_cmds ]]' 2>/dev/null && bad "hash_cmds" "on — stale mise shims possible" || ok "hash_cmds off (mise shim correctness)"
zsh -ic 'bindkey' 2>/dev/null | grep -q fzf && ok "fzf widgets loaded (Ctrl-R/Ctrl-T)" || bad "fzf" "widgets not loaded"
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
  # NB: --global reads only ~/.gitconfig. Upstream's layering puts the managed
  # values in ~/.config/git/config, so query the merged view instead.
  got=$(git config --get "$k" 2>/dev/null)
  [ "$got" = "$want_v" ] && ok "git $k = $got" || bad "git $k" "got '$got' want '$want_v'"
done
[ -f ~/.config/git/config ] && ok "managed git config layer present" || bad "git layer" "~/.config/git/config missing"
grep -qE '^\s*(email|name) =' ~/.gitconfig 2>/dev/null && ok "~/.gitconfig holds identity only" || bad "gitconfig" "identity missing"
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
# Download flow: the host must relay live progress and a real file back, and
# the notification-button actions must refuse a path that isn't a file. Uses a
# 2.8MB sample rather than a stub, so the whole webdl/yt-dlp chain is exercised.
python3 - <<'DLPY' && ok "native host: streams download progress + done" || bad "native host download" "no progress/done relayed"
import json,struct,subprocess,os,sys,tempfile
h=os.path.expanduser("~/.local/bin/chromium-native-host")
def call(msg,env=None):
    d=json.dumps(msg).encode()
    p=subprocess.run([h],input=struct.pack("@I",len(d))+d,capture_output=True,
                     env={**os.environ,**(env or {})},timeout=180)
    out,msgs=p.stdout,[]
    while len(out)>=4:
        (n,)=struct.unpack("@I",out[:4]); msgs.append(json.loads(out[4:4+n])); out=out[4+n:]
    return msgs
with tempfile.TemporaryDirectory() as d:
    m=call({"url":"https://download.samplelib.com/mp4/sample-5s.mp4"},{"OMARCHY_YTDLP_DIR":d})
    prog=[x["progress"] for x in m if "progress" in x]
    done=[x for x in m if x.get("done")]
    ok_dl=bool(prog) and bool(done) and os.path.isfile(done[0]["path"])
guard = call({"action":"reveal","path":"/nope/not-a-file"}) == [{"ok":True}]
sys.exit(0 if ok_dl and guard else 1)
DLPY
chrome-extensions list >/dev/null 2>&1 && ok "chrome-extensions list runs" || bad "chrome-extensions list" "nonzero"
# Match the machine-readable status line, NOT prose: "NOT LOADED in any
# profile" contains the substring "LOADED in ", which false-passed twice.
if chrome-extensions verify 2>/dev/null | grep -qx 'STATUS=loaded'; then
  ok "extensions LOADED in Chrome"
else
  skip "extensions not loaded (per on-disk Preferences)" "load them, then quit Chrome once so it flushes Preferences"
fi
# ⌥⇧D / ⌥⇧L belong to the extensions. AeroSpace used to grab keys globally and
# shadow them; with it gone the only remaining global grabber is macOS itself,
# so assert no system-wide hotkey has claimed them (⌥⇧ mask = 1703936).
_sh=$(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null | tr -d ' \n')
printf '%s' "$_sh" | grep -q "enabled=1;value={parameters=(100,2,1703936)" \
  && bad "keybind conflict" "a macOS hotkey claims ⌥⇧D" || ok "⌥⇧D free for the Download Video extension"
printf '%s' "$_sh" | grep -q "enabled=1;value={parameters=(108,37,1703936)" \
  && bad "keybind conflict" "a macOS hotkey claims ⌥⇧L" || ok "⌥⇧L free for the Copy URL extension"
fi

# ── 11. mac CLI ────────────────────────────────────────────────────────────
if want mac; then
sec "mac CLI"
mac help >/dev/null 2>&1 && ok "mac help" || bad "mac help" "nonzero exit"
for s in update mise dl url transcode term wm doctor edit usage install; do
  mac help 2>/dev/null | grep -q "mac $s" && ok "mac help documents '$s'" || bad "mac help" "missing '$s'"
done
mac wm --status 2>/dev/null | grep -q 'EnableTiledWindowMargins' \
  && ok "mac wm reports native tiling settings" || bad "mac wm --status" "no tiling report"
mac usage 2>/dev/null | grep -q CLAUDE && ok "mac usage reads Claude data" || bad "mac usage" "no claude data"
mac usage 2>/dev/null | grep -q CODEX && ok "mac usage reads Codex data" || bad "mac usage" "no codex data"
mac bogus >/dev/null 2>&1 && bad "mac bogus" "should exit nonzero" || ok "mac rejects unknown subcommand"
mac edit bogus 2>&1 | grep -qi 'mac edit' && ok "mac edit validates target" || bad "mac edit" "no validation"
fi

# ── 12. helper scripts ─────────────────────────────────────────────────────
if want scripts; then
sec "Helper scripts"
for s in mac macup mise-install mac-keyremap mac-wm ghostty-run transcode webdl weburl browser-url \
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
sec "Window management (macOS native)"
# AeroSpace was dropped; a leftover install would fight the native tiler.
command -v aerospace >/dev/null 2>&1 && bad "aerospace" "CLI still on PATH" || ok "aerospace CLI gone"
[ -e /Applications/AeroSpace.app ] && bad "aerospace" "app still installed" || ok "AeroSpace.app removed"
[ -e "$HOME/.config/aerospace" ] && bad "aerospace" "~/.config/aerospace still present" \
  || ok "~/.config/aerospace removed"
grep -qi aerospace ~/.config/homebrew/Brewfile && bad "Brewfile" "still declares aerospace" \
  || ok "Brewfile no longer declares aerospace"

# The native tiler is configured entirely through defaults, so assert the
# defaults system actually holds the values — not that mac-wm printed them.
mac-wm --apply >/dev/null 2>&1
for k in EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag \
         EnableTilingOptionAccelerator EnableTiledWindowMargins; do
  [ "$(defaults read com.apple.WindowManager "$k" 2>/dev/null)" = "1" ] \
    && ok "WindowManager $k on" || bad "$k" "not enabled"
done

# ⌃1-9 -> Desktop 1-9 are symbolic hotkeys 118-126, off by Apple's default.
_sh=$(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null | tr -d ' \n')
_on=0
for i in 118 119 120 121 122 123 124 125 126; do
  printf '%s' "$_sh" | grep -q "$i={enabled=1;" && _on=$((_on+1))
done
[ "$_on" = 9 ] && ok "⌃1-9 switch-to-Desktop hotkeys enabled (9/9)" \
               || bad "space hotkeys" "only $_on of 9 enabled"
# ⌃1 must carry the ⌃ mask (262144) and the keycode for '1' (18).
printf '%s' "$_sh" | grep -q "118={enabled=1;value={parameters=(49,18,262144)" \
  && ok "⌃1 is bound to keycode 18 with the ⌃ mask" || bad "⌃1" "wrong parameters"

# Behaviour, not prose: the tiling menu Apple exposes must actually be there,
# since every documented shortcut hangs off it.
_mr=$(osascript -e 'tell application "System Events" to tell process "Finder" to return name of menu items of menu "Move & Resize" of menu item "Move & Resize" of menu "Window" of menu bar item "Window" of menu bar 1' 2>/dev/null)
printf '%s' "$_mr" | grep -q "Left" && ok "native Move & Resize menu present (tiling available)" \
  || skip "could not read the Move & Resize menu" "grant Accessibility to the terminal"

# mac-wm is the only place the native shortcuts are written down; mac-keys
# renders the same table, so a drift between them is a real bug.
mac-wm --keys --porcelain | grep -q '^Spaces (Mission Control)|⌃ 1..9|' \
  && ok "mac-wm exposes a machine-readable key table" || bad "mac-wm --porcelain" "table missing"
_a=$(mac-wm --keys --porcelain | wc -l | tr -d ' ')
_b=$(mac-keys | grep -cE '^  (fn ⌃|⌃ |drag )')
[ "$_a" = "$_b" ] && ok "mac-keys renders all $_a native shortcuts" \
                  || bad "mac-keys" "renders $_b of $_a native shortcuts"
mac-wm --status | grep -q 'Desktops that exist' && ok "mac-wm reports Spaces state" \
  || bad "mac-wm --status" "no Spaces report"
fi

# ── 15. modifier remap ─────────────────────────────────────────────────────
if want keyremap; then
sec "Modifier remap (hidutil, ex-Karabiner)"
LO=30064771298   # 0x7000000E2 left_option   CAPS=0x700000039  RCMD=0x7000000E7
CAPS=30064771129; RCMD=30064771303

# The assertion is the HID system's own state, not anything mac-keyremap prints.
_map() { hidutil property --get "UserKeyMapping" 2>/dev/null | tr -d ' \n'; }
_has() { _map | grep -q "MappingDst=$LO;HIDKeyboardModifierMappingSrc=$1;"; }

mac-keyremap --apply >/dev/null 2>&1
_has $CAPS && ok "Caps Lock is remapped to ⌥ in the HID system" || bad "keyremap" "caps lock not mapped to ⌥"
_has $RCMD && ok "Right ⌘ is remapped to ⌥ in the HID system"  || bad "keyremap" "right ⌘ not mapped to ⌥"

# Prove --clear/--apply actually mutate HID state (a print-only script passes
# every "does it exist" check and still does nothing).
mac-keyremap --clear >/dev/null 2>&1
_has $CAPS && bad "keyremap --clear" "mapping survived a clear" || ok "--clear really removes the mapping"
mac-keyremap --apply >/dev/null 2>&1
_has $CAPS && ok "--apply restores it (round-trip works)" || bad "keyremap --apply" "did not restore mapping"
mac-keyremap --show 2>/dev/null | grep -q "$LO" && ok "--show reports the live mapping" || bad "keyremap --show" "no mapping reported"

# The mapping is HID-system state and dies on reboot; the login agent is what
# makes it survive. Assert launchd actually holds it.
AGENT="$HOME/Library/LaunchAgents/com.omarchy.keyremap.plist"
plutil -lint "$AGENT" >/dev/null 2>&1 && ok "login agent plist is valid" || bad "keyremap agent" "plist invalid or missing"
diff -q "$AGENT" ~/omarchy-mac/config/launchd/com.omarchy.keyremap.plist >/dev/null 2>&1 \
  && ok "installed agent matches the repo copy" || bad "drift" "installed agent differs from repo"
launchctl print "gui/$UID/com.omarchy.keyremap" >/dev/null 2>&1 \
  && ok "login agent is bootstrapped in gui/$UID" \
  || bad "keyremap agent" "not loaded (launchctl bootstrap gui/$UID $AGENT)"

# Karabiner must be gone, not merely unused — a live Karabiner would silently
# fight hidutil for the same keys.
brew list --cask 2>/dev/null | grep -q karabiner && bad "karabiner" "cask still installed" \
  || ok "karabiner-elements cask removed"
[ -e /Applications/Karabiner-Elements.app ] && bad "karabiner" "app still present" \
  || ok "Karabiner-Elements.app removed"
[ -e "$HOME/.config/karabiner" ] && bad "karabiner" "~/.config/karabiner still present" \
  || ok "~/.config/karabiner removed"
# The DriverKit extension can only be reaped by macOS at reboot (SIP blocks
# systemextensionsctl uninstall), so a leftover is a pending reboot, not a fail.
if systemextensionsctl list 2>/dev/null | grep -qi 'karabiner.*activated'; then
  skip "Karabiner DriverKit extension still registered" "reboot — macOS reaps it once the app is gone"
else
  ok "Karabiner DriverKit extension gone"
fi

# End-to-end: the remap only matters if a remapped key really produces ⌥. Ask
# the HID system what modifiers a synthetic Caps Lock press carries.
_probe=$(osascript -e 'tell application "System Events" to key code 57' 2>&1)
[ -z "$_probe" ] && ok "a Caps Lock keypress is accepted (no caps-lock toggle)" \
                 || skip "could not synthesize Caps Lock" "grant Accessibility to the terminal"
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
  # tolerate a backend prefix (codex is npm:@openai/codex, not the aqua shortname)
  mise ls 2>/dev/null | grep -qE "(^|[:/])$t " && ok "mise manages $t" || bad "mise" "$t not managed"
done
# match real declarations only — the Brewfile mentions these in a comment
grep -qE '^\s*(cask|brew)\s+"(claude-code|codex|gh)"' ~/.config/homebrew/Brewfile \
  && bad "Brewfile" "declares an AI CLI that mise owns" || ok "Brewfile excludes mise-managed AI CLIs"
brew list --cask claude-code >/dev/null 2>&1 && bad "layering" "claude-code cask still installed" || ok "no duplicate claude install"
# THE core rule: nothing mise manages may also be installed by Homebrew.
# `brew upgrade` reinstalled opencode from a tap once and shadowed the mise one.
for t in $(mise ls --installed 2>/dev/null | awk '{print $1}' | sed 's|.*[:/]||'); do
  # `claude` is a name collision, not a layering breach: the cask is the Claude
  # DESKTOP app (/Applications/Claude.app, no CLI), while mise owns the Claude
  # Code CLI. The dangerous cask is claude-code, checked separately above.
  [ "$t" = claude ] && continue
  if brew list "$t" >/dev/null 2>&1 || brew list --cask "$t" >/dev/null 2>&1; then
    bad "layering" "$t is installed by BOTH brew and mise"
  fi
done
ok "no tool installed by both brew and mise"
# mise's tool paths must outrank ~/.local/bin, or shims lose to stale binaries.
env -i HOME="$HOME" TERM=xterm /bin/zsh -l -i -c 'mise doctor' 2>/dev/null | grep -q 'warnings found' \
  && bad "mise doctor" "warnings in a clean login shell (PATH order?)" \
  || ok "mise doctor clean in a fresh login shell"
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
           config/tmux/tmux.conf local/bin/mac-keyremap local/bin/mac-wm \
           config/launchd/com.omarchy.keyremap.plist \
           config/pam/sudo_local local/bin/mac local/bin/macup; do
    [ -f "$R/$f" ] && ok "tracked: $f" || bad "repo" "$f missing"
  done
  # live configs must match what's committed
  for pair in "$HOME/.config/zsh/aliases.zsh:config/zsh/aliases.zsh" \
              "$HOME/.config/zsh/functions.zsh:config/zsh/functions.zsh" \
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
