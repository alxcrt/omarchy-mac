# Raycast setup

The files below are installed on disk. Raycast must register/import them in
its own UI; preparing them does not change its encrypted settings database.

1. In Raycast Settings → Script Commands → Add Script Directory, select
   `~/.config/raycast/scripts`. This adds the 16 Omarchy commands. Existing
   third-party scripts in that directory are preserved.
2. Run **Import Quicklinks** and select
   `~/.local/share/omarchy-mac/raycast/quicklinks.json`.
3. Run **Import Snippets** and select
   `~/.config/raycast/omarchy-snippets.json`. The `;;` keywords avoid replacing
   ordinary typing or two spaces inside code. Command snippets contain no
   trailing newline and do not execute themselves.
4. Install these extensions from the official Raycast Store:
   - Helium: https://www.raycast.com/islamtayeb/helium
   - GitHub: https://www.raycast.com/raycast/github
   - Tailscale: https://www.raycast.com/tailscale/tailscale
   Sign into GitHub when prompted; choose `~/Developer` as its default clone
   folder. Installation alone does not complete authentication.
5. Remove **iTerm**, **Screen Studio**, **FIFA World Cup 2026**, and the extra
   **Emoji Search** extension after checking you do not need their saved
   preferences. Use Raycast's built-in Emoji & Symbols. Disable **MCP Registry
   → Search Servers** and **App Cleaner → Uninstall Application** for now.
   Use Homebrew-aware removals for Homebrew-managed apps.
6. Disable unused background commands: **MyIP → IP in Menu Bar**, **Brew →
   Services Menu Bar**, **Port Manager → Open Ports in Menu Bar**, and the
   World Cup menu/live-score commands. Keep Coffee's timed actions; turn off
   **Start caffeination when Raycast starts** unless intentional. Keep Linear
   notifications only if you use them. No periodic command is added by this pack.
7. In the existing Visual Studio Code extension, set **Build** to the editor
   you use (Cursor or Visual Studio Code) and **Terminal App** to cmux or
   Ghostty. Keep Brew's **Remove all files associated with a cask (--zap)**
   off. Use **Update Everything** for upgrades so `macup` remains the owner.
8. Set Clipboard History → **Keep history for: 1 Month**, and OCR recognition
   to **Fast** if Text Recognition is enabled. In File Search, keep **Use
   Ignore Files** enabled and **Index Network & Removable Drives** off unless
   you want NAS/media volumes searched.
9. Assign aliases: `term` → Open Development Terminal, `up` → Update
   Everything, `health` → Mac Health Check, `usage` → AI Usage, `keys` →
   Omarchy Keybindings, `ports` → Port Manager's Open Ports, `pr` → GitHub's
   My Pull Requests, `tabs` → Helium's Search Tabs. Keep your existing Raycast
   summon hotkey. Prefer aliases initially: Option/Control-number shortcuts
   overlap with herdr and Mission Control. Caps Lock and right Command are
   already owned by hidutil; do not assign the same physical key as Raycast
   Hyper Key without first deliberately changing that remap.

Terminal commands use the existing Ghostty instance through `ghostty-run`.
Open Development Terminal brings cmux forward. Fleet commands open a Ghostty
window and use `cmux-fleet`; houston keeps `herdr --remote`, never tmux. They
connect only when invoked, and do not alter Raycast or cmux socket permissions.
The first invocation may need macOS Automation permission for Raycast itself.

Machine-local dashboard links belong in
`~/.config/raycast/omarchy-quicklinks.local.json` (a JSON array of objects with
`name` and `link`). Run `mac raycast prepare` after edits and re-import. Keep
private links, credentials, and full `.rayconfig` exports out of the public
repository. No full Raycast export, clipboard purge, or private DB edit is
performed by these commands.

Documentation checked 16 October 2026:
- https://manual.raycast.com/script-commands
- https://manual.raycast.com/quicklinks
- https://manual.raycast.com/snippets
- https://manual.raycast.com/clipboard-history
- https://manual.raycast.com/file-search

Emoji and launcher choices were checked against basecamp/omarchy `51bfd1d`.
The snippet contents follow upstream XCompose, with explicit `;;` triggers.
