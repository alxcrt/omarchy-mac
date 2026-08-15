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

# Upstream also has `a='omarchy-agent --inline'` — no macOS counterpart, so it
# is intentionally omitted rather than pointed at something different.

# ── Git ────────────────────────────────────────────────────────────────────
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# ── Environment (from Omarchy default/bash/envs) ───────────────────────────
export EDITOR=nvim
export BAT_THEME=ansi
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"
alias decompress="tar -xzf"
