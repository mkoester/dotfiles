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
-- SUPER+B was "launch firefox" until 2026-08-10. It now focuses the `browser` workspace
-- instead (below) — which is not a regression, because firefox is pinned there AND the
-- workspace carries `on_created_empty`, so pressing it with no browser running still
-- launches one. Same keystroke, same outcome, plus it now also *returns* you to firefox.
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term),       { description = "Terminal" })
hl.bind(mod .. " + E",      hl.dsp.exec_cmd("nautilus"), { description = "File manager" })

-- Named workspaces — SUPER+<mnemonic letter> to focus, +SHIFT to move a window there.
-- DMS owns SUPER+1..9 / SUPER+SHIFT+1..9 for the numbered ones, which stay entirely free
-- for dynamic use; these letters are the static half. Keeping focus on a plain two-key
-- chord is the whole point ("handy"), so the letters were chosen against the live bind
-- table (`hyprctl -j binds`, 134 binds) rather than guessed:
--
--   SUPER+C / SUPER+G and their SHIFT partners were genuinely unbound.
--   SUPER+S was free but SUPER+SHIFT+S was the kanshi "solo" bind -> kanshi moved to
--     SUPER+ALT+D/S below (both verified free) so the S pair could stay together.
--   SUPER+M is a DMS bind (processlist) and is DELIBERATELY OVERRIDDEN here. Personal
--     binds load after dms.binds, so the last bind on a key wins. Nothing is lost:
--     DMS binds processlist to CTRL+ALT+Delete as well, which is untouched.
--
-- COST OF THE OVERRIDE, per the rule at the top of this section: the SUPER+SHIFT+/
-- cheatsheet is generated by DMS and will still label SUPER+M "processlist". That is the
-- documented price of re-binding a DMS key; it is one key, and the duplicate keeps the
-- function reachable.
--
-- Was SUPER+0/SUPER+SHIFT+0 for mail until 2026-08-10; replaced by the letter scheme so
-- all four named workspaces are reached the same way. 0 is free again.
--   SUPER+B was our own "launch firefox" bind, so reusing it costs nothing external.
local named_workspaces = {
    { key = "M", ws = "mail",    label = "mail"         },
    { key = "B", ws = "browser", label = "browser"      },
    { key = "C", ws = "code",    label = "code"         },
    { key = "G", ws = "google",  label = "google"       },
    { key = "S", ws = "social",  label = "social media" },
}
for _, w in ipairs(named_workspaces) do
    hl.bind(mod .. " + " .. w.key,
            hl.dsp.focus({ workspace = "name:" .. w.ws }),
            { description = "Workspace: " .. w.label })
    hl.bind(mod .. " + SHIFT + " .. w.key,
            hl.dsp.window.move({ workspace = "name:" .. w.ws }),
            { description = "Move to " .. w.label })
end

-- Monitor layout (kanshi profiles; define them in the kanshi package's config.d/).
-- Note DMS binds SUPER+P to its own output profile cycling — related but a different
-- mechanism; kanshi stays the source of truth for multi-monitor arrangements here.
-- Moved off SUPER+SHIFT+D/S on 2026-08-10 to free the S pair for the named workspaces
-- above; SUPER+ALT+D and SUPER+ALT+S were both unbound (the ALT layer holds the scrolling
-- motions, which use C/F/comma/period/brackets/L only).
hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd("kanshictl switch docked"), { description = "Monitors: docked" })
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("kanshictl switch solo"),   { description = "Monitors: solo" })

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
-- The five static workspaces. `persistent` keeps them in the DMS bar even when empty, which
-- is the point of a static workspace — the destination is always there to aim at.
--
-- `on_created_empty` restores the "launcher" half of the old SUPER+B / app binds: focusing an
-- empty named workspace starts its app, so one keystroke means "take me to my browser",
-- whether or not it is already running. Delete the field to get plain focus-only behaviour.
--
-- NOT SET for `code`: no VS Code is installed on this machine (verified 2026-08-10 —
-- `pacman -Qq` lists neither `code`, `visual-studio-code-bin` nor `vscodium-bin`), and the
-- three builds have different binaries. Uncomment the matching line after installing; see
-- the window rules below for the same caveat about the class name.
hl.workspace_rule({ workspace = "name:mail",    persistent = true, on_created_empty = "thunderbird" })
hl.workspace_rule({ workspace = "name:browser", persistent = true, on_created_empty = "firefox" })
hl.workspace_rule({ workspace = "name:google",  persistent = true, on_created_empty = "floorp" })
hl.workspace_rule({ workspace = "name:social",  persistent = true, on_created_empty = "brave" })
hl.workspace_rule({ workspace = "name:code",    persistent = true })
-- hl.workspace_rule({ workspace = "name:code", persistent = true, on_created_empty = "code" })

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

