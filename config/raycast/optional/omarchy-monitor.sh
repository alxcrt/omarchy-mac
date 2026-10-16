#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title System Monitor
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 📊
# @raycast.description Open btop in Ghostty

exec "$HOME/.local/bin/mac-raycast" run monitor "$@"
