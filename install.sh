#!/bin/bash
# omarchy-mac installer — idempotent. Symlinks configs into place, ensures
# Homebrew + mise, then reconciles both layers. Safe to re-run.
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
section() { echo -e "\n\033[0;32m$1\033[0m"; }

# link <src-in-repo> <dest-in-home>
link() {
  local src="$REPO/$1" dest="$HOME/$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    cp "$dest" "$dest.bak" && echo "backed up $dest -> $dest.bak"
  fi
  ln -sfn "$src" "$dest"
  echo "linked ~/$2"
}

section "Symlinking configs"
link config/mise/config.toml   .config/mise/config.toml
link config/homebrew/Brewfile  .config/homebrew/Brewfile
link config/zsh/aliases.zsh    .config/zsh/aliases.zsh
link config/starship.toml      .config/starship.toml
link config/tmux/tmux.conf     .config/tmux/tmux.conf
link config/aerospace/aerospace.toml .config/aerospace/aerospace.toml
link config/zsh/functions.zsh  .config/zsh/functions.zsh
link config/btop/btop.conf     .config/btop/btop.conf
for s in macup mise-install mac ghostty-run transcode webdl weburl; do
  link "local/bin/$s" ".local/bin/$s"
  chmod +x "$HOME/.local/bin/$s"
done
# .zshrc is linked separately so you can opt out (it assumes oh-my-zsh).
link zsh/zshrc                 .zshrc

section "Ensuring Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$($(command -v brew || echo /opt/homebrew/bin/brew) shellenv)"

section "Ensuring mise"
command -v mise >/dev/null 2>&1 || brew install mise

section "Reconciling Homebrew layer (Brewfile)"
brew bundle --file="$HOME/.config/homebrew/Brewfile" || true

section "Reconciling mise layer"
mise trust "$HOME/.config/mise/config.toml"
MISE_MINIMUM_RELEASE_AGE=0 mise install

section "Done"
echo "Open a new terminal (or 'exec zsh -l') to load the prompt and aliases."
echo "Update everything anytime with: macup"
