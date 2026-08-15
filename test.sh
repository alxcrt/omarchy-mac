#!/bin/bash
# Real functional test suite — executes things, checks effects.
PASS=0; FAIL=0
ok()   { printf "  \033[0;32mPASS\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  \033[0;31mFAIL\033[0m %s — %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }
sec()  { printf "\n\033[1m%s\033[0m\n" "$1"; }

export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
T=$(mktemp -d)

sec "1. transcode — real media conversions"
magick -size 200x150 xc:red "$T/a.png" 2>/dev/null
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=duration=1:size=160x120:rate=10 "$T/a.mp4" 2>/dev/null
for combo in "jpg high" "jpg low" "png high"; do
  set -- $combo
  out=$(transcode "$T/a.png" "$1" "$2" 2>/dev/null | tail -1)
  [ -s "$out" ] && ok "transcode png->$1 ($2) = $(stat -f%z "$out")b" || bad "transcode png->$1 $2" "no output"
done
out=$(transcode "$T/a.mp4" mp4 720p 2>/dev/null | tail -1)
[ -s "$out" ] && ok "transcode mp4 720p = $(stat -f%z "$out")b" || bad "transcode mp4" "no output"
out=$(transcode "$T/a.mp4" gif 720p 2>/dev/null | tail -1)
[ -s "$out" ] && ok "transcode gif (gifski) = $(stat -f%z "$out")b" || bad "transcode gif" "no output"
transcode "$T/nope.png" jpg high >/dev/null 2>&1 && bad "transcode missing-file" "should have failed" || ok "transcode rejects missing file"

sec "2. compress / decompress"
mkdir -p "$T/dir" && echo payload > "$T/dir/f.txt"
( cd "$T" && zsh -ic 'source ~/.config/zsh/functions.zsh; compress dir' >/dev/null 2>&1 )
[ -s "$T/dir.tar.gz" ] && ok "compress -> $(stat -f%z "$T/dir.tar.gz")b" || bad "compress" "no tarball"
mkdir -p "$T/x" && tar -xzf "$T/dir.tar.gz" -C "$T/x" 2>/dev/null
[ "$(cat "$T/x/dir/f.txt" 2>/dev/null)" = payload ] && ok "decompress round-trip intact" || bad "decompress" "content mismatch"

sec "3. tmux layouts — real sessions"
tmux kill-session -t _q1 2>/dev/null
tmux new-session -d -s _q1 -x 200 -y 50 2>/dev/null
tmux send-keys -t _q1 "source ~/.config/zsh/functions.zsh && tdl 'echo ai'" C-m; sleep 2
n=$(tmux list-panes -t _q1 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = 3 ] && ok "tdl -> 3 panes" || bad "tdl" "got $n panes"
tmux kill-session -t _q1 2>/dev/null
tmux new-session -d -s _q2 -x 200 -y 50 2>/dev/null
tmux send-keys -t _q2 "source ~/.config/zsh/functions.zsh && tsl 5 'echo s'" C-m; sleep 2
n=$(tmux list-panes -t _q2 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = 5 ] && ok "tsl 5 -> 5 panes" || bad "tsl 5" "got $n panes"
tmux kill-session -t _q2 2>/dev/null
tmux new-session -d -s _q3 -x 220 -y 60 2>/dev/null
tmux send-keys -t _q3 "source ~/.config/zsh/functions.zsh && tds" C-m; sleep 2
n=$(tmux list-panes -t _q3 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = 4 ] && ok "tds -> 4 panes" || bad "tds" "got $n panes"
tmux kill-session -t _q3 2>/dev/null
p=$(tmux new-session -d -s _q4 2>/dev/null; tmux show-options -g prefix | awk '{print $2}'; tmux kill-session -t _q4 2>/dev/null)
[ "$p" = "C-Space" ] && ok "tmux prefix = C-Space" || bad "tmux prefix" "got $p"

sec "4. git worktree ga/gd"
mkdir -p "$T/repo" && ( cd "$T/repo" && git init -q . && git commit -q --allow-empty -m init 2>/dev/null )
( cd "$T/repo" && zsh -ic 'source ~/.config/zsh/functions.zsh; ga feature-x' >/dev/null 2>&1 )
[ -d "$T/repo--feature-x" ] && ok "ga created worktree ../repo--feature-x" || bad "ga" "worktree missing"
( cd "$T/repo" && git worktree remove "$T/repo--feature-x" --force 2>/dev/null; git branch -D feature-x 2>/dev/null ) >/dev/null 2>&1

sec "5. browser flows"
u=$(browser-url 2>/dev/null)
[ -n "$u" ] && ok "browser-url -> $u" || bad "browser-url" "empty"
weburl >/dev/null 2>&1 && [ "$(pbpaste)" = "$u" ] && ok "weburl copied to clipboard" || bad "weburl" "clipboard mismatch"
webdl "https://github.com/alxcrt/omarchy-mac" 2>&1 | grep -qi 'no video' && ok "webdl rejects non-video page" || bad "webdl non-video" "unexpected output"

sec "6. native messaging host (real protocol frames)"
python3 - <<'PY' && ok "native host copy-url mode works" || bad "native host" "protocol error"
import json,struct,subprocess,os,sys
h=os.path.expanduser("~/.local/bin/chromium-native-host")
def frame(o):
    d=json.dumps(o).encode(); return struct.pack('@I',len(d))+d
r=subprocess.run([h,"chrome-extension://bgpiichlckmfanooecilcjemknkcpngb/"],
    input=frame({"url":"https://example.com/suite-test"}),capture_output=True)
clip=subprocess.run(["pbpaste"],capture_output=True).stdout.decode()
sys.exit(0 if r.returncode==0 and clip=="https://example.com/suite-test" else 1)
PY

sec "7. mac CLI"
mac help >/dev/null 2>&1 && ok "mac help" || bad "mac help" "nonzero"
mac wm status >/dev/null 2>&1 && ok "mac wm status" || bad "mac wm status" "nonzero"
mac usage 2>/dev/null | grep -q CLAUDE && ok "mac usage reads real data" || bad "mac usage" "no data"
mac bogus >/dev/null 2>&1 && bad "mac bogus" "should fail" || ok "mac rejects unknown subcommand"

sec "8. hooks"
mkdir -p ~/.config/omarchy-mac/hooks/selftest.d
echo 'echo HOOK_FIRED' > ~/.config/omarchy-mac/hooks/selftest.d/x
mac-hook selftest 2>/dev/null | grep -q HOOK_FIRED && ok "mac-hook runs .d/ hooks" || bad "mac-hook" "did not fire"
rm -rf ~/.config/omarchy-mac/hooks/selftest.d

sec "9. window manager"
aerospace reload-config >/dev/null 2>&1 && ok "aerospace config parses" || bad "aerospace" "parse error"
[ "$(osascript -e 'application "AeroSpace" is running' 2>/dev/null)" = true ] && ok "aerospace running" || bad "aerospace" "not running"
[ "$(aerospace list-monitors 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ] && ok "aerospace sees monitors" || bad "aerospace monitors" "none"

sec "10. Touch ID / PAM"
grep -q pam_tid /etc/pam.d/sudo_local 2>/dev/null && ok "pam_tid configured" || bad "pam_tid" "missing"
grep -q pam_reattach /etc/pam.d/sudo_local 2>/dev/null && ok "pam_reattach (tmux support) configured" || bad "pam_reattach" "missing"
[ -f /opt/homebrew/lib/pam/pam_reattach.so ] && ok "pam_reattach.so present" || bad "pam_reattach.so" "missing"

sec "11. package layering"
for t in node claude codex gh bun opencode grok; do
  p=$(zsh -ic "command -v $t" 2>/dev/null)
  case "$p" in */mise/*) ok "$t -> mise";; *) bad "$t" "resolves to ${p:-nothing}";; esac
done

rm -rf "$T"
printf "\n\033[1mRESULT: %d passed, %d failed\033[0m\n" "$PASS" "$FAIL"
exit $(( FAIL > 0 ))
