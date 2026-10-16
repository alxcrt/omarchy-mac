# Raycast: one Omarchy command

Search **Omarchy** in Raycast, choose an action from its dropdown, and press
Return. The choices are grouped by Update, Learn, System, Developer, Media,
and Fleet. Normal Raycast app search already opens cmux, Ghostty, the browser,
and editors; no separate app-launch commands are needed in this menu.

If you already registered `~/.config/raycast/scripts`, Raycast watches that
folder and picks up the new command. Otherwise, add it once in Raycast
Settings → Script Commands → Add Script Directory. No Store extension is
required. Optional: give the Omarchy command the alias `om`.

Long-running tools, updates, keybindings, and usage output open in the existing
Ghostty instance. Fleet choices connect only when selected and use the existing
`cmux-fleet` wrapper; houston uses herdr. The first browser/Ghostty invocation
may need macOS Automation permission for Raycast itself.

The earlier 16 standalone scripts are retained under `config/raycast/optional`
for individual hotkeys if wanted later. They are no longer installed into the
registered folder by default. The installer removes only its old symlinks;
user files and unrelated Script Commands are preserved.

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

Checked basecamp/omarchy (now omacom/omarchy) `51bfd1d`, Quattro:
`docs/menu.md`, `default/omarchy/omarchy-menu.jsonc`, `manual/04-navigation.md`,
and `default/hypr/bindings/utilities.lua`. Current Omarchy uses a shared
Quickshell menu with categories and direct shortcuts, with built-in features
and a launcher hide list. Its older Walker documentation describes an earlier
release. This port uses one Raycast dropdown with grouped labels rather than
adding another UI runtime.

Sources:
- https://github.com/omacom/omarchy/blob/51bfd1dbaa1b5f790e19623faf2745945d40c796/docs/menu.md
- https://github.com/omacom/omarchy/blob/51bfd1dbaa1b5f790e19623faf2745945d40c796/default/omarchy/omarchy-menu.jsonc
- https://github.com/raycast/script-commands/blob/master/documentation/ARGUMENTS.md
