#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Mac Health Check
# @raycast.mode silent
# @raycast.packageName Omarchy
# @raycast.icon 🩺
# @raycast.description Run mac doctor in Ghostty

exec "$HOME/.local/bin/mac-raycast" run health "$@"
