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
link config/zsh/functions.zsh  .config/zsh/functions.zsh
link config/btop/btop.conf     .config/btop/btop.conf
link config/herdr/config.toml  .config/herdr/config.toml
link config/opencode/opencode.jsonc .config/opencode/opencode.jsonc
link config/git/config         .config/git/config
link config/ghostty/config     .config/ghostty/config
# Every script in local/bin — no hand-kept list to fall out of date.
for f in "$REPO"/local/bin/*; do
  s=$(basename "$f")
  link "local/bin/$s" ".local/bin/$s"
  chmod +x "$f"
done
# .zshrc is linked separately so you can opt out (it is a self-contained zsh config).
link zsh/zshrc                 .zshrc
# Claude Code skill: teaches future sessions how this setup works.
link skills/omarchy-mac/SKILL.md .claude/skills/omarchy-mac/SKILL.md

# --links: just repair the symlinks (live files drift into plain copies after
# --zap, installers appending to .zshrc, or editors that write via rename).
[ "${1:-}" = "--links" ] && exit 0

section "Staging the browser extensions"
# Real copies (Chrome resolves icons relative to the folder), refreshed from
# the repo every run; Chrome picks them up on its next reload or restart.
"$HOME/.local/bin/chrome-extensions" sync

section "Installing the modifier-remap login agent"
# Replaces Karabiner-Elements: hidutil is Apple's own HID remapper, so there is
# no driver or system extension to approve. The plist is COPIED, not symlinked —
# launchd is fussy about plist ownership and a symlink into the repo is not
# worth the risk. Re-running install.sh re-copies it.
AGENT="$HOME/Library/LaunchAgents/com.omarchy.keyremap.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cp "$REPO/config/launchd/com.omarchy.keyremap.plist" "$AGENT"
launchctl bootout "gui/$UID/com.omarchy.keyremap" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$AGENT" 2>/dev/null || true
"$HOME/.local/bin/mac-keyremap" --apply

section "Configuring native window management"
# Window management is macOS's own tiling + Mission Control Spaces now
# (AeroSpace was dropped). This only flips on what Apple ships disabled.
"$HOME/.local/bin/mac-wm" --apply

section "Ensuring Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$($(command -v brew || echo /opt/homebrew/bin/brew) shellenv)"

section "Ensuring mise"
command -v mise >/dev/null 2>&1 || brew install mise

section "Reconciling Homebrew layer (Brewfile)"
# Homebrew 6 aborts the whole bundle on a formula from an untrusted tap, so
# tap and trust the third-party ones first. Trust the formula, not the tap.
for t in bjarneo/cliamp blacktop/tap mateussiqueira/unleash; do brew tap "$t"; done
brew trust --formula bjarneo/cliamp/cliamp blacktop/tap/ipsw mateussiqueira/unleash/unleash
brew bundle --file="$HOME/.config/homebrew/Brewfile" || true

section "Applying macOS defaults"
# Key repeat, Finder hidden files/path bar/status bar, instant Dock autohide,
# Transmission's prefs + magnet/.torrent handler, ~/Developer. After the
# Brewfile, since the default apps need duti and Transmission installed.
"$HOME/.local/bin/mac-defaults" --apply

section "Reconciling mise layer"
mise trust "$HOME/.config/mise/config.toml"
mise install

section "Done"
echo "Open a new terminal (or 'exec zsh -l') to load the prompt and aliases."
echo "Update everything anytime with: macup"
