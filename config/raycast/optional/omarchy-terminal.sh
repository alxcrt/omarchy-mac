#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Open Development Terminal
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 💻
# @raycast.description Bring cmux forward

exec "$HOME/.local/bin/mac-raycast" run terminal "$@"
