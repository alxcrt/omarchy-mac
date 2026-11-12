-- ~/.config/rex/init.lua
-- Rex is a terminal and multiplexer in one (Ghostty's renderer plus herdr's
-- job), so this file carries config/herdr/config.toml's [keys] over. herdr
-- terms map to Rex terms: workspace -> session, tab -> tab, pane -> pane.
-- Rex's default ⌘ shortcuts (⌘D, ⌘T, ⌘W...) stay as they are.
--
-- Appearance (font, padding, theme) is not configurable here: Rex keeps it
-- in its app settings, which mac-defaults sets to match the Ghostty config.
--
-- Apply with `rex config reload`; Rex does not watch this file.

local P = "ctrl+space>" -- herdr's prefix; Rex writes a prefix as a key sequence

local function bind(keys, action, args)
  for _, key in ipairs(keys) do rex.bind(key, action, args) end
end

-- Config and help
bind({ P .. "q" }, "client.config.reload")
bind({ P .. "shift+/" }, "client.palette.toggle") -- herdr's help; the palette lists every action

-- Panes. herdr's split_horizontal is a horizontal divider (new pane below),
-- split_vertical a vertical one (new pane to the right).
bind({ P .. "h", "alt+enter" }, "pane.split", { direction = "down" })
bind({ P .. "v", "alt+shift+enter" }, "pane.split", { direction = "right" })
bind({ P .. "x", "alt+escape" }, "pane.close")
bind({ P .. "z" }, "pane.zoom")
bind({ P .. ";" }, "pane.focus_previous") -- nearest thing to herdr's last_pane
bind({ P .. "shift+o" }, "pane.rename")

for _, dir in ipairs({ "left", "down", "up", "right" }) do
  bind({ "ctrl+alt+" .. dir }, "pane.focus", { direction = dir })
  bind({ "ctrl+alt+shift+" .. dir }, "pane.resize", { direction = dir })
end

-- herdr's resize mode: prefix then ctrl+arrow enters it, arrows resize,
-- Enter or Escape leaves.
rex.mode("resize", { exclusive = true })
for _, dir in ipairs({ "left", "down", "up", "right" }) do
  bind({ P .. "ctrl+" .. dir }, "client.mode.enter", { name = "resize" })
  bind({ "resize/" .. dir, "resize/ctrl+" .. dir }, "pane.resize", { direction = dir })
end
bind({ "resize/enter" }, "client.mode.exit")

-- Tabs
bind({ P .. "c" }, "client.tab.new")
bind({ P .. "r" }, "client.tab.rename")
bind({ P .. "k" }, "client.tab.close")
bind({ P .. "p", "alt+left" }, "client.tab.previous")
bind({ P .. "n", "alt+right" }, "client.tab.next")
bind({ "alt+shift+left" }, "client.tab.move.backward")
bind({ "alt+shift+right" }, "client.tab.move.forward")
for i = 1, 9 do
  -- [DigitN] is the physical key, so Shift or the layout can't change it.
  bind({ P .. "[Digit" .. i .. "]", "alt+[Digit" .. i .. "]" }, "client.tab.goto", { index = i })
end

-- herdr workspaces -> Rex sessions
bind({ P .. "shift+c" }, "session.new")
bind({ P .. "shift+r" }, "session.rename")
bind({ P .. "shift+k" }, "session.close")
bind({ P .. "shift+p", "alt+up" }, "session.previous")
bind({ P .. "shift+n", "alt+down" }, "session.next")

-- Pressing the prefix twice sends it to the program, as herdr does.
bind({ P .. "ctrl+space" }, "pane.send_key", { key = "ctrl+space" })

-- Not carried over: detach (Rex sessions outlive the app on their own) and
-- copy mode (Rex selects with the mouse; ⌘F finds in the scrollback).
