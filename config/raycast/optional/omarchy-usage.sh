#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title AI Usage
# @raycast.mode fullOutput
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🤖
# @raycast.description Show existing agent usage and rate limits

exec "$HOME/.local/bin/mac-raycast" run usage "$@"
