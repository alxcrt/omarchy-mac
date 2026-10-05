#!/bin/bash
# test.sh — real functional tests for the omarchy-mac setup.
# Every test executes something and checks its effect; nothing here just
# asserts a file exists. Safe to run any time: it works in a temp dir, uses
# throwaway git repos, and never runs macup or touches ~/Movies.
#
#   ./test.sh            run everything
#   ./test.sh <section>  run one section (e.g. ./test.sh herdr)

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
# ffp <file> <stream> <fields>: ffprobe one stream's fields as csv. Fields come
# back in ffprobe's own order (codec_name, width, height, pix_fmt), not the
# order asked for, so only compare combinations in that order.
ffp() { ffprobe -v error -select_streams "$2" -show_entries "stream=$3" -of csv=p=0 "$1"; }

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
check_alias ic 'hdl c'
check_alias ix 'hdl cx'
check_alias icx 'hdl c cx'
check_alias mup 'mise up'
check_alias cd 'zd'
check_alias decompress 'tar -xzf'
for a in ls lsa lt lta ff eff cx up macup; do check_alias "$a" ""; done
zsh -ic 'alias cx' 2>/dev/null | grep -q 'permission-mode auto' \
  && ok "cx uses --permission-mode auto (upstream)" || bad "cx" "wrong permission mode"
zsh -ic 'alias open' >/dev/null 2>&1 && bad "open" "must NOT be overridden on macOS" || ok "open left native (not overridden)"
fi

# ── 3. shell functions ─────────────────────────────────────────────────────
if want functions; then
sec "Shell functions defined"
for f in zd sff compress ga gd n fip dip lip \
         hdl hds hdlm hsl _herdr_ratio _herdr_split \
         img2jpg img2png img2jpg-small img2jpg-medium img2jpg-large \
         transcode-video-1080p transcode-video-4K transcode-video-gif; do
  ZRUN "typeset -f $f >/dev/null" && ok "$f defined" || bad "$f" "not defined"
