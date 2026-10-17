#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Omarchy
# @raycast.mode silent
# @raycast.packageName Omarchy
# @raycast.icon ⌨️
# @raycast.description Developer checks, Git, Docker, music, updates, help and fleet actions
# @raycast.argument1 {"type":"dropdown","placeholder":"Choose an action","data":[{"title":"Learn → Keybindings","value":"keys"},{"title":"System → Health check","value":"health"},{"title":"System → Activity monitor","value":"monitor"},{"title":"Developer → Environment check","value":"dev-doctor"},{"title":"Developer → Git repositories","value":"git"},{"title":"Developer → AI usage","value":"usage"},{"title":"Developer → Docker","value":"docker"},{"title":"Developer → Neovim","value":"editor"},{"title":"Media → Music player (CLIamp)","value":"music"},{"title":"Media → Transcode file","value":"transcode"},{"title":"Media → Download current video","value":"download"},{"title":"Media → Copy browser URL","value":"copy-url"},{"title":"Fleet → Houston","value":"houston"},{"title":"Fleet → NASA","value":"nasa"},{"title":"Fleet → Coolify","value":"coolify"},{"title":"Fleet → Titan","value":"titan"},{"title":"Update → Everything","value":"update"},{"title":"Update → Developer tools","value":"mise"}]}

exec "$HOME/.local/bin/mac-raycast" menu "$@"
