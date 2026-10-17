# Raycast: one Omarchy command

Search **Omarchy** in Raycast, choose an action from its dropdown, and press
Return. The choices are grouped by Update, Learn, System, Developer, Media,
and Fleet. Normal Raycast app search already opens cmux, Ghostty, the browser,
and editors; no separate app-launch commands are needed in this menu.

The Developer group checks the web/full-stack environment (`mac dev doctor`),
opens Git repositories in lazygit, and opens Docker containers in lazydocker.
The check reports tools and apps without starting Docker or any database. The
Media group opens CLIamp in Ghostty alongside the download/transcode flows.
Configure music providers when wanted with `mac raycast run music-setup`;
provider sign-in is interactive and credentials stay in CLIamp's own config.

Search **Bruno** for API requests, **DBeaver** for databases, and **Keka** for
archives using normal Raycast app search. Keka opens RAR archives and creates
ZIP/7z archives; it does not create RAR archives. These apps need no Store
extension. Connections, collections and archive choices stay app-owned.

If you already registered `~/.config/raycast/scripts`, Raycast watches that
folder and picks up the new command. Otherwise, add it once in Raycast
Settings → Script Commands → Add Script Directory. No Store extension is
required. Optional: give the Omarchy command the alias `om`.

Long-running tools, updates, keybindings, and usage output open in the existing
Ghostty instance. Fleet choices connect only when selected and use the existing
`cmux-fleet` wrapper; houston uses herdr. The first browser/Ghostty invocation
may need macOS Automation permission for Raycast itself.

Standalone scripts are retained under `config/raycast/optional` for individual
hotkeys if wanted later, including developer checks, Git, CLIamp/provider setup,
Bruno, DBeaver and Keka. They are not installed into the
registered folder by default. The installer removes only its old symlinks;
user files and unrelated Script Commands are preserved.

To enable an individual optional command, symlink only its script into
`~/.config/raycast/scripts`, for example
`ln -s ~/omarchy-mac/config/raycast/optional/omarchy-api.sh ~/.config/raycast/scripts/omarchy-api.sh`.
Assign any desired hotkey in Raycast Settings → Extensions → Script Commands;
Raycast's aliases and hotkeys require this in-app step. The file installer
does not enable optional scripts or change those settings.

## Optional extras

The menu works without any imports. If you want dashboard/project Quicklinks,
run `mac raycast prepare`, then use Raycast's **Import Quicklinks** with
`~/.local/share/omarchy-mac/raycast/quicklinks.json`. **Import Snippets** can
load `~/.config/raycast/omarchy-snippets.json`; its explicit `;;` triggers avoid
replacing ordinary spaces and command snippets contain no trailing newline.
Private dashboards stay in `~/.config/raycast/omarchy-quicklinks.local.json`,
outside Git. Full `.rayconfig` exports and credentials also stay outside Git.

Keep built-in app/file search, Calculator, Clipboard History, Quicklinks,
Snippets, and Emoji & Symbols. Keep useful existing integrations such as
CleanShot X and Linear. No GitHub or Tailscale Store extension is required;
add a specific integration only when a repeated task needs it.

For existing clutter, review iTerm/Screen Studio (apps absent at audit), World
Cup, and extra Emoji Search; hide unused commands and background menu-bar
items in Raycast Settings. These app settings have not been changed by the
file installer. Keep `macup` as the update command and avoid routine App Cleaner
removals of Homebrew-managed apps. Leave hidutil mappings and existing hotkeys
in place.

## Upstream reference

Checked the official `omacom/omarchy` source at `f4357a3` (17 October 2026):
`docs/menu.md`, `default/omarchy/omarchy-menu.jsonc`, `manual/04-navigation.md`,
and `default/hypr/bindings/utilities.lua`. Current Omarchy uses a shared
Quickshell menu with categories and direct shortcuts, with built-in features
and a launcher hide list. Its older Walker documentation describes an earlier
release. This port uses one Raycast dropdown with grouped labels rather than
adding another UI runtime.

Sources:
- https://github.com/omacom/omarchy/blob/f4357a3b2667047aa3c295d89337fc0ff751b41f/docs/menu.md
- https://github.com/omacom/omarchy/blob/f4357a3b2667047aa3c295d89337fc0ff751b41f/default/omarchy/omarchy-menu.jsonc
- https://github.com/raycast/script-commands/blob/master/documentation/ARGUMENTS.md
