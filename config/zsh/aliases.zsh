# ~/.config/zsh/aliases.zsh
# Ported from Omarchy's default bash aliases/envs, adjusted for macOS + zsh.
# Sourced from ~/.zshrc.

# --- Files ---
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias eff='$EDITOR "$(ff)"'

# --- Directories ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- Tools ---
alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise up'
alias macup='$HOME/.local/bin/macup'
alias up='macup'
alias c='opencode'                # Omarchy default: `c` launches opencode
alias cx='printf "\033[2J\033[3J\033[H" && claude --permission-mode bypassPermissions'
alias cy='codex -s danger-full-access -a never'
alias d='docker'
alias t='tmux attach || tmux new -s Work'
# Omarchy dev-layout shortcuts (see functions.zsh: tdl)
alias ic='tdl c'
alias ix='tdl cx'
alias icx='tdl c cx'
n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }

# --- Git ---
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# sff: fuzzy-find files by recency. Omarchy used GNU `find -printf`, which BSD
# find lacks — rewritten with stat -f so it works on stock macOS.
sff() {
  fd --type f "${1:-}" 2>/dev/null \
    | while IFS= read -r f; do stat -f '%m %N' "$f"; done \
    | sort -rn | cut -d' ' -f2-
}

# --- Environment ---
export EDITOR=nvim
export BAT_THEME=ansi
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# macOS note: `open` is native and better than xdg-open — NOT overridden.
# Omarchy-internal aliases (a=omarchy-agent, h=herdr, ic/ix/icx=tdl) dropped:
# those binaries don't exist on macOS. r='rails' kept as-is if you use it.
alias r='rails'
