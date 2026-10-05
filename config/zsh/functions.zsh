# ~/.config/zsh/functions.zsh
# Omarchy's shell functions, ported to zsh (basecamp/omarchy default/bash/fns).
# NOTE: zsh arrays are 1-indexed, so bash's ${panes[0]} becomes ${panes[1]}.
# Sourced from ~/.zshrc.
#
# In zsh you cannot define a function whose name is an existing alias — it's a
# parse error that aborts sourcing the rest of this file. oh-my-zsh's git
# plugin used to alias `ga`/`gd`; it is gone, but drop them defensively.
unalias ga gd 2>/dev/null || true

# ── Compression ────────────────────────────────────────────────────────────
compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }

# ── Git worktrees ──────────────────────────────────────────────────────────
# ga <branch> — add a worktree as ../<repo>--<branch> and cd into it
ga() {
  if [[ -z "$1" ]]; then
    echo "Usage: ga [branch name]"
    return 1
  fi

  local branch="$1"
  local base="$(basename "$PWD")"
  local wt_path="../${base}--${branch}"

  git worktree add -b "$branch" "$wt_path"
  mise trust "$wt_path"
  cd "$wt_path"
}

# gd — remove the worktree you are standing in, and its branch.
# Hardened vs upstream: upstream derives root/branch from `basename $PWD` and
# runs `worktree remove --force` + `branch -D` on that guess, so a plain
# directory named `notes--drafts` would nuke branch `drafts` in ../notes.
# It also used `cd`, which is aliased to zd() here — on a bad path zoxide
# fuzzy-jumps to an unrelated directory and returns 0, so the force-remove ran
# against a repo the user never named. Everything below is git-verified and
# uses `builtin cd`.
gd() {
  local wt root branch
  wt=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git worktree"; return 1; }
  if [[ $(git rev-parse --git-common-dir) == $(git rev-parse --git-dir) ]]; then
    echo "refusing: this is the main checkout, not a linked worktree"; return 1
  fi
  branch=$(git symbolic-ref --quiet --short HEAD) || { echo "detached HEAD; refusing"; return 1; }

  git status --short
  echo "worktree: $wt"
  echo "branch:   $branch"
  if command -v gum >/dev/null 2>&1; then
    gum confirm "Remove THIS worktree and branch '$branch'? (discards the above)" || return 0
  else
    local confirm
    read "confirm?Remove worktree '$wt' and branch '$branch'? [y/N] "
    [[ "$confirm" == [yY]* ]] || return 0
  fi

  root=$(git rev-parse --path-format=absolute --git-common-dir); root=${root:h}
  builtin cd "$root" || return 1
  git worktree remove "$wt" --force || return 1
  git branch -D -- "$branch"
}

# ── Transcoding (Omarchy wrappers; `transcode` is the macOS port) ──────────
transcode-video-1080p() { transcode "$1" mp4 1080p; }
transcode-video-4K()    { transcode "$1" mp4 4k; }
transcode-video-gif()   { transcode "$1" gif 1080p; }
img2jpg()               { transcode "$1" jpg high; }
img2jpg-small()         { transcode "$1" jpg low; }
img2jpg-medium()        { transcode "$1" jpg medium; }
img2jpg-large()         { transcode "$1" jpg high; }
img2png()               { transcode "$1" png high; }

