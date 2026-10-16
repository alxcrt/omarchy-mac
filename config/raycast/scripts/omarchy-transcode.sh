#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Transcode File
# @raycast.mode silent
# @raycast.packageName Omarchy
# @raycast.icon 🎞️
# @raycast.description Choose a file and output format

exec "$HOME/.local/bin/mac-raycast" run transcode "$@"