done
# both an alias AND a function of the same name must coexist where expected
ZRUN 'typeset -f ga >/dev/null' && ok "ga defined (not shadowed by an alias)" || bad "ga" "clobbered by an alias"
ZRUN 'typeset -f gd >/dev/null' && ok "gd defined (not shadowed by an alias)" || bad "gd" "clobbered by an alias"
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
# mp4 share: the copy chat apps play inline. Fixtures are real 1s clips.
mk() { ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc=duration=1:size=$2:rate=24" -f lavfi -i sine=duration=1 "${@:3}" "$T/$1"; }
vp9=(-c:v libvpx-vp9 -deadline realtime -cpu-used 8 -c:a libopus)
mk s-vp9.mp4 640x360 "${vp9[@]}"; mk s-h264.mp4 640x360 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac
mk s-wide.mp4 2560x1440 "${vp9[@]}"; mk s-tall.mp4 1080x1920 "${vp9[@]}"
moovfirst() { /usr/bin/python3 - "$1" <<'PY2'
import struct, sys
f = open(sys.argv[1], 'rb'); seen = []
while True:
    h = f.read(8)
    if len(h) < 8: break
    size, kind = struct.unpack('>I4s', h); seen.append(kind)
    if size == 1: size = struct.unpack('>Q', f.read(8))[0]; f.seek(size - 16, 1)
    else: f.seek(size - 8, 1)
sys.exit(0 if b'moov' in seen and seen.index(b'moov') < seen.index(b'mdat') else 1)
PY2
}
out=$(transcode "$T/s-vp9.mp4" mp4 share 2>/dev/null | tail -1)
[ "$(ffp "$out" v:0 codec_name,pix_fmt)" = h264,yuv420p ] && [ "$(ffp "$out" a:0 codec_name)" = aac ] \
  && ok "share: VP9/Opus becomes H.264/AAC yuv420p" || bad "share" "got $(ffp "$out" v:0 codec_name,pix_fmt)/$(ffp "$out" a:0 codec_name)"
[ "$(ffp "$out" v:0 width,height)" = 640,360 ] && ok "share: small video is not upscaled" || bad "share" "size $(ffp "$out" v:0 width,height)"
moovfirst "$out" && ok "share: index (moov) before data, so previews stream" || bad "share" "moov after mdat (no faststart)"
out=$(transcode "$T/s-h264.mp4" mp4 share 2>/dev/null | tail -1)
[ "$(ffmpeg -v error -i "$out" -map 0:v -c copy -f md5 - 2>/dev/null)" = "$(ffmpeg -v error -i "$T/s-h264.mp4" -map 0:v -c copy -f md5 - 2>/dev/null)" ] \
  && ok "share: compliant H.264 is copied, not re-encoded" || bad "share" "re-encoded an already-compliant video"
out=$(transcode "$T/s-wide.mp4" mp4 share 2>/dev/null | tail -1)
[ "$(ffp "$out" v:0 width,height)" = 1920,1080 ] && ok "share: 1440p is scaled to 1080p" || bad "share" "1440p became $(ffp "$out" v:0 width,height)"
out=$(transcode "$T/s-tall.mp4" mp4 share 2>/dev/null | tail -1)
[ "$(ffp "$out" v:0 width,height)" = 1080,1920 ] && ok "share: portrait keeps its 1080 short side" || bad "share" "portrait became $(ffp "$out" v:0 width,height)"
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

# ── 7. herdr (replaced tmux) ──────────────────────────────────────────────
if want herdr; then
sec "herdr + layout functions"
command -v tmux >/dev/null 2>&1 && bad "tmux" "still installed; herdr replaced it" || ok "tmux is gone (herdr replaced it)"
herdr --version >/dev/null 2>&1 && ok "herdr runs ($(herdr --version 2>/dev/null | head -1))" || bad "herdr" "does not run"
# Unset HERDR_PANE_ID so these run as "outside herdr" even when the suite is
# itself launched from a herdr pane; otherwise hdl would really split panes.
ZRUN 'unset HERDR_PANE_ID; hdl' 2>&1 | grep -qi usage && ok "hdl shows usage with no args" || bad "hdl usage" "no usage text"
for f in hdl hdlm; do
  ZRUN "unset HERDR_PANE_ID; $f c" 2>&1 | grep -qi 'must start herdr' && ok "$f refuses outside herdr" || bad "$f guard" "no guard"
done
ZRUN 'unset HERDR_PANE_ID; hsl 3 x' 2>&1 | grep -qi 'must start herdr' && ok "hsl refuses outside herdr" || bad "hsl guard" "no guard"
ZRUN 'unset HERDR_PANE_ID; hds' 2>&1 | grep -qi 'must start herdr' && ok "hds refuses outside herdr" || bad "hds guard" "no guard"
mac-keys 2>/dev/null | grep -q 'split horizontal' && ok "mac-keys lists herdr's bindings" || bad "mac-keys" "no herdr section"
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
# (The wrapper is not run here: `mise use -g` would write jq into the global
# mise config, which is this repo's config.toml.)
[ -x ~/.local/bin/_ttjq ] && grep -q 'mise use -g --quiet jq' ~/.local/bin/_ttjq \
  && ok "mise-install wrapper is quiet (no 'tools:' line before the tool's output)" || bad "mise-install" "bad wrapper"
rm -f ~/.local/bin/_ttjq
for n in ../evil .hidden -x; do
  mise-install jq "$n" >/dev/null 2>&1 && bad "mise-install" "accepted command name '$n'" || ok "mise-install rejects command name '$n'"
done
# The release cooldown and prune policy live in mise's own config now, so a
# plain `mise up` behaves like mup/macup.
[ "$(mise settings get minimum_release_age 2>/dev/null)" = 0 ] && ok "mise config: minimum_release_age = 0" || bad "mise config" "release cooldown still on"
[ "$(mise settings get upgrade.auto_prune 2>/dev/null)" = false ] && ok "mise config: auto_prune off (live sessions keep their binary)" || bad "mise config" "auto_prune on"
grep -q 'softwareupdate --list' ~/.local/bin/macup && ok "macup only lists macOS updates (never installs)" || bad "macup" "may auto-install OS updates"
for s in "brew update" "brew upgrade" "mas update" "mise install" "mise up" "brew cleanup"; do
  grep -q "$s" ~/.local/bin/macup && ok "macup runs '$s'" || bad "macup" "missing '$s'"
done
grep -q 'mac-hook post-update' ~/.local/bin/macup && ok "macup fires post-update hook" || bad "macup" "no hook call"
# Behaviour, not grep: run macup against stubs that log their argv. brew fails
# on purpose, to prove one broken layer no longer skips the rest.
STUB="$T/macup-stubs"; LOG="$T/macup.log"; mkdir -p "$STUB"; : >"$LOG"
for c in brew mas mise softwareupdate mac-hook; do
  printf '#!/bin/bash\necho "%s $*" >>"%s"\n[ "%s $1" = "brew upgrade" ] && exit 1\nexit 0\n' "$c" "$LOG" "$c" >"$STUB/$c"
  chmod +x "$STUB/$c"
done
# mise reports two old claude versions; lsof says 1.1.0 is open by a running
# process (as a session started via installs/claude/latest would show).
cat >"$STUB/mise" <<EOF
#!/bin/bash
echo "mise \$*" >>"$LOG"
[ "\$1 \$2" = "ls --prunable" ] && printf '%s' '{"claude":[{"version":"1.0.0","install_path":"/x/mise/installs/claude/1.0.0","installed":true},{"version":"1.1.0","install_path":"/x/mise/installs/claude/1.1.0","installed":true}]}'
exit 0
EOF
printf '#!/bin/bash\nprintf "p42\\nn/x/mise/installs/claude/1.1.0/bin/claude\\n"\n' >"$STUB/lsof"
chmod +x "$STUB/mise" "$STUB/lsof"
PATH="$STUB:/usr/bin:/bin" ~/.local/bin/macup </dev/null >/dev/null 2>&1; rc=$?
grep -q '^mise uninstall claude@1.0.0' "$LOG" && ok "macup prunes an old tool version nothing is using" || bad "macup" "did not prune claude@1.0.0"
grep -q '^mise uninstall claude@1.1.0' "$LOG" && bad "macup" "pruned a version a running process has open" || ok "macup keeps a version a running session has open"
grep -q '^brew upgrade .*--yes' "$LOG" && ok "macup upgrades with --yes (never stalls at y/n)" || bad "macup" "brew upgrade without --yes"
grep -q '^mise up' "$LOG" && ok "macup still updates mise after a brew failure" || bad "macup" "brew failure skipped mise"
[ "$rc" -ne 0 ] && ok "macup exits non-zero when a step failed" || bad "macup" "hid a failed step"
# App Store: an app owned by another Apple Account pops a modal dialog on every
# update attempt. macup must try it once, report it under "Needs you" (not as
# a failure), and skip it on the next run. Developer's real ADAM ID is used so
# the receipt lookup runs against a real app.
cat >"$STUB/mas" <<EOF
#!/bin/bash
echo "mas \$*" >>"$LOG"
case \$1 in
  outdated) echo "640199958  Developer   (11.0.2 -> 11.1)" ;;
  update)   echo "Error: No downloads initiated for ADAM ID 640199958"; exit 1 ;;
