-- Hyprland configuration — PUBLIC skeleton (tracked in dotfiles).
-- Reference: https://wiki.hypr.land/  ·  API stubs: /usr/share/hypr/stubs/hl.meta.lua
--
-- THIS REPO IS PUBLIC. Machine- and device-specific bits (real monitor blocks, an absolute
-- xkb keymap path, Bluetooth MAC addresses, which shell this machine runs) must NOT live
-- here. They go in ~/.config/hypr/local.lua, required by the optional block at the bottom —
-- the same skeleton + private-overlay pattern as the niri and kanshi packages.
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
-- Monitors
--------------------------------------------------------------------------------
-- Generic fallback only. Real monitor blocks (connector, mode, scale) are machine-specific
-- and belong in local.lua. `hl.monitor` entries accumulate; the later one wins.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
hl.config({
    input = {
        kb_layout          = "us",   -- a custom keymap file is machine-specific -> local.lua
        numlock_by_default = true,
        follow_mouse       = 1,      -- focus follows mouse, matching the niri config
        touchpad           = { natural_scroll = false, tap_to_click = true },
    },
    general = {
        gaps_in     = 8,
        gaps_out    = 16,            -- niri config uses gaps 16
        border_size = 3,
        layout      = "dwindle",     -- default; scrolling is opted into per workspace below
    },
    decoration = {
        rounding = 20,               -- matches the niri window-rule corner radius
        shadow   = { enabled = true, range = 30, offset = { 0, 5 } },
    },
    animations = { enabled = true },
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

--------------------------------------------------------------------------------
-- Workspaces — the whole reason for the move off niri
--------------------------------------------------------------------------------
-- niri cannot have named workspaces sort AFTER the numbered ones, so a named workspace
-- always steals a low index (Workstation-Documentation desktop/niri-workspaces.md).
-- Hyprland separates the two namespaces: numbered ids stay 1..9 for SUPER+<n>, and a named
-- workspace is addressed by name and kept alive by `persistent`.
--
-- Start with ONE named workspace as the pattern; add chat/editor once it proves out.
hl.workspace_rule({ workspace = "name:mail", persistent = true })

-- TRY SCROLLING HERE. This is the property no other candidate has: one workspace scrolls,
-- everything else tiles, one line apart. Delete the line to go back to plain tiling.
hl.workspace_rule({ workspace = "2", layout = "scrolling" })

--------------------------------------------------------------------------------
-- Keybinds — deliberately mirroring config-stow/niri/.config/niri/config.kdl
--------------------------------------------------------------------------------

-- Applications
hl.bind(mod .. " + Return",   hl.dsp.exec_cmd(term),      { description = "Terminal" })
hl.bind(mod .. " + B",        hl.dsp.exec_cmd("firefox"), { description = "Browser" })
hl.bind(mod .. " + E",        hl.dsp.exec_cmd("nautilus"),{ description = "File manager" })
-- Guarded: not every machine installs wofi (the Macs run the Noctalia launcher instead and
-- repoint this bind in local.lua). An unguarded spawn of a missing binary just logs noise.
hl.bind(mod .. " + Space",    hl.dsp.exec_cmd("command -v wofi >/dev/null && wofi"), { description = "Launcher" })
-- hyprlock, not swaylock: it authenticates the fingerprint reader itself over fprintd's
-- D-Bus API. Config comes from config-stow/hyprlock/.
hl.bind(mod .. " + ALT + L",  hl.dsp.exec_cmd("pidof hyprlock >/dev/null || hyprlock"), { description = "Lock" })

-- Window management
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = 1 }))  -- maximize, keeps decorations

-- Focus: arrows and hjkl, same as the niri config
for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down",
                        H = "left", L = "right", K = "up", J = "down" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- Workspaces: SUPER+<n> focus, SUPER+CTRL+<n> move window (CTRL, as in the niri config —
-- Hyprland's own default is SHIFT, but muscle memory wins).
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,          hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + CTRL + " .. i,   hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0",        hl.dsp.focus({ workspace = "name:mail" }))
hl.bind(mod .. " + CTRL + 0", hl.dsp.window.move({ workspace = "name:mail" }))
hl.bind(mod .. " + Tab",      hl.dsp.focus({ workspace = "previous" }))

-- Mouse wheel over workspaces, as in niri
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Scrolling-layout motions. Harmless on tiling workspaces (the layout ignores them), so
-- they are bound unconditionally rather than per workspace.
hl.bind(mod .. " + period",       hl.dsp.layout("move +col"))
hl.bind(mod .. " + comma",        hl.dsp.layout("move -col"))
hl.bind(mod .. " + bracketright", hl.dsp.layout("colresize +conf"))
hl.bind(mod .. " + bracketleft",  hl.dsp.layout("colresize -conf"))
hl.bind(mod .. " + C",            hl.dsp.layout("fit_into_view"))
hl.bind(mod .. " + CTRL + F",     hl.dsp.layout("fit expand"))

-- Audio / brightness. locked=true keeps them working on the lock screen (niri:
-- allow-when-locked=true).
local media = {
    { "XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 0.1+" },
    { "XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-" },
    { "XF86AudioMute",        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { "XF86AudioMicMute",     "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { "XF86AudioNext",        "playerctl next" },
    { "XF86AudioPrev",        "playerctl previous" },
    { "XF86AudioPlay",        "playerctl play-pause" },
    { "XF86AudioPause",       "playerctl play-pause" },
    { "XF86MonBrightnessUp",  "brightnessctl -e4 -n2 set 5%+" },
    { "XF86MonBrightnessDown","brightnessctl -e4 -n2 set 5%-" },
}
for _, m in ipairs(media) do
    hl.bind(m[1], hl.dsp.exec_cmd(m[2]), { locked = true, repeating = true })
end

-- Monitor layout (kanshi profiles; define them in the kanshi package's config.d/)
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("kanshictl switch docked"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("kanshictl switch solo"))

-- Screenshots. niri has these built in; Hyprland does not, so shell out — guarded, because
-- the tool set differs per machine (grim+slurp here, hyprshot/grimblast elsewhere).
hl.bind("CTRL + SHIFT + 1", hl.dsp.exec_cmd("command -v slurp >/dev/null && grim -g \"$(slurp)\" - | wl-copy"))
hl.bind("CTRL + SHIFT + 2", hl.dsp.exec_cmd("command -v grim >/dev/null && grim - | wl-copy"))

-- Exit / power
hl.bind(mod .. " + SHIFT + P", hl.dsp.dpms("off"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())

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
-- NO BAR AND NO POLKIT AGENT ARE SPAWNED HERE — deliberately, for the same reason as the
-- niri skeleton: which shell a machine runs (waybar+wofi vs Noctalia vs DMS) is a per-machine
-- decision, and only one polkit agent may register per subject. Machines spawn their own from
-- local.lua, e.g.  hl.on("hyprland.start", function() hl.exec_cmd("qs -c noctalia-shell") end)

--------------------------------------------------------------------------------
-- Machine-/device-specific overrides — required LAST so it wins
--------------------------------------------------------------------------------
-- ~/.config/hypr/local.lua, symlinked from workstation-private/<hostname>/hypr/local.lua by
-- install.sh. pcall so a machine without one still boots: a plain require() would abort the
-- whole config with "module 'local' not found".
-- (There is no hl.log in the API — plain print() goes to the Hyprland log.)
local ok, err = pcall(require, "local")
if not ok then
    print("hyprland.lua: no local.lua overlay loaded: " .. tostring(err))
end
