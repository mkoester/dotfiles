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
-- Anything DMS already binds is deliberately absent.
--
-- BINDS ON THE SAME KEY ACCUMULATE — THEY DO NOT REPLACE (measured 2026-08-10). This comment
-- previously said "the last bind on a key replaces the earlier one", which is FALSE and cost a
-- real bug: SUPER+M moved to the mail workspace *and* opened DMS's process list, both on one
-- press. Hyprland keeps every binding registered for a key and runs them all.
--
-- So taking a key DMS already owns needs an explicit `hl.unbind("<key>")` first. Adding a bind
-- alone gets you both behaviours, which reads as "my bind did not work" only if the other one
-- is visible — a silent second action would just look like a haunted desktop.

-- Applications. SUPER+Return is muscle memory from niri; DMS's own SUPER+T stays too.
--
-- SUPER+B was "launch firefox" until 2026-08-10, when it became the `browser` workspace focus.
-- Losing the launcher was NOT intended and was felt immediately (MK, 2026-08-10): under niri
-- that key spawned a browser window (`MOD+B { spawn-sh "firefox"; }`) and the muscle memory is
-- years old. Both behaviours are wanted, so they now sit on adjacent keys rather than one
-- replacing the other:
--
--   SUPER+B        focus the `browser` workspace          (the 2026-08-10 scheme, unchanged)
--   SUPER+SHIFT+B  move a window to `browser`             (       "        "        "      )
--   SUPER+ALT+B    spawn a new browser window             (RESTORED here)
--
-- ALT is where the other secondary actions already live (kanshi on SUPER+ALT+D/S), and
-- SUPER+ALT+B is free on both sides: absent from this file and from DMS's 100 SUPER binds
-- (`~/.config/hypr/dms/binds.lua` — only ALT+space, SUPER+ALT+L, CTRL+ALT+Delete, ALT+Print
-- use ALT at all). No `hl.unbind` needed; see the accumulation note above for why that matters.
--
-- The command is a bare `firefox`, byte-for-byte what niri spawned, because that is the
-- behaviour being restored and it is the one already known to feel right. Two rejected
-- alternatives, both of which LOOK better and are worse:
--
--   `xdg-open <url>` would follow `xdg-settings get default-web-browser` (firefox.desktop
--     here) instead of hardcoding a browser — but it must be given a URL, and a URL handed to
--     a running Firefox opens a TAB, not a window. Generic in the wrong dimension: it drops
--     the very property asked for.
--   `firefox --new-window` needs a `<url>` argument per `firefox --help`, so it is not simply
--     a stronger form of the bare command.
--
-- Bare `firefox` is right by the help text rather than by assumption: `--new-instance` is
-- documented as "Open new instance, not a new window in running instance", which states that
-- the default for an already-running Firefox is exactly a new window. With none running it
-- starts one. Hardcoding the browser is the accepted cost; change this line if the default
-- browser ever changes.
--
-- Note the `browser` workspace still has NO window rule and NO autostart, deliberately (see
-- the workspace and window-rule sections below): a browser window opens wherever you are, and
-- this key is what makes that convenient again. SUPER+B is then "go where the browsing lives",
-- which is a different question from "give me a window", and the two no longer fight.
hl.bind(mod .. " + Return",  hl.dsp.exec_cmd(term),                     { description = "Terminal" })
hl.bind(mod .. " + E",       hl.dsp.exec_cmd("nautilus"),               { description = "File manager" })
hl.bind(mod .. " + ALT + B", hl.dsp.exec_cmd("firefox"),                { description = "New browser window" })

-- Named workspaces — SUPER+<mnemonic letter> to focus, +SHIFT to move a window there.
-- DMS owns SUPER+1..9 / SUPER+SHIFT+1..9 for the numbered ones, which stay entirely free
-- for dynamic use; these letters are the static half. Keeping focus on a plain two-key
-- chord is the whole point ("handy"), so the letters were chosen against the live bind
-- table (`hyprctl -j binds`, 134 binds) rather than guessed:
--
--   SUPER+C / SUPER+G and their SHIFT partners were genuinely unbound.
--   SUPER+S was free but SUPER+SHIFT+S was the kanshi "solo" bind -> kanshi moved to
--     SUPER+ALT+D/S below (both verified free) so the S pair could stay together.
--   SUPER+M is a DMS bind (processlist) and is DELIBERATELY TAKEN here, via `unbind`.
--     Nothing is lost: DMS binds processlist to CTRL+ALT+Delete as well, untouched.
--
-- COST OF TAKING A DMS KEY: the SUPER+SHIFT+/ cheatsheet is generated by DMS and will still
-- label SUPER+M "processlist" and SUPER+T "terminal". One stale label each; the functions stay
-- reachable (CTRL+ALT+Delete, and spotlight for ghostty).
--
-- Was SUPER+0/SUPER+SHIFT+0 for mail until 2026-08-10; replaced by the letter scheme so
-- all four named workspaces are reached the same way. 0 is free again.
--   SUPER+B was our own "launch firefox" bind, so reusing it cost nothing EXTERNAL — but it
--     did cost the launcher, which turned out to matter. That moved to SUPER+ALT+B rather
--     than being dropped; see the applications block above.
--   SUPER+A was free. Mnemonic is "agents" — herdr is the agent terminal manager.
--   SUPER+T is DMS's ghostty launcher and is TAKEN (MK, 2026-08-10), also via `unbind`.
--     A slightly worse deal than SUPER+M because it is not duplicated elsewhere: ghostty must
--     now be launched from spotlight (SUPER+space). SUPER+Return still opens alacritty.
--
-- `takes_dms_key` marks the two entries whose key DMS already binds. Without the unbind, BOTH
-- actions fire on one press — that is not theory, it is what SUPER+M did: focused the mail
-- workspace and opened the process list together.
--
-- `no_move` — SUPER+SHIFT+T is DMS's FLOAT TOGGLE, which is genuinely useful and has no second
-- binding, unlike the processlist behind SUPER+M. So `term` gets a focus bind only rather than
-- silently costing float. Uncomment the line below the loop if you want the move bind and are
-- happy to lose float toggle; SUPER+ALT+T is free if you would rather keep both.
local named_workspaces = {
    { key = "M", ws = "mail",    label = "mail",         takes_dms_key = true },
    { key = "B", ws = "browser", label = "browser"      },
    { key = "C", ws = "code",    label = "code"         },
    { key = "G", ws = "google",  label = "google"       },
    { key = "S", ws = "social",  label = "social media" },
    { key = "A", ws = "herdr",   label = "herdr"        },
    { key = "T", ws = "term",    label = "terminal", no_move = true, takes_dms_key = true },
}
for _, w in ipairs(named_workspaces) do
    -- Remove DMS's binding first, or both actions fire on the same press.
    if w.takes_dms_key then hl.unbind(mod .. " + " .. w.key) end
    hl.bind(mod .. " + " .. w.key,
            hl.dsp.focus({ workspace = "name:" .. w.ws }),
            { description = "Workspace: " .. w.label })
    if not w.no_move then
        hl.bind(mod .. " + SHIFT + " .. w.key,
                hl.dsp.window.move({ workspace = "name:" .. w.ws }),
                { description = "Move to " .. w.label })
    end
end
-- Move-to-term, off by default (see `no_move` above). Pick ONE:
-- hl.bind(mod .. " + SHIFT + T", hl.dsp.window.move({ workspace = "name:term" }))  -- costs float toggle
-- hl.bind(mod .. " + ALT + T",   hl.dsp.window.move({ workspace = "name:term" }))  -- keeps both

-- Monitor layout (kanshi profiles; define them in the kanshi package's config.d/).
-- Note DMS binds SUPER+P to its own output profile cycling — related but a different
-- mechanism; kanshi stays the source of truth for multi-monitor arrangements here.
-- Moved off SUPER+SHIFT+D/S on 2026-08-10 to free the S pair for the named workspaces
-- above; SUPER+ALT+D and SUPER+ALT+S were both unbound (the ALT layer holds the scrolling
-- motions, which use C/F/comma/period/brackets/L only).
hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd("kanshictl switch docked"), { description = "Monitors: docked" })
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("kanshictl switch solo"),   { description = "Monitors: solo" })