esac
EOF
printf '#!/bin/bash\nexit 0\n' >"$STUB/sudo"; chmod +x "$STUB/mas" "$STUB/sudo"
for run in 1 2; do
  : >"$LOG"
  out=$(XDG_STATE_HOME="$T/state" PATH="$STUB:/usr/bin:/bin" ~/.local/bin/macup </dev/null 2>&1)
  n=$(grep -c '^mas update' "$LOG")
  if [ $run = 1 ]; then
    [ "$n" = 1 ] && ok "macup tries an outdated App Store app" || bad "macup mas" "first run: $n update calls"
  else
    [ "$n" = 0 ] && ok "macup skips a foreign-account app next run (no repeat dialog)" || bad "macup mas" "retried a foreign-account app"
  fi
  grep -q 'Developer (640199958) belongs to another Apple Account' <<<"$out" \
    && ok "run $run: foreign-account app reported under Needs you" || bad "macup mas" "run $run: not reported"
  sed -n '/^.*Failed:/,$p' <<<"$out" | grep -q 'mas update' \
    && bad "macup mas" "run $run: counted as a failure" || ok "run $run: foreign-account app is not a failure"
done
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
CAPS=30064771129; RCMD=30064771303; ESC=30064771113   # ESC=0x700000029

# The assertion is the HID system's own state, not anything mac-keyremap prints.
_map() { hidutil property --get "UserKeyMapping" 2>/dev/null | tr -d ' \n'; }
_has() { _map | grep -q "MappingDst=$2;HIDKeyboardModifierMappingSrc=$1;"; }

