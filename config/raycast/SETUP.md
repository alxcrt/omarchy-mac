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

## Everyday shortcuts

Configured and read back in Raycast Settings on 18 October 2026. The repeatable
assignment guide is `config/raycast/hotkeys.tsv`; `mac keys` includes it and
labels it as a guide because Raycast owns the actual registrations privately.
The installer links the guide, but **does not assign hotkeys**. Re-check these
in Raycast Settings → Shortcuts after reinstalling or importing app settings.

| Shortcut | Action |
| --- | --- |
| `⌘Space` | Raycast launcher (existing) |
| `⌘` + backtick | Ghostty quick terminal (existing global Ghostty binding) |
| `Hyper+V` | Clipboard History |
| `Hyper+B` | Helium, the current default browser |
| `Hyper+T` | Ghostty (existing) |
| `Hyper+W` | cmux workspaces |
| `Hyper+A` / `Hyper+C` | ChatGPT / Claude |
| `Hyper+E` / `Hyper+L` | VS Code / Linear (Linear retained) |
| `Hyper+P` / `Hyper+M` | Bitwarden / IINA |
| `Hyper+O` | Omarchy menu |
| `Hyper+K` | Omarchy Keybindings |

Hyper is **left Control + Option + Shift + Command** on the Corne. Both bottom
outer keys provide it: left-bottom taps Raycast and holds Hyper; right-bottom
taps one-shot Hyper and holds ordinary Hyper. After tapping and releasing
right-bottom, press the shortcut within 1.5 seconds. It applies to one key
press and times out unused; it does not lock on. Left modifiers avoid hidutil's
right-Command-to-Option remap. Caps Lock stays Escape. A regular Mac keyboard
can press the four left modifiers together; no new key-remapping tool is needed.

The Corne's outer keys are arranged as follows on Mac:

| Row | Left | Right |
| --- | --- | --- |
| Top | Quick terminal | Capture menu; hold Clicks |
| Middle | Caps Word | Clipboard History |
| Bottom | Raycast; hold Hyper | One-shot Hyper; hold Hyper |

Clicks turns the thumbs into mouse buttons while capture is held: Space or
Backspace = left click, Tab or Enter = right click, Escape or Delete = middle
click. Release capture to return to typing. The Mouse layer (hold Tab) moves
the pointer and scrolls.

Caps Word uppercases a word or identifier (`MY_VARIABLE`), then turns off at
a space or other separator. It uses Shift and avoids the Caps-Lock-to-Escape
remap. Both host modes use it. Browser access remains Hyper+B / System + L;
Helium's saved Raycast assignment and the default browser are unchanged.

Hold Escape + Y for an area screenshot. Linux uses the same positions for its
scratchpad, capture menu, Caps Word, clipboard, menu and one-shot Super. Hold
Escape + Q for Mac or Escape + W for Linux. See the
[firmware guide](https://github.com/alxcrt/miryoku-chocofi-layout/tree/dongle)
and [printable cheat sheet](https://github.com/alxcrt/miryoku-chocofi-layout/blob/dongle/output/pdf/corne-cheatsheet.pdf).

`Hyper+K` uses the existing optional script enabled by this symlink:
`~/.config/raycast/scripts/omarchy-keys.sh` →
`~/omarchy-mac/config/raycast/optional/omarchy-keys.sh`. The installer preserves
this optional link. It renders output inside Raycast; it does not open Ghostty.
Other standalone scripts remain optional.

Ghostty's `global:cmd+grave_accent=toggle_quick_terminal` provides the requested
show/hide action. Its installed CLI accepts the config; live toggle and global
shortcut registration still need a physical test because Computer Use blocks
Ghostty in this environment. Do not infer missing Accessibility permission from
that restriction. On Linux, `Super+backtick` toggles the scratchpad rather than
creating a terminal; put a terminal there with `Super+Shift+backtick` first.

Validation: all assignments above were read back in Raycast Settings. The
Omarchy Keybindings command was also run from search and rendered the new
shortcut guide inside Raycast. Global Hyper activation still needs a physical
keyboard test; synthesized Hyper input in Computer Use did not launch it.
The full headless run passed 426 functional checks, with six desktop checks
skipped; its only failure was the expected uncommitted-work check. After the
commit, all 56 repository/link checks passed. Firmware build
[`39072857398`](https://github.com/alxcrt/miryoku-chocofi-layout/actions/runs/39072857398)
passed all six targets for the final arrangement (commit `a23b537`), including
Caps Word, the 1.5-second one-shot Hyper behavior and both host modes. No
keyboard has been flashed by this task.

This keeps the useful Omarchy workflows while respecting Mac shortcuts:
Command for native app actions, Hyper for global app launchers, and Option for
herdr. In particular, `⌥Enter` still splits a herdr pane, and Ghostty's existing
Hyper+arrow split-resizing bindings stay in place. Native tiling and Spaces
continue through `mac wm`; no extra window manager is installed.

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

Checked everyday shortcuts in official `omacom/omarchy` at `4a9c83d` (18 October
2026): `default/hypr/bindings/{applications,utilities,clipboard,tiling}.lua`.
These define menu, clipboard, browser, terminal, scratchpad and keybindings.

The earlier menu comparison used `f4357a3` (17 October 2026):
`docs/menu.md`, `default/omarchy/omarchy-menu.jsonc`, `manual/04-navigation.md`,
and `default/hypr/bindings/utilities.lua`. Current Omarchy uses a shared
Quickshell menu with categories and direct shortcuts, with built-in features
and a launcher hide list. Its older Walker documentation describes an earlier
release. This port uses one Raycast dropdown with grouped labels rather than
adding another UI runtime.

Sources:
- https://github.com/omacom/omarchy/tree/4a9c83deceb5bda84f706794c2ddc61084914fe0/default/hypr/bindings
- https://ghostty.org/docs/config/keybind/reference#toggle_quick_terminal
- https://github.com/omacom/omarchy/blob/f4357a3b2667047aa3c295d89337fc0ff751b41f/docs/menu.md
- https://github.com/omacom/omarchy/blob/f4357a3b2667047aa3c295d89337fc0ff751b41f/default/omarchy/omarchy-menu.jsonc
- https://github.com/raycast/script-commands/blob/master/documentation/ARGUMENTS.md
