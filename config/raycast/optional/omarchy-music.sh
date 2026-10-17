#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Music Player
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🎵
# @raycast.description Open CLIamp in Ghostty

exec "$HOME/.local/bin/mac-raycast" run music "$@"