mac-keyremap --apply >/dev/null 2>&1
_has $CAPS $ESC && ok "Caps Lock is remapped to Escape in the HID system" || bad "keyremap" "caps lock not mapped to Escape"
_has $RCMD $LO  && ok "Right ⌘ is remapped to ⌥ in the HID system"  || bad "keyremap" "right ⌘ not mapped to ⌥"

# Prove --clear/--apply actually mutate HID state (a print-only script passes
# every "does it exist" check and still does nothing).
mac-keyremap --clear >/dev/null 2>&1
_has $CAPS $ESC && bad "keyremap --clear" "mapping survived a clear" || ok "--clear really removes the mapping"
mac-keyremap --apply >/dev/null 2>&1
_has $CAPS $ESC && ok "--apply restores it (round-trip works)" || bad "keyremap --apply" "did not restore mapping"
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
# No synthetic-keypress check here: System Events injects CGEvents above the
# HID layer, so hidutil never sees them and such a test proves nothing about
# the remap. The HID-state assertions above are the real check.
fi

# ── 16. Touch ID ───────────────────────────────────────────────────────────
if want touchid; then
sec "Touch ID for sudo"
if [ -f /etc/pam.d/sudo_local ]; then
  grep -q pam_tid /etc/pam.d/sudo_local && ok "pam_tid enabled" || bad "pam_tid" "missing"
  grep -q pam_reattach /etc/pam.d/sudo_local && ok "pam_reattach enabled (Touch ID in herdr/detached sessions)" || bad "pam_reattach" "missing"
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
# No oh-my-zsh: zshrc sets what it used to provide, at ~half the startup cost.
[ -z "$(zsh -ic 'echo ${ZSH:-}' 2>/dev/null | tail -1)" ] && ok "oh-my-zsh not loaded" || bad "zshrc" "oh-my-zsh still loaded"
[ -e "$HOME/.oh-my-zsh" ] && bad "cleanup" "~/.oh-my-zsh still present" || ok "~/.oh-my-zsh removed"
# Startup budget: the median of 7 interactive starts must stay under 100ms
# (oh-my-zsh + uncached inits was ~132ms; this zshrc is ~70ms).
ms=$(for i in 1 2 3 4 5 6 7; do /usr/bin/python3 -c 'import subprocess,time;t=time.time();subprocess.run(["zsh","-i","-c","exit"],capture_output=True);print(int((time.time()-t)*1000))'; done | sort -n | sed -n 4p)
[ "${ms:-999}" -lt 100 ] && ok "interactive zsh starts in ${ms}ms (<100)" || bad "startup" "${ms}ms (budget 100ms)"
SC="$HOME/.cache/zsh/starship.zsh"
[ -s "$SC" ] && ok "starship init is cached" || bad "starship cache" "missing"
grep -q '^RPROMPT=' "$SC" && bad "starship cache" "keeps an RPROMPT (a starship process per prompt)" || ok "no per-prompt RPROMPT process"
grep -q '^PROMPT2=.*%{' "$SC" && ok "PROMPT2 baked with zsh %{ %} escapes" || bad "starship cache" "PROMPT2 missing or unescaped"
[ "$(zsh -ic 'whence -w try' 2>/dev/null | tail -1)" = "try: function" ] && ok "try is a lazy shell function" || bad "try" "not defined"
zsh -ic 'bindkey "^[[A"' 2>/dev/null | grep -q history-beginning-search-backward && ok "↑ searches history by prefix (inputrc parity)" || bad "↑ binding" "not prefix search"
[ "$(zsh -ic 'whence -p git' 2>/dev/null | tail -1)" = /opt/homebrew/bin/git ] && ok "git is brew's (no xcrun stub)" || bad "git" "resolves to $(zsh -ic 'whence -p git' 2>/dev/null | tail -1)"
[ "$(zsh -ic 'echo $EDITOR' 2>/dev/null | tail -1)" = nvim ] && ok "EDITOR=nvim" || bad "EDITOR" "not nvim"
[ "$(zsh -ic 'echo $BAT_THEME' 2>/dev/null | tail -1)" = ansi ] && ok "BAT_THEME=ansi" || bad "BAT_THEME" "not ansi"
zsh -ic 'echo $MANPAGER' 2>/dev/null | grep -q bat && ok "MANPAGER uses bat" || bad "MANPAGER" "not bat"
zsh -ic 'echo $PATH' 2>/dev/null | tr ':' '\n' | grep -qx "$HOME/.local/bin" && ok "~/.local/bin on PATH" || bad "PATH" "~/.local/bin missing"
# ~/.bun/bin is the old curl installer. ~/.bun/install/cache is fine: it is the
# package cache the mise-managed bun itself writes, so ~/.bun reappears there.
for gone in "$HOME/.bun/bin" "$HOME/.pixi" "$HOME/.local/bin/uv"; do
  [ -e "$gone" ] && bad "cleanup" "$gone still present" || ok "removed: $(basename "$gone")"