# ── SSH port forwarding (upstream fns/ssh-port-forwarding) ─────────────────
fip() {
  (( $# < 2 )) && echo "Usage: fip <host> <port1> [port2] ..." && return 1
  local host="$1"
  shift
  for port in "$@"; do
    ssh -f -N -L "${port}:localhost:${port}" "$host" && echo "Forwarding localhost:$port -> $host:$port"
  done
}

dip() {
  (( $# == 0 )) && echo "Usage: dip <port1> [port2] ..." && return 1
  for port in "$@"; do
    pkill -f "ssh.*-L ${port}:localhost:${port}" && echo "Stopped forwarding port $port" || echo "No forwarding on port $port"
  done
}

lip() {
  # Upstream uses `pgrep -af`, which is a GNU-ism: on macOS -a means "include
  # process ancestors", not "print the command line", so it printed bare PIDs
  # and could match the caller's own shell.
  ps -axo pid,command | grep -E 'ssh .*-L [0-9]+:localhost:[0-9]+' | grep -v grep \
    || echo "No active forwards"
}

# ── Rsync-on-change watchers (upstream fns/rsyncing) ──────────────────────
# rsw <source> <destination> — sync once, then again on every change, in the
# background. lsw lists the watches, dsw stops them all.
# macOS: fswatch replaces inotifywait (-o: one line per batch of events; -l 0.2:
# batch every 0.2s instead of 1s, so a change syncs, and dsw stops it, sooner), and
# perl's POSIX::setsid replaces `setsid --fork`: the watcher leads its own
# session, so it survives the terminal and dsw can kill its whole group.
rsw() {
  (( $# != 2 )) && echo "Usage: rsw <source> <destination>" && return 1
  local src="${1%/}" dest="$2"
  # Reuse one SSH connection per login, so 1Password only prompts once.
  local sockets="${XDG_RUNTIME_DIR:-$HOME/.ssh/sockets}"
  mkdir -p "$sockets"
  local rsh="ssh -o ControlMaster=auto -o ControlPath=$sockets/rsw-%r@%h:%p -o ControlPersist=yes"
  RSYNC_RSH="$rsh" perl -MPOSIX -e 'fork and exit; POSIX::setsid(); exec @ARGV' \
    bash -c 'rsync -a "$1/" "$2"; fswatch -o -r -l 0.2 "$1" | while read -r _; do rsync -a "$1/" "$2"; done' \
    rsw-watch "$src" "$dest" >/dev/null 2>&1 </dev/null
  echo "Watching $src -> $dest"
}

lsw() {
  local pid cmd rest found=0
  # pgrep -fl, not upstream's -af: on macOS -a means "include ancestors".
  while read -r pid cmd; do
    rest="${cmd##*rsw-watch }"
    echo "$pid: ${rest% *} -> ${rest##* }"
    found=1
  done < <(pgrep -fl 'rsw-watch ')
  (( found )) || echo "No active watches"
}

dsw() {
  local pid found=0
  for pid in $(pgrep -f 'rsw-watch '); do
    kill -- -"$pid" 2>/dev/null && echo "Stopped watch (pid $pid)" && found=1
  done
  (( found )) || echo "No active watches"
}

# ── Drives (upstream fns/drives), rewritten for diskutil ───────────────────
# On a Mac the wrong /dev/diskN is the internal SSD, so only whole, external,
# physical disks are ever offered or accepted, read from diskutil's plists
# (not its prose), and both commands confirm with the disk's name and size.

# _external_disks — one line per external physical whole disk:
#   diskN<TAB>size<TAB>name
_external_disks() {
  local d info
  for d in $(diskutil list -plist external physical 2>/dev/null |
             plutil -extract WholeDisks json -o - - 2>/dev/null | jq -r '.[]?'); do
    info=$(diskutil info -plist "/dev/$d" 2>/dev/null) || continue
    printf '%s\t%s\t%s\n' "$d" \
      "$(plutil -extract TotalSize raw -o - - <<<"$info" | awk '{ printf "%.1f GB", $1 / 1e9 }')" \
      "$(plutil -extract MediaName raw -o - - <<<"$info")"
  done
}

# _drive_check <disk> — print diskN if it is an external physical whole disk.
_drive_check() {
  local d=${1#/dev/}; d=${d#r}   # disk4, /dev/disk4 and /dev/rdisk4 all mean disk4
  if [[ $d != disk<-> ]]; then
    echo "Give a whole disk like disk4, not '$1'" >&2; return 1
  fi
  if ! _external_disks | cut -f1 | grep -qx "$d"; then
    echo "/dev/$d is not an external physical disk; refusing. See: diskutil list external physical" >&2
    return 1
  fi
  echo "$d"
}

_drive_confirm() {
  if command -v gum >/dev/null; then gum confirm "$1"; else
    local confirm; read "confirm?$1 (y/N): "; [[ $confirm == [yY]* ]]; fi
}

# iso2sd <image> [disk] — write an image to an SD card or USB stick. Plain
# images go straight through dd; .gz/.xz/.zst/.zip stream-decompress to it.
iso2sd() {
  if (( $# < 1 )); then
    echo "Usage: iso2sd <image> [disk]"
    echo "Example: iso2sd ~/Downloads/ROCKNIX.img.gz disk4"
    echo; echo "External disks:"; _external_disks
    return 1
  fi
  local img=$1 disk=${2:-}
  [[ -f $img ]] || { echo "No such image: $img"; return 1; }

  if [[ -z $disk ]]; then
    local -a disks=("${(@f)$(_external_disks)}")
    disks=(${disks:#})
    (( $#disks )) || { echo "No external disk found and no disk given"; return 1; }
    if (( $#disks == 1 )); then
      disk=${disks[1]%%$'\t'*}
    else
      disk=$(printf '%s\n' "${disks[@]}" | gum choose --header "Write $(basename "$img") to:" | cut -f1)
    fi
    [[ -n $disk ]] || { echo "No disk selected"; return 1; }
  fi
  disk=$(_drive_check "$disk") || return 1
  local desc=$(_external_disks | awk -F'\t' -v d="$disk" '$1 == d { print $2 ", " $3 }')

  _drive_confirm "ERASE /dev/$disk ($desc) and write $(basename "$img") to it?" || return 1
  diskutil unmountDisk "/dev/$disk" || return 1
  # /dev/rdiskN (raw) skips the buffer cache: several times faster. For a pipe,
  # obs=4m makes dd collect whole blocks, since a raw disk rejects writes that
  # aren't sector-aligned.
  case $img in
    *.gz)  gzip -dc -- "$img"  | sudo dd of="/dev/r$disk" ibs=64k obs=4m status=progress ;;
    *.xz)  xz -dc -- "$img"    | sudo dd of="/dev/r$disk" ibs=64k obs=4m status=progress ;;
    *.zst) zstd -dc -- "$img"  | sudo dd of="/dev/r$disk" ibs=64k obs=4m status=progress ;;
    *.zip) unzip -p -- "$img"  | sudo dd of="/dev/r$disk" ibs=64k obs=4m status=progress ;;
    *)     sudo dd if="$img" of="/dev/r$disk" bs=4m status=progress ;;
  esac || { echo "Write failed"; return 1; }
  sync
  diskutil eject "/dev/$disk"
}

# format-drive <disk> <name> — one exFAT partition over the whole disk (GPT),
# which is what upstream's wipefs/dd/parted/mkfs.exfat sequence produces.
format-drive() {
  if (( $# != 2 )); then
    echo "Usage: format-drive <disk> <name>"
    echo "Example: format-drive disk4 'My Stuff'"
    echo; echo "External disks:"; _external_disks
    return 1
  fi
  local disk; disk=$(_drive_check "$1") || return 1
  local desc=$(_external_disks | awk -F'\t' -v d="$disk" '$1 == d { print $2 ", " $3 }')
  echo "WARNING: This will completely erase all data on /dev/$disk ($desc) and label it '$2'."
  local confirm; read "confirm?Are you sure you want to continue? (y/N): "
  [[ $confirm == [yY]* ]] || return 1
  diskutil eraseDisk ExFAT "$2" GPT "/dev/$disk" && echo "Drive /dev/$disk formatted as exFAT and labeled '$2'."
}

# ── SSH reconnect (upstream fns/ssh-reconnect) ─────────────────────────────
# Wrap ssh to clean up the terminal and reconnect when a connection drops.
#
# A remote herdr, tmux, or editor arms terminal modes over the SSH pipe (mouse
# tracking, focus reporting, the alternate screen) that only it can disarm. If
# the connection dies instead of exiting cleanly, those modes stay armed on the
# local terminal, and every mouse move floods the prompt with escape junk.
ssh() {
  local rc started

  started=$SECONDS
  command ssh "$@"
  rc=$?

  [[ -t 1 ]] || return $rc
  _ssh_disarm

  # Reconnect only when an interactive session drops: ssh exits 255 for
  # transport failures, but a fast 255 with no established session is a
  # connect/auth failure, a remote command's own 255 passes through
  # indistinguishably and must not replay its side effects, and redirected
  # stdin would feed the remaining piped input to a fresh remote shell.
  if (( rc != 255 )) || [[ ! -t 0 ]] || ! _ssh_interactive "$@" ||
    (( SECONDS - started < 30 )); then
    return $rc
  fi

  # Retry in a subshell: Ctrl-C reaches the whole foreground process group,
  # so it cancels both the in-flight attempt and the loop itself. Keep
  # retrying fast failures, since a rebooting server refuses connections too.
  (
    while true; do
      echo "Connection lost. Reconnecting (Ctrl-C to stop)..."
      sleep 2
      command ssh "$@"
      rc=$?
      _ssh_disarm
      (( rc != 255 )) && exit $rc
    done
  )
}

# Disarm mouse tracking (1000/1002/1003, 1006 encoding), focus reporting
# (1004), and the alternate screen (1049), and show the cursor again.
_ssh_disarm() {
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h'
}

# True for an interactive session: a destination and no remote command. The
# letters are the ssh(1) options that consume a value, so their arguments are
# not mistaken for the destination.
# zsh: upstream's `local argv=("$@")` would clobber the positional parameters
# (argv IS "$@" in zsh), so the copy is called args here.
_ssh_interactive() {
  local value_opts="BbcDEeFIiJLlmOoPpQRSWw"
  local -a args=("$@")
  local arg letters i dest="" opts_done=""

  while (($#)); do
    arg="$1"
    shift

    if [[ -z $opts_done && $arg == "--" ]]; then
      opts_done=1
    elif [[ -z $opts_done && $arg == -?* ]]; then
      letters="${arg#-}"
      for ((i = 0; i < ${#letters}; i++)); do
        if [[ $value_opts == *"${letters:$i:1}"* ]]; then
          # The value is glued to the letter (-p2222) unless the letter ends
          # the argument, in which case it consumes the next one (-p 2222).
          (( i == ${#letters} - 1 )) && shift
          break
        fi
      done
    elif [[ -z $dest ]]; then
      dest="$arg"
    else
      return 1
    fi
  done

  [[ -n $dest ]] || return 1

  # A RemoteCommand from ssh_config or -o replays on reconnect just like a
  # positional command; ssh -G resolves the effective configuration for this
  # exact invocation without connecting. Fail closed when it cannot resolve,
  # since an undetected RemoteCommand must not replay. The explicit "none"
  # cancels a configured command, and some versions emit it when unset.
  local resolved
  resolved=$(command ssh -G "${args[@]}" 2>/dev/null) || return 1
  ! grep -i '^remotecommand ' <<<"$resolved" | grep -qvi '^remotecommand none$'
}

# ── Herdr layouts (upstream fns/herdr) ─────────────────────────────────────
# zsh note: upstream indexes arrays from 0 (`${columns[index]}`); zsh arrays are
# 1-indexed, so every index below is +1 relative to upstream.

_herdr_ratio() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.4f", a / b }'
}

_herdr_split() {
  herdr pane split "$1" --direction "$2" --ratio "$3" --cwd "$4" --no-focus |
    jq -r '.result.pane.pane_id'
}

# hdl <ai> [<second_ai>] — editor + AI + terminal
hdl() {
  [[ -z $1 ]] && { echo "Usage: hdl <c|cx|codex|other_ai> [<second_ai>]"; return 1; }
  [[ -z $HERDR_PANE_ID ]] && { echo "You must start herdr to use hdl."; return 1; }

  local current_dir="${PWD}"
  local editor_pane ai_pane ai2_pane
  local ai="$1" ai2="${2:-}"

  editor_pane="$HERDR_PANE_ID"
  herdr tab rename "$HERDR_TAB_ID" "$(basename "$current_dir")" >/dev/null
  _herdr_split "$editor_pane" down 0.85 "$current_dir" >/dev/null
  ai_pane=$(_herdr_split "$editor_pane" right 0.7 "$current_dir")

  if [[ -n $ai2 ]]; then
    ai2_pane=$(_herdr_split "$ai_pane" down 0.5 "$current_dir")
    herdr pane run "$ai2_pane" "$ai2" >/dev/null
  fi

  herdr pane run "$ai_pane" "$ai" >/dev/null
  herdr pane run "$editor_pane" "${EDITOR:-nvim} ." >/dev/null
}

# hds — editor + diff watch + terminal + opencode
hds() {
  [[ -n $1 ]] && { echo "Usage: hds"; return 1; }
  [[ -z $HERDR_PANE_ID ]] && { echo "You must start herdr to use hds."; return 1; }

  local current_dir="${PWD}"
  local editor_pane diff_pane terminal_pane opencode_pane

  editor_pane="$HERDR_PANE_ID"
  herdr tab rename "$HERDR_TAB_ID" "$(basename "$current_dir")" >/dev/null

  terminal_pane=$(_herdr_split "$editor_pane" down 0.5 "$current_dir")
  diff_pane=$(_herdr_split "$editor_pane" right 0.5 "$current_dir")
  opencode_pane=$(_herdr_split "$terminal_pane" right 0.5 "$current_dir")

  herdr pane run "$editor_pane" "nvim ." >/dev/null
  herdr pane run "$diff_pane" "hunk diff --watch" >/dev/null
  herdr pane run "$opencode_pane" "opencode" >/dev/null
}

# hdlm <ai> [<second_ai>] — one hdl tab per subdirectory
hdlm() {
  [[ -z $1 ]] && { echo "Usage: hdlm <c|cx|codex|other_ai> [<second_ai>]"; return 1; }
  [[ -z $HERDR_PANE_ID ]] && { echo "You must start herdr to use hdlm."; return 1; }

  local ai="$1" ai2="${2:-}"
  local base_dir="$PWD"
  local first=true
  local dir dirpath hdl_command pane_id

  herdr workspace rename "$HERDR_WORKSPACE_ID" "$(basename "$base_dir")" >/dev/null

  for dir in "$base_dir"/*/; do
    [[ -d $dir ]] || continue
    dirpath="${dir%/}"

    hdl_command="hdl ${(q)ai}"
    [[ -n $ai2 ]] && hdl_command="$hdl_command ${(q)ai2}"

    if $first; then
      hdl_command="cd ${(q)dirpath} && $hdl_command"
      herdr pane run "$HERDR_PANE_ID" "$hdl_command" >/dev/null
      first=false
    else
      pane_id=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$dirpath" --no-focus |
        jq -r '.result.root_pane.pane_id')
      herdr pane run "$pane_id" "$hdl_command" >/dev/null
    fi
  done
}

# hsl <pane_count> <command> — swarm grid, same command in every pane
hsl() {
  [[ -z $1 || -z $2 ]] && { echo "Usage: hsl <pane_count> <command>"; return 1; }
  [[ -z $HERDR_PANE_ID ]] && { echo "You must start herdr to use hsl."; return 1; }

  local count="$1" cmd="$2"
  local current_dir="${PWD}"
  local -a columns panes
  local cols=1 k col index rows j last pane

  herdr tab rename "$HERDR_TAB_ID" "$(basename "$current_dir")" >/dev/null

  while (( cols * cols < count )); do ((cols++)); done

  columns=("$HERDR_PANE_ID")
  for (( k = 1; k < cols; k++ )); do
    columns+=("$(_herdr_split "${columns[-1]}" right "$(_herdr_ratio 1 $((cols - k + 1)))" "$current_dir")")
  done

  for (( index = 0; index < cols; index++ )); do
    col="${columns[index+1]}"          # +1: zsh arrays are 1-indexed
    rows=$(( count / cols ))
    (( index < count % cols )) && (( rows++ ))
    panes+=("$col")
    last="$col"
    for (( j = 1; j < rows; j++ )); do
      last=$(_herdr_split "$last" down "$(_herdr_ratio 1 $((rows - j + 1)))" "$current_dir")
      panes+=("$last")
    done
  done

  for pane in "${panes[@]}"; do
    herdr pane run "$pane" "$cmd" >/dev/null
  done
}
