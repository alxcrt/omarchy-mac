#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Open Ghostty
# @raycast.mode silent
# @raycast.packageName Omarchy
# @raycast.icon 👻
# @raycast.description Bring the existing Ghostty app forward

exec "$HOME/.local/bin/mac-raycast" run ghostty "$@"