-- Keybind cheat sheet, on DMS's own cheat-sheet key. TAKEN DELIBERATELY (MK, 2026-08-10) via
-- unbind, because ours strictly supersedes it: DMS renders its OWN static bind list and cannot
-- see `hl.unbind()`, so its sheet still labels SUPER+M "processlist" and SUPER+T "terminal" —
-- the two keys this config took. `hyprbinds` reads `hyprctl -j binds` instead, so an unbound key
-- is simply absent and the sheet cannot go stale.
--
-- Without the unbind BOTH sheets open on one press (binds accumulate — see the note above).
--
-- ABSOLUTE PATH, NOT A BARE `hyprbinds`. ~/.local/bin is put on PATH by .zshrc, i.e. only for
-- INTERACTIVE shells — a process the compositor spawns inherits the session environment, where
-- nothing has added it. A bare name therefore fails to exec, alacritty exits instantly, and the
-- keybind looks dead with no error anywhere. herdr and alacritty are unaffected because they
-- live in /usr/bin. Built from $HOME so no home directory is hardcoded, same as the xkb path.
--
-- The window is sized by the window rules below, NOT here. An earlier version passed
-- `-o window.dimensions.columns=… lines=…` to alacritty as a workaround while rule-based sizing
-- appeared broken; that turned out to be a rule-ordering bug (see the rules), so the workaround
-- was removed rather than left as a second mechanism fighting the first. `window.dimensions`
-- does work and sizes in CELLS — reach for it if the sheet should ever track the font size
-- instead of the monitor.
local cheatsheet = os.getenv("HOME") .. "/.local/bin/hyprbinds"
hl.unbind(mod .. " + SHIFT + Slash")
hl.bind(mod .. " + SHIFT + Slash",
        hl.dsp.exec_cmd("alacritty --class hyprbinds -e " .. cheatsheet .. " --fzf"),
        { description = "Keybind cheat sheet" })

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
-- `on_created_empty` IS REMOVED FROM ALL OF THEM — it never fires on a `persistent` workspace
-- (measured 2026-08-10, twice and independently):
--   * after a real reboot every named workspace came up empty and nothing launched;
--   * navigating to the empty `google` workspace with SUPER+G launched nothing either.
-- The explanation that fits both: `persistent` means the workspace is created once, at config
-- load, and then always exists — so it is never "created empty" again, and navigating to an
-- already-existing workspace is not a creation. The two options are therefore mutually
-- defeating, which nothing in the docs says.
--
-- => Anything wanted at login is exec'd from the `hyprland.start` handler at the bottom of this
--    file (thunderbird + herdr), and each app reaches its workspace via its WINDOW RULE.
--    Dropping `persistent` would presumably make on_created_empty work, at the cost of the
--    always-visible bar entries that are the whole point of a static workspace. Not tested.
--
-- `browser` deliberately has NEITHER an autostart NOR a window rule (MK, 2026-08-10):
-- firefox must be openable on any workspace and must not autostart. The workspace still
-- exists and SUPER+B still focuses it — it is simply a destination you move windows to by
-- hand (SUPER+SHIFT+B) rather than one that claims every firefox window.
--
-- BAR ORDER IS ALPHABETICAL BY NAME — declaration order here does NOT affect it. DMS sorts
-- numbered workspaces first by id, then all named ones together: every named workspace maps to
-- the same sort key, so the tiebreak is `localeCompare` on the name
-- (`WorkspaceSwitcher.qml:257`, hyprlandWorkspaceOrder). So the bar reads
--   browser · code · google · herdr · mail · social · term
-- and the ONLY way to move one is to rename it. Accepted as-is 2026-08-10 (the request was for
-- `herdr` left of `code`, which no config change can deliver while it is called "herdr").
hl.workspace_rule({ workspace = "name:mail",    persistent = true })
hl.workspace_rule({ workspace = "name:browser", persistent = true, layout = "scrolling" })
hl.workspace_rule({ workspace = "name:code",    persistent = true, layout = "scrolling" })
hl.workspace_rule({ workspace = "name:google",  persistent = true })
hl.workspace_rule({ workspace = "name:social",  persistent = true })

