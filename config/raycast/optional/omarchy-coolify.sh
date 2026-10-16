#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Connect to Coolify
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon ☁️
# @raycast.description Open the VPS shell through the existing fleet wrapper

exec "$HOME/.local/bin/mac-raycast" run coolify "$@"
