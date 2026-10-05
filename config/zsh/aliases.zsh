# ~/.config/zsh/aliases.zsh
# 1:1 port of Omarchy's default/bash/aliases, adapted for zsh + macOS.
# Deviations from upstream are marked "macOS:" and are only where the Linux
# original cannot work here.

# ── File system ────────────────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

# macOS: upstream has a kitty-image branch; Ghostty uses the bat preview.
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias eff='$EDITOR "$(ff)"'

# sff <destination> — pick a recent file with fzf and scp it somewhere.
# macOS: BSD find has no -printf, so use GNU find (findutils) when present,
# else fall back to stat -f. Behaviour matches upstream.
sff() {
  if [ $# -eq 0 ]; then echo "Usage: sff <destination> (e.g. sff host:/tmp/)"; return 1; fi
  local file
  if command -v gfind &>/dev/null; then
    file=$(gfind . -type f -printf '%T@\t%p\n' | sort -rn | cut -f2- | ff)
  else
    file=$(find . -type f -exec stat -f '%m%t%N' {} + | sort -rn | cut -f2- | ff)
  fi
  [ -n "$file" ] && scp "$file" "$1"
}

# ── Directories ────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi
      printf "\U000F17A9 "
      pwd
    fi
  }
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# macOS: upstream wraps xdg-open as `open`. macOS `open` is already native
# and better, so it is deliberately NOT overridden.

# ── Tools ──────────────────────────────────────────────────────────────────
alias c='opencode --auto'
alias cx='printf "\033[2J\033[3J\033[H" && claude --permission-mode auto'
alias cy='codex --approve-for-me'
alias d='docker'
alias r='rails'
alias h='herdr'
# herdr replaces tmux here, so the dev-layout shortcuts drive hdl, not tdl.
alias ic='hdl c'
alias ix='hdl cx'
alias icx='hdl c cx'
alias mup='mise up'   # minimum_release_age=0 lives in mise's config
n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }

# macOS additions: `omarchy update` equivalent (no upstream counterpart).
alias macup='$HOME/.local/bin/macup'
alias up='macup'

# Upstream's `a='omarchy-agent --inline'` launches the *configured default*
# coding agent, each with its own spelling of "don't stop to ask"
# (bin/omarchy-agent). There's no omarchy-agent here, so `a` reads the choice
# from OMARCHY_AGENT: claude|codex|opencode|grok|omp|hermes|pi.
# Like upstream, a launch from $HOME starts in the work dir (~/Developer here,
# ~/Work upstream): agents won't remember trust for $HOME and re-ask every
# session. A subshell, so the calling shell stays where it was, as it does
# when upstream's separate omarchy-agent process changes directory.
export OMARCHY_AGENT="${OMARCHY_AGENT:-claude}"
a() {
  local -a cmd
  case ${OMARCHY_AGENT:-claude} in
    claude)   cmd=(claude --permission-mode auto) ;;
    codex)    cmd=(codex --approve-for-me) ;;
    opencode) cmd=(opencode --auto) ;;
    grok)     cmd=(grok --permission-mode bypassPermissions) ;;
    omp)      cmd=(omp --auto-approve) ;;
    hermes)   cmd=(hermes --yolo) ;;
    *)        cmd=("$OMARCHY_AGENT") ;;   # pi and others have nothing to skip
  esac
  (
    [[ $PWD == "$HOME" && -d $HOME/Developer ]] && builtin cd "$HOME/Developer"
    command "${cmd[@]}" "$@"
  )
}

# ── Git ────────────────────────────────────────────────────────────────────
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# ── Environment (from Omarchy default/bash/envs) ───────────────────────────
# Upstream guards with ${EDITOR:-…}; keep that so a pre-set EDITOR wins.
export EDITOR="${EDITOR:-nvim}"
export SUDO_EDITOR="$EDITOR"
# Upstream points BROWSER at omarchy-launch-browser so CLIs (gh, mise) can open
# URLs detached from the terminal; `open` is the macOS equivalent.
export BROWSER="${BROWSER:-open}"
export BAT_THEME=ansi
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"
alias decompress="tar -xzf"
