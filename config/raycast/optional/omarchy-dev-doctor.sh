#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Developer Environment Check
# @raycast.mode silent
# @raycast.packageName Omarchy
# Optional standalone command; the default pack uses the single Omarchy menu.
# @raycast.icon 🩺
# @raycast.description Check developer tools and apps without starting services

exec "$HOME/.local/bin/mac-raycast" run dev-doctor "$@"