-- herdr is a terminal app with no class of its own, so it is not pinned by an app rule; it is
-- launched at login with `--class herdr`, which invents a class the window rule below can match.
hl.workspace_rule({ workspace = "name:herdr",   persistent = true })

-- term: deliberately bare — a scratch terminal workspace, nothing pinned, nothing autostarted.
-- `code` likewise: visual-studio-code-bin IS installed and its window rule works, it is simply
-- not wanted at login. Add either to the hyprland.start handler if that changes.
hl.workspace_rule({ workspace = "name:term",    persistent = true })

-- Numbered workspace 2 carried `layout = "scrolling"` as the original "try scrolling here"
-- experiment. Removed 2026-08-10: scrolling is now a deliberate choice on `browser` and `code`
-- above, so leaving a numbered workspace silently scrolling as well is just a surprise. The
-- per-workspace scrolling layout — one workspace scrolls, everything else tiles, one line
-- apart — is still the property no other candidate WM had; it is simply pointed at the right
-- workspaces now.

--------------------------------------------------------------------------------
-- Window rules
--------------------------------------------------------------------------------
-- NOTE the limitation, it is the same one niri has: `workspace` is a STATIC effect, applied
-- once at open and matched against initialTitle/initialClass. It cannot re-home a window
-- whose title settles later — which is exactly the restored-Firefox case
-- (desktop/niri-window-placement.md). The Hyprland answer is an event handler; see below.
hl.window_rule({ match = { class = "firefox", title = "^Picture-in-Picture$" }, float = true })
hl.window_rule({ match = { class = "org.mozilla.Thunderbird", title = "Alias" }, float = true })

