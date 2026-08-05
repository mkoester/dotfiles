-- Hyprland configuration — PUBLIC skeleton (tracked in dotfiles).
-- Reference: https://wiki.hypr.land/  ·  API stubs: /usr/share/hypr/stubs/hl.meta.lua
--
-- THIS REPO IS PUBLIC. Machine- and device-specific bits (real monitor blocks, an absolute
-- xkb keymap path, Bluetooth MAC addresses) must NOT live here. They go in
-- ~/.config/hypr/local.lua, required by the block at the bottom — the same skeleton +
-- private-overlay pattern as the niri and kanshi packages.
--
-- WHY LUA AND NOT hyprland.conf: hyprlang is deprecated since Hyprland 0.55. 0.56.1 still
-- falls back to a legacy parser when no .lua exists, but that branch is already deleted on
-- upstream `main`. New config is written in Lua. See Workstation-Documentation
-- desktop/wm-comparison.md.
--
-- VALIDATE BEFORE LOGGING IN — it runs offline, no session needed:
--   Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- It catches syntax errors, unknown keys, type errors and nonexistent API calls. It does
-- NOT catch well-typed wrong values (out-of-range numbers, bogus enum values, layouts that
-- do not exist) — measured 2026-08-03, see wm-comparison.md.

local mod  = "SUPER"
local term = "alacritty"

--------------------------------------------------------------------------------
-- Module search path — REQUIRED, do not remove
--------------------------------------------------------------------------------
-- Hyprland resolves `require` relative to the config file's REAL directory. This file is
-- reached through a stow symlink, so that real directory is the dotfiles clone, not
-- ~/.config/hypr — and every require below would look in the wrong place. Measured
-- 2026-08-05: without this, `require("local")` failed with "module 'local' not found"
-- listing paths under config-stow/hypr/, i.e. the machine overlay had never loaded.
local hypr_dir = os.getenv("HOME") .. "/.config/hypr/"
package.path = hypr_dir .. "?.lua;" .. hypr_dir .. "?/init.lua;" .. package.path

-- Optional require: a fragment that is not deployed yet must not abort the whole config.
-- Returns true if the module loaded. Anything genuinely broken still shows up in the log.
local function want(name)
    local ok, err = pcall(require, name)
    if not ok then print("hyprland.lua: skipped '" .. name .. "': " .. tostring(err)) end
    return ok
end

--------------------------------------------------------------------------------
-- Base settings
--------------------------------------------------------------------------------
-- Applied BEFORE the DMS fragments, so anything DMS manages (layout, gaps, decoration,
-- cursor, colors) wins over these. What is left here is what DMS does not own.
hl.config({
    input = {
        kb_layout          = "us",   -- a custom keymap file is machine-specific -> local.lua
        numlock_by_default = true,
        follow_mouse       = 1,
        touchpad           = { natural_scroll = false, tap_to_click = true },
    },
    general = {
        layout = "dwindle",          -- default; scrolling is opted into per workspace below
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        focus_on_activate        = true,
    },
    -- Scrolling layout defaults; only workspaces that opt in below actually use them.
    scrolling = {
        column_width           = 0.5,
        direction              = "right",
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    },
})

-- Generic monitor fallback. Real blocks (connector, mode, scale) are machine-specific and
-- belong in local.lua, which is required last and therefore wins.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

