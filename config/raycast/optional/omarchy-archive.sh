#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Archive Manager
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 📦
# @raycast.description Open Keka for ZIP, 7z and RAR files

exec "$HOME/.local/bin/mac-raycast" run archive "$@"
