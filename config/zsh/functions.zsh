# ~/.config/zsh/functions.zsh
# Omarchy's shell functions, ported to zsh (basecamp/omarchy default/bash/fns).
# NOTE: zsh arrays are 1-indexed, so bash's ${panes[0]} becomes ${panes[1]}.
# Sourced from ~/.zshrc.
#
# oh-my-zsh's git plugin claims `ga`/`gd` (and friends) as ALIASES. In zsh you
# cannot define a function whose name is an existing alias — it's a parse error
# that aborts sourcing the rest of this file. So drop those aliases first.
unalias ga gd 2>/dev/null || true

# ── tmux dev layout: editor + AI + terminal ────────────────────────────────
# tdl <ai> [<second_ai>]   e.g.  tdl cx     |  tdl cx cy
tdl() {
  [[ -z $1 ]] && { echo "Usage: tdl <c|cx|codex|other_ai> [<second_ai>]"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tdl."; return 1; }

  local current_dir="${PWD}"
  local editor_pane ai_pane ai2_pane
  local ai="$1"
  local ai2="$2"

  editor_pane="$TMUX_PANE"

  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"

  # Bottom terminal strip (15%)
  tmux split-window -v -l 15% -t "$editor_pane" -c "$current_dir"

  # AI pane on the right (30%)
  ai_pane=$(tmux split-window -h -l 30% -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')

  if [[ -n $ai2 ]]; then
    ai2_pane=$(tmux split-window -v -t "$ai_pane" -c "$current_dir" -P -F '#{pane_id}')
    tmux send-keys -t "$ai2_pane" "$ai2" C-m
  fi

  tmux send-keys -t "$ai_pane" "$ai" C-m
  tmux send-keys -t "$editor_pane" "${EDITOR:-nvim} ." C-m
  tmux select-pane -t "$editor_pane"
}

# tdlm <ai> [<second_ai>] — one tdl layout per subdirectory
tdlm() {
  [[ -z $1 ]] && { echo "Usage: tdlm <c|cx|codex|other_ai> [<second_ai>]"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tdlm."; return 1; }

  local ai="$1"
  local ai2="$2"
  local base_dir="$PWD"
  local first=true
  local dir dirpath pane_id

  tmux rename-session "$(basename "$base_dir" | tr '.:' '--')"

  for dir in "$base_dir"/*/; do
    [[ -d $dir ]] || continue
    dirpath="${dir%/}"

    if $first; then
      tmux send-keys -t "$TMUX_PANE" "cd '$dirpath' && tdl $ai $ai2" C-m
      first=false
    else
      pane_id=$(tmux new-window -c "$dirpath" -P -F '#{pane_id}')
      tmux send-keys -t "$pane_id" "tdl $ai $ai2" C-m
    fi
  done
}

# tsl <pane_count> <command> — swarm layout, same command in N tiled panes
tsl() {
  [[ -z $1 || -z $2 ]] && { echo "Usage: tsl <pane_count> <command>"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tsl."; return 1; }

  local count="$1"
  local cmd="$2"
  local current_dir="${PWD}"
  local -a panes
  local new_pane split_target pane

  tmux rename-window -t "$TMUX_PANE" "$(basename "$current_dir")"
  panes+=("$TMUX_PANE")

  while (( ${#panes[@]} < count )); do
    split_target="${panes[-1]}"
    new_pane=$(tmux split-window -h -t "$split_target" -c "$current_dir" -P -F '#{pane_id}')
    panes+=("$new_pane")
    tmux select-layout -t "${panes[1]}" tiled
  done

  for pane in "${panes[@]}"; do
    tmux send-keys -t "$pane" "$cmd" C-m
  done

  tmux select-pane -t "${panes[1]}"
}

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

# ── Dev square layout: editor + diff watch + terminal + opencode ───────────
# Usage: tds       (upstream fns/tmux)
# NOTE: the diff pane runs `hunk diff --watch` — a Basecamp tool that may not
# be installed here; the pane simply shows a "command not found" if missing.
tds() {
  [[ -n $1 ]] && { echo "Usage: tds"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tds."; return 1; }

  local current_dir="${PWD}"
  local editor_pane diff_pane terminal_pane opencode_pane

  editor_pane="$TMUX_PANE"

  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"

  terminal_pane=$(tmux split-window -v -l 50% -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')
  diff_pane=$(tmux split-window -h -l 50% -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')
  opencode_pane=$(tmux split-window -h -l 50% -t "$terminal_pane" -c "$current_dir" -P -F '#{pane_id}')

  tmux send-keys -t "$editor_pane" -l "nvim ."
  tmux send-keys -t "$editor_pane" C-m
  tmux send-keys -t "$diff_pane" -l "hunk diff --watch"
  tmux send-keys -t "$diff_pane" C-m
  tmux send-keys -t "$opencode_pane" -l "opencode"
  tmux send-keys -t "$opencode_pane" C-m

  tmux select-pane -t "$editor_pane"
}

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
  pgrep -af "ssh.*-L [0-9]+:localhost:[0-9]+" || echo "No active forwards"
}
