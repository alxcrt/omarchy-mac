#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Update Everything
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon ⬆️
# @raycast.description Run macup in Ghostty with normal prompts and logs

exec "$HOME/.local/bin/mac-raycast" run update "$@"
