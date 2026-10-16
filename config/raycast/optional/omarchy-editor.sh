#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Open Neovim
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 📝
# @raycast.description Open Neovim in the Developer folder

exec "$HOME/.local/bin/mac-raycast" run editor "$@"