-- App -> static workspace. EVERY class below was read off a LIVE WINDOW with
-- `hyprctl -j clients | grep -i class` (2026-08-10, mkMac2014) — no guesses, no .desktop files.
--
-- WHY THAT SENTENCE IS EMPHATIC: this block previously used classes taken from
-- `StartupWMClass`, and TWO of the four were wrong in a way that failed silently.
--
--   Thunderbird  .desktop said `thunderbird`  ->  actually `org.mozilla.Thunderbird`
--   VS Code      guessed `Code`/`code-oss`    ->  actually `code`
--
-- The real pattern is not capitalisation and NOT XWayland (an earlier note here blamed a
-- capitalised XWayland WM_CLASS — that was wrong): modern Wayland apps set a **reverse-DNS
-- app_id**, while `StartupWMClass` in the .desktop file still carries the legacy X11-era short
-- name. Both live here at once — `org.mozilla.Thunderbird` and `com.mitchellh.ghostty` are
-- reverse-DNS, while `firefox`, `floorp`, `brave-browser` and `code` are short names. Nothing
-- about the app tells you which style it uses. So: **read the live window, every time.**
--
-- Hyprland links libre2 so these match as RE2 regexes, but each is written as a plain literal:
-- a wrong literal fails visibly (the app does not move) rather than quietly matching too much.
hl.window_rule({ match = { class = "org.mozilla.Thunderbird" }, workspace = "name:mail" })
hl.window_rule({ match = { class = "floorp" },                  workspace = "name:google" })
hl.window_rule({ match = { class = "brave-browser" },           workspace = "name:social" })
hl.window_rule({ match = { class = "code" },                    workspace = "name:code" })

-- The herdr terminal, matched on the custom class set by `alacritty --class herdr` in the login
-- autostart at the bottom of this file. Plain Alacritty windows are class
-- "Alacritty" and are deliberately NOT matched here — they must stay openable anywhere, the
-- same reasoning as firefox below.
hl.window_rule({ match = { class = "herdr" }, workspace = "name:herdr" })

-- The cheat sheet floats and stays on the CURRENT workspace — deliberately no `workspace`
-- field, unlike every rule above: a reference you open mid-task must not yank you elsewhere.
-- Same `--class` trick as herdr, since a terminal has no class of its own to match on.
-- TWO RULES, NOT ONE — the split is what makes sizing work at all, confirmed 2026-08-10.
-- As a single `{ match = …, float = true, size = … }` the window came up 800x600 (Hyprland's
-- default float size, read from `hyprctl -j clients`): the float took effect and the size was
-- silently dropped. A Lua table has NO defined iteration order, so the effects can be applied
-- in any order, and sizing a window that is not floating YET is a no-op. Declared as separate
-- rules, float lands first and the size sticks.
--
-- Three things follow, all of which cost a round of trial and error here:
--   * `Hyprland --verify-config` says `config ok` for the broken form. It validates field NAMES
--     (an invented one gives "unknown field 'x'") and cannot see application order.
--   * "no effect" and "wrong value" are indistinguishable without measuring: 800x600 is neither
--     the rule's size nor alacritty's own window.dimensions, which is what finally gave it away.
--
-- PIXELS ONLY — a PERCENTAGE STRING IS SILENTLY IGNORED HERE. `size = "40% 70%"` validates and
-- then leaves the window at the 800x600 default, measured on BOTH monitors (2026-08-10) in the
-- split-rule form that demonstrably works with pixels. So this is not the ordering bug above and
-- not a monitor-dependent effect: the percentage form itself does nothing in a Lua window rule
-- on 0.56.2. Percentages were briefly assumed innocent because they had only been tried inside
-- the broken combined rule; that assumption was wrong and cost a round.
--
-- Consequence, accepted: the size is absolute, so the window is the same on the 3440 ultrawide
-- and the 2560 panel rather than proportional to each. The sheet needs ~100 columns, so keep the
-- width comfortably above ~900px. If proportional sizing is ever wanted, alacritty's
-- `window.dimensions` (cells) is the working alternative — not a percentage here.
hl.window_rule({ match = { class = "hyprbinds" }, float = true })
hl.window_rule({ match = { class = "hyprbinds" }, size = { 900, 1000 } })