-- App -> static workspace. Class strings are NOT recalled; each was read from the shipped
-- .desktop file's StartupWMClass or off a live window (2026-08-10, mkMac2014):
--   thunderbird  StartupWMClass=thunderbird   (lowercase — this also settles the open
--                question in Workstation-Documentation/desktop/niri-workspaces.md, where
--                the capital-T niri rule was suspected never to have fired)
--   firefox      StartupWMClass=firefox,  confirmed live via `hyprctl -j clients`
--   floorp       StartupWMClass=floorp,   confirmed live via `hyprctl -j clients`
--   brave        StartupWMClass=brave-browser  (package brave-bin, /usr/share/applications)
--
-- Hyprland links libre2, so these match as RE2 regexes — but each variant is written as its
-- own literal rule rather than one alternation, so the config is correct whether matching is
-- regex or literal, and a wrong variant fails visibly (app does not move) instead of quietly.
hl.window_rule({ match = { class = "thunderbird" }, workspace = "name:mail" })
hl.window_rule({ match = { class = "firefox" },     workspace = "name:browser" })
hl.window_rule({ match = { class = "floorp" },      workspace = "name:google" })

-- Brave is Chromium-based: the class differs between native Wayland (lowercase) and XWayland
-- (capitalised), which is the trap called out in desktop/niri-window-placement.md. Both are
-- bound so it lands correctly either way.
hl.window_rule({ match = { class = "brave-browser" }, workspace = "name:social" })
hl.window_rule({ match = { class = "Brave-browser" }, workspace = "name:social" })

-- VS Code — no build is installed on this machine yet, so these class names are the one thing
-- in this block that is NOT measured on a live window. But the build is NOT a guess: this
-- repo's own `config-stow/vscode/` package targets **~/.config/Code/User/settings.json** (and
-- the flatpak path com.visualstudio.code), which is the directory of the OFFICIAL Microsoft
-- build — `visual-studio-code-bin`. Code - OSS uses "Code - OSS" and VSCodium uses "VSCodium",
-- so the tracked settings would not even load under those.
--   => the expected class here is "Code".
-- The other three stay bound as cheap insurance in case a machine installs a different build;
-- they cost nothing and cannot misfire (no other app uses those classes). Confirm and prune
-- once VS Code is actually running:
--   hyprctl -j clients | grep -i class
hl.window_rule({ match = { class = "code-oss" },  workspace = "name:code" })
hl.window_rule({ match = { class = "Code" },      workspace = "name:code" })
hl.window_rule({ match = { class = "codium" },    workspace = "name:code" })
hl.window_rule({ match = { class = "VSCodium" },  workspace = "name:code" })

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
--
-- kanshi likewise has to be spawned here. Under niri the session started it; plain Hyprland
-- starts nothing, so on the first Hyprland login (mkMac2014, 2026-08-06) no kanshi process
-- existed and the two kanshictl binds above were silently dead. kanshi stays the source of
-- truth for monitor arrangements because it is compositor-agnostic (Hyprland ships
-- wlr-output-management-unstable-v1) and the per-machine profiles already live in
-- workstation-private/<host>/kanshi/. DMS has its own output profiles on SUPER+P; that is a
-- second mechanism for the same job, deliberately not adopted.
-- `have kanshi` is not checkable from Lua, so this is a plain exec: on a machine without
-- kanshi it fails once at startup and costs nothing.
hl.on("hyprland.start", function()
    hl.exec_cmd("dms run -d")
    hl.exec_cmd("kanshi")
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