--------------------------------------------------------------------------------
-- DMS (DankMaterialShell) — the shell on every desktop machine
--------------------------------------------------------------------------------
-- OWNERSHIP RULE for this setup: TRACKED = hand-written, UNTRACKED = GUI-written.
--   * this file             — common to all machines, tracked in dotfiles (public)
--   * local.lua             — per machine, tracked in workstation-private
--   * ~/.config/hypr/dms/*  — machine-local, UNTRACKED, written by `dms setup` and by the
--                             DMS Settings GUI (Shortcuts / Displays / Theme / Window Rules)
-- Nothing DMS writes is a symlink into a repo, so DMS can never dirty a tracked file and
-- can never silently replace a stow link.
--
-- DEPLOY THE FRAGMENTS (needs a TTY, prompts for compositor + terminal):
--   dms setup binds && dms setup colors && dms setup layout && dms setup cursor
--   dms setup windowrules
-- Do NOT run plain `dms setup` — it wants to write hyprland.lua itself, which is this
-- tracked file. The per-fragment subcommands only touch ~/.config/hypr/dms/.
--
-- `dms setup outputs` is deliberately NOT in that list: monitors are per-machine and live
-- in local.lua, which loads later and wins. Requiring it anyway so the DMS Displays page
-- can still configure outputs local.lua does not pin (e.g. an external screen).
want("dms.colors")
want("dms.layout")
want("dms.cursor")
want("dms.outputs")
want("dms.windowrules")

-- DMS's default keybinds are the BASE of the bind set (decided 2026-08-05). They are what
-- the SUPER+SHIFT+/ cheatsheet and the Settings > Shortcuts page display, and the media and
-- brightness keys route through `dms ipc` so they raise DMS's on-screen display. Personal
-- additions come after; `dms.binds-user` (GUI-written) comes last so it wins over both.
--
-- Highlights, so this file is readable without launching the cheatsheet:
--   SUPER+T terminal · SUPER+space spotlight · SUPER+V clipboard · SUPER+X powermenu
--   SUPER+comma settings · SUPER+Tab/O overview · SUPER+SHIFT+/ cheatsheet
--   SUPER+Q close · SUPER+F maximize · SUPER+SHIFT+F fullscreen · SUPER+SHIFT+T float
--   SUPER+<dir|hjkl> focus · SUPER+SHIFT+<dir|hjkl> move · SUPER+CTRL+<dir> focus monitor
--   SUPER+<n> workspace · SUPER+SHIFT+<n> move to workspace · SUPER+ALT+L lock
--   SUPER+SHIFT+E exit Hyprland · Print screenshot
local have_dms_binds = want("dms.binds")

--------------------------------------------------------------------------------
-- Personal keybinds — additions only, chosen NOT to collide with DMS defaults
--------------------------------------------------------------------------------
-- Anything DMS already binds is deliberately absent. Re-adding a key here silently wins
-- over DMS (last bind on a key replaces the earlier one) and desyncs the cheatsheet from
-- reality, so add a bind only after checking it against the list above.

-- Applications. SUPER+Return is muscle memory from niri; DMS's own SUPER+T stays too.
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term),       { description = "Terminal" })
hl.bind(mod .. " + B",      hl.dsp.exec_cmd("firefox"),  { description = "Browser" })
hl.bind(mod .. " + E",      hl.dsp.exec_cmd("nautilus"), { description = "File manager" })

-- Named workspace. DMS binds SUPER+1..9 / SUPER+SHIFT+1..9 for the numbered ones; 0 is free
-- and the SHIFT-to-move pattern matches DMS's.
hl.bind(mod .. " + 0",         hl.dsp.focus({ workspace = "name:mail" }),       { description = "Workspace: mail" })
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "name:mail" }), { description = "Move to mail" })

-- Monitor layout (kanshi profiles; define them in the kanshi package's config.d/).
-- Note DMS binds SUPER+P to its own output profile cycling — related but a different
-- mechanism; kanshi stays the source of truth for multi-monitor arrangements here.
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("kanshictl switch docked"), { description = "Monitors: docked" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("kanshictl switch solo"),   { description = "Monitors: solo" })

-- Screenshots on CTRL+SHIFT+<n>: Apple keyboards have no Print key, which is what DMS binds.
-- Routed through `dms screenshot` so both paths behave identically.
hl.bind("CTRL + SHIFT + 1", hl.dsp.exec_cmd("dms screenshot"),        { description = "Screenshot: region" })
hl.bind("CTRL + SHIFT + 2", hl.dsp.exec_cmd("dms screenshot full"),   { description = "Screenshot: screen" })
hl.bind("CTRL + SHIFT + 3", hl.dsp.exec_cmd("dms screenshot window"), { description = "Screenshot: window" })

-- Scrolling-layout motions, on SUPER+ALT+* because the natural keys are all taken by DMS
-- (SUPER+comma = settings, SUPER+bracket* = preselect, SUPER+CTRL+F = maximize).
-- Harmless on tiling workspaces — the layout ignores them.
hl.bind(mod .. " + ALT + period",       hl.dsp.layout("move +col"),     { description = "Scroll: column right" })
hl.bind(mod .. " + ALT + comma",        hl.dsp.layout("move -col"),     { description = "Scroll: column left" })
hl.bind(mod .. " + ALT + bracketright", hl.dsp.layout("colresize +conf"), { description = "Scroll: widen" })
hl.bind(mod .. " + ALT + bracketleft",  hl.dsp.layout("colresize -conf"), { description = "Scroll: narrow" })
hl.bind(mod .. " + ALT + C",            hl.dsp.layout("fit_into_view"), { description = "Scroll: fit into view" })
hl.bind(mod .. " + ALT + F",            hl.dsp.layout("fit expand"),    { description = "Scroll: expand" })

-- Fallbacks for the handful of things DMS would otherwise provide, in case its bind
-- fragment is not deployed on this machine. Only bound when dms.binds did NOT load.
if not have_dms_binds then
    hl.bind(mod .. " + Q",         hl.dsp.window.close())
    hl.bind(mod .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = 1 }))
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen())
    for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d",
                            H = "l", L = "r", K = "u", J = "d" }) do
        hl.bind(mod .. " + " .. key,           hl.dsp.focus({ direction = dir }))
        hl.bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ direction = dir }))
    end
    for i = 1, 9 do
        hl.bind(mod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
        hl.bind(mod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
    end
    hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
end

--------------------------------------------------------------------------------
-- Workspaces
--------------------------------------------------------------------------------
-- niri cannot have named workspaces sort AFTER the numbered ones, so a named workspace
-- always steals a low index (Workstation-Documentation desktop/niri-workspaces.md).
-- Hyprland separates the two namespaces: numbered ids stay 1..9 for SUPER+<n>, and a named
-- workspace is addressed by name and kept alive by `persistent`. This is the whole reason
-- for the move.
hl.workspace_rule({ workspace = "name:mail", persistent = true })

-- TRY SCROLLING HERE. The property no other candidate has: one workspace scrolls,
-- everything else tiles, one line apart. Delete the line to go back to plain tiling.
hl.workspace_rule({ workspace = "2", layout = "scrolling" })

--------------------------------------------------------------------------------
-- Window rules
--------------------------------------------------------------------------------
-- NOTE the limitation, it is the same one niri has: `workspace` is a STATIC effect, applied
-- once at open and matched against initialTitle/initialClass. It cannot re-home a window
-- whose title settles later — which is exactly the restored-Firefox case
-- (desktop/niri-window-placement.md). The Hyprland answer is an event handler; see below.
hl.window_rule({ match = { class = "firefox", title = "^Picture-in-Picture$" }, float = true })
hl.window_rule({ match = { class = "thunderbird", title = "Alias" }, float = true })
hl.window_rule({ match = { class = "thunderbird" }, workspace = "name:mail" })

-- Post-restore Firefox placement, the in-config replacement for
-- ~/.local/bin/place-firefox-windows.sh. Disabled until the Winger window-name prefixes are
-- confirmed to show up in the Wayland title (open item in desktop/niri-window-placement.md).
--
-- hl.on("window.title", function(w)
--     if w == nil or w.title == nil then return end
--     if w.title:match("^mail") then
--         hl.dispatch(hl.dsp.window.move({ workspace = "name:mail" }))
--     end
-- end)

--------------------------------------------------------------------------------
-- Environment
--------------------------------------------------------------------------------
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

--------------------------------------------------------------------------------
-- Autostart
--------------------------------------------------------------------------------
-- DMS is started here rather than from local.lua: it is now the shell on every desktop
-- machine, so it belongs in the common config. It also supplies the polkit agent, which is
-- why nothing else spawns one (only one agent may register per subject).
--
-- NOT via the shipped dms.service systemd unit: that unit is WantedBy/Requisite
-- graphical-session.target, and plain Hyprland (no uwsm installed) never reaches that
-- target — only niri-session does. Spawning it from the compositor works on both.
hl.on("hyprland.start", function()
    hl.exec_cmd("dms run -d")
end)

--------------------------------------------------------------------------------
-- GUI-written bind overrides, then machine overrides — LAST so they win
--------------------------------------------------------------------------------
-- dms/binds-user.lua is what the DMS Settings > Shortcuts page writes, including
-- hl.unbind() lines for DMS defaults deleted there. It must load after the personal binds
-- above so a change made in the GUI actually takes effect.
want("dms.binds-user")

-- ~/.config/hypr/local.lua, symlinked from workstation-private/<hostname>/hypr/local.lua by
-- install.sh. Optional: a machine without one still boots.
want("local")
