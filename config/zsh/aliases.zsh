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
alias t='tmux attach || tmux new -s Work'
alias h='herdr'
alias ic='tdl c'
alias ix='tdl cx'
alias icx='tdl c cx'
alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise up'
n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }

# macOS additions: `omarchy update` equivalent (no upstream counterpart).
alias macup='$HOME/.local/bin/macup'
alias up='macup'

# Upstream's `a='omarchy-agent --inline'` launches the *configured default*
# coding agent. There's no omarchy-agent here, so `a` reads the same idea from
# an env var — set OMARCHY_AGENT to claude|codex|opencode|grok|omp.
export OMARCHY_AGENT="${OMARCHY_AGENT:-claude}"
a() { command "${OMARCHY_AGENT:-claude}" "$@"; }

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

# ── Shell hygiene (upstream default/bash/shell + init) ─────────────────────
# HISTSIZE is left alone — the live value (50000) already exceeds upstream's
# 32768. These are the parts that were genuinely missing:
setopt hist_ignore_all_dups   # upstream HISTCONTROL=ignoreboth
setopt hist_ignore_space
unsetopt hash_cmds            # upstream `set +h` — stops stale mise shim paths
unsetopt hash_dirs
# fzf's Ctrl-R / Ctrl-T / Alt-C widgets (upstream sources fzf's completion+keybindings)
command -v fzf >/dev/null && source <(fzf --zsh) 2>/dev/null
