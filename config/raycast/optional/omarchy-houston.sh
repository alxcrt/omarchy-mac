#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Connect to Houston
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🚀
# @raycast.description Open houston in its own Rex session (ssh over Tailscale)

exec "$HOME/.local/bin/mac-raycast" run houston "$@"
