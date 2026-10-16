#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Copy Browser URL
# @raycast.mode compact
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🔗
# @raycast.description Copy the selected browser tab URL

exec "$HOME/.local/bin/mac-raycast" run copy-url "$@"
