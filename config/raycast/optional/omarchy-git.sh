#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Git Repositories
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🌱
# @raycast.description Open lazygit in the Developer folder

exec "$HOME/.local/bin/mac-raycast" run git "$@"