done
starship_cfg=~/.config/starship.toml
grep -q 'add_newline' "$starship_cfg" && ok "starship.toml is Omarchy's" || bad "starship.toml" "unexpected content"
fi

# ── 18. brew / mise layer integrity ────────────────────────────────────────
if want brew; then
sec "Homebrew + mise layers"
brew list --formula >/dev/null 2>&1 && ok "brew responds" || bad "brew" "not working"
for f in git bat eza fd fzf ripgrep zoxide jq gum try cliamp btop fastfetch starship neovim lazygit gifski mas pam-reattach; do
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

# ── macOS defaults ─────────────────────────────────────────────────────────
if want defaults; then
sec "macOS defaults (key repeat, Finder, Dock)"
# Sandboxed first: a stub `defaults` backed by a temp file and a stub `killall`
# that logs, so drift detection and --apply are exercised for real without
# touching this Mac's preferences.
DS="$T/defaults-stub"; mkdir -p "$DS" "$T/dhome"; DB="$T/defaults.db"; KL="$T/killall.log"; : >"$DB"; : >"$KL"
cat >"$DS/defaults" <<EOF
#!/bin/bash
op=\$1 dom=\$2 key=\$3 val=\$5
case \$op in
  read)  v=\$(grep "^\$dom \$key=" "$DB" | tail -1 | cut -d= -f2); [ -n "\$v" ] && echo "\$v" || exit 1 ;;
  write) [ "\$val" = true ] && val=1; [ "\$val" = false ] && val=0; echo "\$dom \$key=\$val" >>"$DB" ;;
