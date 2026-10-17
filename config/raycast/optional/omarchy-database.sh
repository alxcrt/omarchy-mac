#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Database Browser
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🗄️
# @raycast.description Open DBeaver

exec "$HOME/.local/bin/mac-raycast" run database "$@"
