#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Download Current Video
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon ⬇️
# @raycast.description Run webdl in Ghostty using the selected browser

exec "$HOME/.local/bin/mac-raycast" run download "$@"
