#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Connect to Titan
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🎮
# @raycast.description Open the gaming VM shell through the existing fleet wrapper

exec "$HOME/.local/bin/mac-raycast" run titan "$@"