esac
EOF
printf '#!/bin/bash\necho "$*" >>"%s"\n' "$KL" >"$DS/killall"; chmod +x "$DS/defaults" "$DS/killall"
MD() { HOME="$T/dhome" PATH="$DS:/usr/bin:/bin" ~/.local/bin/mac-defaults "$@"; }
MD --status >/dev/null 2>&1 && bad "mac-defaults" "unset prefs reported as fine" || ok "--status flags unset prefs (exit 1)"
MD --apply >/dev/null 2>&1
MD --status >/dev/null 2>&1 && ok "--apply makes --status clean" || bad "mac-defaults --apply" "drift remains after apply"
grep -q Dock "$KL" && grep -q Finder "$KL" && ok "--apply restarts Dock and Finder after changing them" || bad "mac-defaults" "did not restart Dock/Finder"
[ -d "$T/dhome/Developer" ] && ok "--apply creates ~/Developer" || bad "mac-defaults" "no ~/Developer"
: >"$KL"; MD --apply >/dev/null 2>&1
[ -s "$KL" ] && bad "mac-defaults" "restarts Dock/Finder with nothing to change" || ok "a second --apply changes nothing and restarts nothing"
# Then the real Mac, read straight from cfprefs rather than through the script.
for kv in "-g InitialKeyRepeat 15" "-g KeyRepeat 1" "com.apple.finder AppleShowAllFiles 1" \
          "com.apple.finder ShowPathbar 1" "com.apple.finder ShowStatusBar 1" \
          "com.apple.dock autohide 1" "com.apple.dock autohide-delay 0" "com.apple.dock autohide-time-modifier 0"; do
  set -- $kv
  [ "$(defaults read "$1" "$2" 2>/dev/null)" = "$3" ] && ok "live: $2 = $3" || bad "live default" "$2 is $(defaults read "$1" "$2" 2>&1), want $3"
done
fi

# ── notifications ──────────────────────────────────────────────────────────
if want notify; then
sec "Notifications (mac-notify -> terminal-notifier)"
/opt/homebrew/bin/terminal-notifier -version >/dev/null 2>&1 && ok "terminal-notifier installed" || bad "terminal-notifier" "missing"
# A stub records the argv mac-notify would hand terminal-notifier, one per
# line; when buttons are offered it "presses" $STUB_CHOICE, as the real one
# prints the chosen button. A fake `open` logs what it was asked to reveal.
NS="$T/tn-stub"; NL="$T/tn.log"; OL="$T/open.log"
cat >"$NS" <<EOF
#!/bin/bash
printf '%s\n' "\$@" >"$NL"
for a; do [ "\$a" = -action ] && { printf '%s\n' "\${STUB_CHOICE:-@CLOSED}"; break; }; done
EOF
chmod +x "$NS"
mkdir -p "$T/openstub"; printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s"\n' "$OL" >"$T/openstub/open"; chmod +x "$T/openstub/open"
# Buttons are answered in the background; wait (≤3s) for $1 to become true.
settle() { for i in $(seq 30); do eval "$1" && return 0; sleep 0.1; done; return 1; }
N() { MAC_NOTIFY_BIN="$NS" ~/.local/bin/mac-notify "$@"; }
touch "$T/shot.png"; N "Transcode complete" "shot.png" "$T/shot.png"
grep -qx -- '-execute' "$NL" && ok "clicking a file notification runs a command" || bad "mac-notify" "no -execute for a file"
grep -qx -- '-contentImage' "$NL" && ok "image results attach a thumbnail" || bad "mac-notify" "no thumbnail for a .png"
N "Copied URL" "https://example.com"
grep -qx -- '-execute' "$NL" && bad "mac-notify" "click action without a file" || ok "no click action when there is no file"
N "Title" "-looks-like-a-flag"
grep -qxF -- '\-looks-like-a-flag' "$NL" && ok "a message starting with - is escaped" || bad "mac-notify" "leading - not escaped"
# The click command goes through sh -c: a path with a quote and spaces must
# reach `open -R` intact (stub `open` prints its last argument).
f="$T/it's a clip.mp4"; touch "$f"; N "Download complete" "x" "$f"
cmd=$(grep -A1 -x -- '-execute' "$NL" | tail -1)
mkdir -p "$T/ostub"; printf '#!/bin/sh\nfor a; do last=$a; done; printf "%%s\\n" "$last"\n' >"$T/ostub/open"; chmod +x "$T/ostub/open"
[ "$(PATH="$T/ostub:$PATH" sh -c "$cmd")" = "$f" ] && ok "click reveals the exact file (quotes/spaces survive)" || bad "mac-notify" "click command mangles the path"
# osascript notifications open Script Editor when clicked; none may remain.
left=$(grep -l 'display notification' ~/.local/bin/webdl ~/.local/bin/weburl ~/.local/bin/transcode-pick ~/.local/bin/chromium-native-host 2>/dev/null)
[ -z "$left" ] && ok "no script posts osascript notifications" || bad "notifications" "still osascript: $left"
# mac-clip puts the FILE on the pasteboard (as Finder's ⌘C does), checked on a
# private named pasteboard so the real clipboard is never touched.
PB="omarchy-test-$$"
pbfile() { osascript -l JavaScript -e 'ObjC.import("AppKit"); function run(a){ const u=$.NSPasteboard.pasteboardWithName(a[0]).readObjectsForClassesOptions($.NSArray.arrayWithObject($.NSURL),$.NSDictionary.dictionary); return u.count ? ObjC.unwrap(u.objectAtIndex(0).path) : ""; }' "$PB" 2>/dev/null; }
MAC_CLIP_PASTEBOARD=$PB ~/.local/bin/mac-clip "$T/shot.png" && [ "$(pbfile)" = "$T/shot.png" ] \
  && ok "mac-clip puts the file itself on the pasteboard" || bad "mac-clip" "pasteboard holds '$(pbfile)'"
