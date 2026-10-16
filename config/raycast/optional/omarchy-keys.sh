#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Omarchy Keybindings
# @raycast.mode fullOutput
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon ⌨️
# @raycast.description Read the keybindings from the current configs

exec "$HOME/.local/bin/mac-raycast" run keys "$@"