-- If login focus-jumping becomes annoying (both autostarted apps open on workspaces you are not
-- on, and `focus_on_activate = true` is set at the top), add `no_initial_focus = true` to these
-- two rules — verified a valid field. Left off because it also affects manual launches.

-- NO firefox -> name:browser rule, on purpose. A new firefox window must be able to open on
-- whatever workspace you are on; pinning it would yank every window to `browser`. This also
-- removes the last reason the PiP float rule above was awkward — a Picture-in-Picture window
-- now stays put instead of being re-homed along with its parent.

-- Brave and VS Code moved up into the measured block above (2026-08-10). Both had guessed
-- classes here — Brave carried a `Brave-browser` XWayland variant that never applied (it runs
-- native Wayland as `brave-browser`), and VS Code had FOUR guesses, none of which was the real
-- `code`, so the `code` workspace had silently never worked. The build guess was right
-- (`visual-studio-code-bin` is what is installed, and ~/.config/Code/User/settings.json is a
-- live stow symlink) — the CLASS guess derived from it was not. Getting the package right does
-- not get the class right.

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
--
-- LOGIN AUTOSTART (2026-08-10). This is the ONLY launcher: `on_created_empty` never fires on a
-- `persistent` workspace at all — not at boot and not on navigation either (see the workspace
-- section above, measured twice). Anything wanted at login has to be exec'd here.
--
-- Placement is not this handler's job: each app lands on its workspace by its WINDOW RULE, not by
-- which workspace happens to be focused, so it does not matter that these run before any
-- workspace is visited.
--
-- Only these two autostart, by request — the browsers stay manual.
--
-- kanshi is spawned with its output KEPT. History (mkDell, 2026-08-09): the
-- bare `hl.exec_cmd("kanshi")` that used to be here started kanshi at login and it EXITED,
-- leaving no daemon — `kanshictl` then fails with "Couldn't connect to kanshi at
-- $XDG_RUNTIME_DIR/… Is the kanshi daemon running?", which reads like a broken profile and
-- is not: the same config applies cleanly when kanshi is run by hand a minute later.
--
-- What it actually was, as far as the evidence goes: at that login
-- ~/.config/kanshi/config.d/ held only .gitkeep, so the PUBLIC skeleton's generic `docked`
-- profile applied — and on this machine that puts a 2560-wide output at 1920,0 against a
-- 3440-wide primary, a 1520 px overlap. Once the machine's own profile was linked, kanshi
-- succeeded on the FIRST attempt at the next login (one "--- hyprland.start" in the log,
-- then a clean apply, no retry). So the thing that fixed it was the profile, and this loop
-- is unproven insurance against a slow-start race that may not exist.
--
-- So all that is kept is the LOG, which is the half that earned its place: it is what turned
-- "the daemon isn't running" into a readable cause. The leading echo means the log's mere
-- existence proves this wrapper ran, so "no log" and "log with an error" are different
-- findings rather than one ambiguous silence. A retry loop stood here briefly and was
-- dropped: it never fired even on the failing machine, so it was insurance against a race
-- nothing has yet shown to exist.
--   Check after a login:  pgrep -af kanshi ; cat $XDG_RUNTIME_DIR/kanshi-start.log
hl.on("hyprland.start", function()
    hl.exec_cmd("dms run -d")
    hl.exec_cmd([[sh -c '{ echo "--- hyprland.start"; exec kanshi; } >>$XDG_RUNTIME_DIR/kanshi-start.log 2>&1']])

    -- -> name:mail via the thunderbird window rule.
    hl.exec_cmd("thunderbird")

    -- -> name:herdr via the `herdr` class rule. `--class` is what makes this pinnable at all:
    -- a bare `alacritty` is class "Alacritty" like every other terminal, so a rule on it would
    -- drag EVERY terminal to the herdr workspace. Keep this command identical to the one in the
    -- workspace's on_created_empty, or the two paths produce differently-classed windows.
    hl.exec_cmd("alacritty --class herdr -e herdr")
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