MAC_CLIP_PASTEBOARD=$PB ~/.local/bin/mac-clip "$T/nope.mp4" 2>/dev/null && bad "mac-clip" "accepted a missing file" || ok "mac-clip rejects a missing file"
# End to end: webdl against a fake yt-dlp. A finished download offers Show and
# Copy buttons: Copy puts the file on the pasteboard, Show reveals it.
YS="$T/ytdlp-stub"; mkdir -p "$YS" "$T/dl"
# What yt-dlp often really saves: VP9 + Opus inside .mp4.
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=duration=1:size=320x240:rate=24 -f lavfi -i sine=duration=1 \
  -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -c:a libopus "$T/fixture.mp4"
pbclear() { osascript -l JavaScript -e 'ObjC.import("AppKit"); function run(a){ $.NSPasteboard.pasteboardWithName(a[0]).clearContents; }' "$PB" >/dev/null 2>&1; }
# The stub's behaviour comes from YTMODE: ok (a video), none (a page with no
# video: prints nothing, exits 0, like the YouTube homepage), fail (download
# errors out), hang (download never finishes).
cat >"$YS/yt-dlp" <<EOF
#!/bin/bash
for a; do
  if [ "\$a" = --simulate ]; then
    [ "\${YTMODE:-ok}" = none ] || printf 'abc\tTest clip\n'; exit 0
  fi
done
case "\${YTMODE:-ok}" in fail) exit 1 ;; hang) sleep 30 & wait ;; esac
p="$T/dl/Test_clip [abc].mp4"; cp "$T/fixture.mp4" "\$p"; echo "\$p"
EOF
chmod +x "$YS/yt-dlp"
W() { PATH="$T/openstub:$YS:$PATH" OMARCHY_YTDLP_DIR="$T/dl" MAC_CLIP_PASTEBOARD=$PB MAC_NOTIFY_BIN="$NS" ~/.local/bin/webdl "$@"; }
F="$T/dl/Test_clip [abc].mp4"
pbclear; s0=$(date +%s); STUB_CHOICE=@CLOSED W "https://example.com/v" >/dev/null 2>&1
[ $(( $(date +%s) - s0 )) -lt 5 ] && ok "webdl returns without waiting for a click" || bad "webdl" "blocked on the notification"
grep -qx 'Download complete' "$NL" && grep -qx 'Show,Copy' "$NL" \
  && ok "finished download offers Show and Copy buttons" || bad "webdl" "notification: $(tr '\n' ' ' <"$NL")"
grep -qx 'Test clip' "$NL" && ok "notification shows the video title, not the filename" || bad "webdl" "no title in: $(tr '\n' ' ' <"$NL")"
[ -z "$(pbfile)" ] && ok "nothing is copied unless Copy is pressed" || bad "webdl" "copied without asking"
STUB_CHOICE=Copy W "https://example.com/v" >/dev/null 2>&1
SF="$T/dl/Test_clip [abc]-share.mp4"
settle '[ "$(pbfile)" = "$SF" ]' && ok "Copy puts a share-ready copy on the pasteboard" || bad "webdl Copy" "pasteboard holds '$(pbfile)'"
[ "$(ffp "$SF" v:0 codec_name)" = h264 ] && [ -s "$F" ] && ok "the share copy is H.264 and the original is kept" || bad "webdl Copy" "share copy: $(ffp "$SF" v:0 codec_name)"
grep -qx 'Copied · ready to paste' "$NL" && ok "Copy confirms with a notification" || bad "webdl Copy" "last notification: $(tr '\n' ' ' <"$NL")"
: >"$OL"; STUB_CHOICE=Show W "https://example.com/v" >/dev/null 2>&1
settle 'grep -qxF -- "-R $F" "$OL"' && ok "Show reveals the file in Finder" || bad "webdl Show" "open got: $(cat "$OL")"
: >"$OL"; STUB_CHOICE=@ACTIONCLICKED W "https://example.com/v" >/dev/null 2>&1
settle 'grep -qxF -- "-R $F" "$OL"' && ok "clicking the notification body also reveals it" || bad "webdl click" "open got: $(cat "$OL")"
rm -f "$T/dl/"*; YTMODE=none W "https://www.youtube.com/" >/dev/null 2>&1
grep -qx 'No video found for download' "$NL" && [ -z "$(ls "$T/dl")" ] \
  && ok "a page with no video (exit 0, no ID) is rejected" || bad "webdl" "accepted a page with no video"
YTMODE=fail W "https://example.com/v" >/dev/null 2>&1
grep -qx 'Download failed' "$NL" && ok "a failing download says so (pipefail no longer exits early)" || bad "webdl" "no failure notification: $(tr '\n' ' ' <"$NL")"
( YTMODE=hang W "https://example.com/v" >/dev/null 2>&1 ) & wpid=$!
sleep 2; pkill -TERM -f "$HOME/.local/bin/webdl https://example.com/v" 2>/dev/null; wait $wpid 2>/dev/null
grep -qx -- '-remove' "$NL" && ok "a killed run removes its \"Downloading…\" notification" || bad "webdl" "killed run left: $(tr '\n' ' ' <"$NL")"
pkill -f "$YS/yt-dlp" 2>/dev/null
osascript -l JavaScript -e 'ObjC.import("AppKit"); function run(a){ $.NSPasteboard.pasteboardWithName(a[0]).releaseGlobally; }' "$PB" 2>/dev/null
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
           config/herdr/config.toml local/bin/mac-keyremap local/bin/mac-wm \
           config/launchd/com.omarchy.keyremap.plist \
           config/pam/sudo_local local/bin/mac local/bin/macup; do
    [ -f "$R/$f" ] && ok "tracked: $f" || bad "repo" "$f missing"
  done
  # Every path install.sh links must still BE a symlink into the repo. A
  # content diff isn't enough: a plain copy matches until the next commit, then
  # silently stays behind (a stale macup kept prompting y/n this way).
  # Repair with: ~/omarchy-mac/install.sh --links
  # (process substitution, not a pipe: a piped loop's ok/bad counts are lost)
  while read -r src dest; do
    [ "$(readlink "$HOME/$dest")" = "$R/$src" ] && ok "linked: ~/$dest" \
      || bad "drift" "~/$dest is not a symlink to the repo (install.sh --links)"
  done < <(grep -E '^link ' "$R/install.sh" | awk '{print $2, $3}'
           for f in "$R"/local/bin/*; do echo "local/bin/${f##*/} .local/bin/${f##*/}"; done)
else
  skip "repo tests" "~/omarchy-mac not a git repo"
fi
fi

printf "\n\033[1m════ RESULT: %d passed, %d failed, %d skipped ════\033[0m\n" "$PASS" "$FAIL" "$SKIP"
exit $(( FAIL > 0 ))
