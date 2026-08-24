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

-- GHOSTTY EVERYWHERE SINCE 2026-08-10 — provisional, under evaluation for a few days (MK).
-- Was alacritty. This variable is the default terminal (SUPER+Return); the three class-pinned
-- launchers were moved in the same pass, so alacritty is no longer spawned anywhere.
--
-- THE CLASS NAMES HAD TO CHANGE, and that is the whole risk of this switch. Those launchers
-- exist to invent a class for a window rule to pin on, and ghostty will not take the old
-- single-word names. src/config/Config.zig:1504: "The class name must follow the requirements
-- defined in the GTK documentation" (g_application_id_is_valid) — AT LEAST TWO period-separated
-- elements, no leading digit, `[A-Za-z0-9_-]` plus periods. So:
--
--     herdr      -> mk.herdr        (login autostart, bottom of this file)
--     hyprbinds  -> mk.hyprbinds    (cheat sheet, below)
--     monitors   -> mk.monitors     (kanshi layout picker, SUPER+P)
--     git        -> mk.git          (gitaw, mkDell/hypr/local.lua)
--     switcher   -> mk.switcher     (ALT+TAB MRU window switcher, below)
--
-- Each rename touches TWO places — the launcher and its window rule — and they must move
-- together or the window silently lands unpinned.
--
-- THE FAILURE MODE IS SILENT, so verify by measurement rather than by reading this file.
-- Ghostty's config PARSER accepts an invalid class perfectly happily (measured: `class = herdr`
-- echoes back fine from `ghostty +show-config`); GTK rejects it later and the window simply
-- carries the default `com.mitchellh.ghostty` instead. Nothing is logged. After any change here:
--
--     hyprctl -j clients | grep -i class
--
-- A window class is only knowable from a running window — a config file, a .desktop file or
-- this comment are all predictions.
--
-- Two further caveats from the same source note, both accepted. A non-default class changes the
-- DBus bus name, so it "may break launching Ghostty from .desktop files, via DBus activation, or
-- systemd user services" — irrelevant here, since these three are compositor-spawned and the
-- ordinary launcher path still uses the default class. And a differing class spawns a separate
-- instance under `gtk-single-instance`; the default is `detect`, which does not apply to CLI
-- launches, so these are separate processes by design rather than by accident.
--
-- REVERTING is a single pass: put "alacritty" back here, change the three launchers back to
-- `alacritty --class <name>`, and drop the `mk.` prefix from the three window rules.
local term = "ghostty"

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
        -- SCROLLING EVERYWHERE since 2026-08-11 (was "dwindle" with a per-workspace opt-in on
        -- `browser` and `code`). The per-workspace split was abandoned because it makes every
        -- scrolling-specific bind a key that silently does nothing on 5 of 7 workspaces — see
        -- the SUPER+F note further down, which is the case that forced the decision.
        layout = "scrolling",
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        focus_on_activate        = true,
    },
    binds = {
        -- niri's behaviour, restored (2026-08-14): pressing the focus key of the workspace you
        -- are ALREADY on takes you back to the previous one. `workspace_back_and_forth` is the
        -- switch itself; `allow_workspace_cycles` is what lets it be pressed repeatedly, since
        -- without it a workspace forgets where you came from ("workspaces don't forget their
        -- previous workspace" — the binary's own description).
        --
        -- CONFIRMED WORKING (MK, 2026-08-14), back when these were true NAMED workspaces reached
        -- by `focus({workspace = "name:mail"})` — which was the uncertain case, since every
        -- description of the option talks about workspace *ids*. They are numbered workspaces
        -- as of 2026-08-15, i.e. the case the option is actually documented for, so this is now
        -- safer than when it was verified. No `focus({workspace = "previous"})` bind is needed.
        workspace_back_and_forth = true,
        allow_workspace_cycles   = true,
    },
    -- Scrolling layout settings. These now apply to EVERY workspace (see general.layout).
    -- `explicit_column_widths` is the preset list SUPER+F cycles through.
    scrolling = {
        column_width           = 0.5,
        direction              = "right",
        -- Default is TRUE, i.e. focusing right from the last column jumps to the first.
        -- Turned off 2026-08-11: at the edge the layout then resolves the target to the
        -- column you are already on, so focus stays put (`ScrollingAlgorithm.cpp:1509/1532`).
        -- Matches niri, which does not wrap either.
        wrap_focus             = false,
        -- TWO values on purpose (2026-08-11): this list is read by nothing except the
        -- `colresize +conf` / `-conf` messages, which step to the next larger/smaller entry
        -- and wrap at the end. With exactly two, SUPER+F becomes a plain 0.5 <-> 1.0 toggle,
        -- which is what is wanted. Was "0.333, 0.5, 0.667, 1.0" — a four-step cycle that
        -- needed three presses to get back to where it started.
        explicit_column_widths = "0.5, 1.0",
    },
})

-- HOW TO DEBUG A HANDLER IN THIS FILE (learned the hard way 2026-08-19, cost four empty probes).
-- Lua `print` works and is emitted at DEBUG level tagged `[Lua]`, but reaching it needs BOTH:
--
--   1. `hl.config({ debug = { disable_logs = false } })` — without it nothing is written to the
--      log file. There is no `debug` block here normally, so this is off by default.
--   2. Reading the LOG FILE, not `hyprctl rollinglog`:
--        grep 'BW[D]EBUG' "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"
--      `rollinglog` is an in-memory buffer that does NOT carry `[Lua]` prints. It happily shows
--      other DEBUG lines, so it looks live while silently dropping exactly what you added.
--
-- Two traps that made this expensive. `--verify-config` DOES print — it logs to stdout before
-- disabling stdout logs — so a print verified there proves nothing about a running session. And
-- grepping rollinglog for your own marker matches the TERMINAL WINDOW'S TITLE, because Hyprland
-- logs every title change and your title is the command you just typed: bracket one character
-- (`BW[D]EBUG`) so the pattern cannot match itself.
--
-- Also settled: `hyprctl reload` DOES re-execute this file (a top-level print appeared once per
-- reload), and handlers registered with `hl.on` do NOT accumulate across reloads the way keybinds
-- do — one popup produced exactly one `match` line per title change after three reloads.

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
--   SUPER+Q close · SUPER+F maximize (REBOUND below) · SUPER+SHIFT+F fullscreen · SUPER+SHIFT+T float
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
--     now be launched from spotlight (SUPER+space). SUPER+Return opens `term` (ghostty since
--     2026-08-10), so a plain ghostty window is in fact still one keypress away.
--
-- `takes_dms_key` marks the two entries whose key DMS already binds. Without the unbind, BOTH
-- actions fire on one press — that is not theory, it is what SUPER+M did: focused the mail
-- workspace and opened the process list together.
--
-- `no_move` — SUPER+SHIFT+T is DMS's FLOAT TOGGLE, which is genuinely useful and has no second
-- binding, unlike the processlist behind SUPER+M. So `term` gets a focus bind only rather than
-- silently costing float. Uncomment the line below the loop if you want the move bind and are
-- happy to lose float toggle; SUPER+ALT+T is free if you would rather keep both.
-- NUMBERED WORKSPACES WITH NAMES, NOT NAMED WORKSPACES (changed 2026-08-15). Each entry now
-- carries an explicit `id`, and the workspace rules below declare it as a NUMBERED workspace
-- with `default_name` — so it has a POSITIVE id and still displays its name in the bar.
--
-- Why: Hyprland gives a purely named workspace a negative id (measured here: -1345 … -1337),
-- and DMS's overview (SUPER+O) tests `workspaceValue > 0` in three places
-- (`OverviewWidget.qml` — `workspaceExists`, `hasWindows`, and the window filter's
-- `minId…maxId` range). With every workspace negative it built its cell list from
-- `maxExisting + 1` upward, i.e. ~-1336 up — SYNTHETIC ids matching no workspace — so the
-- overview drew empty cells labelled with nonsense numbers and filtered out every window,
-- which is why it showed no icons and no previews. Positive ids satisfy all three gates.
--
-- The bar still shows NAMES: `getWorkspaceIndex` (`WorkspaceSwitcher.qml`) returns
-- `modelData.name` whenever it is non-empty, whatever the id's sign, and this fleet runs
-- `"showWorkspaceName": true` with `"showWorkspaceIndex": false`.
--
-- SECOND BENEFIT, AND IT UNDOES A DOCUMENTED IMPOSSIBILITY: bar order is now OURS. DMS maps
-- every *named* workspace to one sort key and tiebreaks on `localeCompare(name)`, which is why
-- "herdr left of code" was previously unachievable without renaming. Positive ids sort by id,
-- so the order below is exactly what the bar renders.
--
-- IDS START AT 11, NOT 1 (MK, 2026-08-15) — 1-10 stay free for ad-hoc numbered workspaces, and
-- DMS's SUPER+1…9 keep reaching those rather than these. Two consequences to expect:
--   * the SUPER+<n> keys are NOT synonyms for the mnemonic keys;
--   * the overview builds its cells as `1..maxExisting`, so it shows 1-10 as empty cells above
--     these. That is the cost of the offset, and they stop being empty the moment you use one.
--
-- 19 IS RESERVED for `git`, which is machine-specific and lives in mkDell's local.lua. Do not
-- claim it here.
local named_workspaces = {
    { id = 11, key = "M", ws = "mail",    label = "mail",         takes_dms_key = true },
    { id = 12, key = "B", ws = "browser", label = "browser"      },
    { id = 13, key = "A", ws = "herdr",   label = "herdr"        },
    { id = 14, key = "C", ws = "code",    label = "code"         },
    { id = 15, key = "G", ws = "google",  label = "google"       },
    { id = 16, key = "S", ws = "social",  label = "social media" },
    { id = 17, key = "T", ws = "term",    label = "terminal", no_move = true, takes_dms_key = true },
}
for _, w in ipairs(named_workspaces) do
    -- Remove DMS's binding first, or both actions fire on the same press.
    if w.takes_dms_key then hl.unbind(mod .. " + " .. w.key) end
    hl.bind(mod .. " + " .. w.key,
            hl.dsp.focus({ workspace = w.id }),
            { description = "Workspace: " .. w.label })
    if not w.no_move then
        hl.bind(mod .. " + SHIFT + " .. w.key,
                hl.dsp.window.move({ workspace = w.id }),
                { description = "Move to " .. w.label })
    end
end

-- The `chat` workspace is declared here rather than in the table because its binds are on the
-- ALT layer (see below) and it has no plain-SUPER key.
local ws_chat = 18

-- name -> id, so the window rules further down can stay readable (`ws.mail`) while addressing
-- workspaces NUMERICALLY. That matters: a window rule's `workspace` is resolved once, at open,
-- and a rule that silently stops matching is this config's most-repeated failure (Thunderbird's
-- class, then its title). Whether `"name:mail"` still resolves to a NUMBERED workspace carrying
-- that `default_name` is undocumented and untested — so the question is avoided rather than
-- answered: every rule below uses the id.
local ws = { chat = ws_chat }
for _, w in ipairs(named_workspaces) do ws[w.ws] = w.id end
-- Move-to-term, off by default (see `no_move` above). Pick ONE:
-- hl.bind(mod .. " + SHIFT + T", hl.dsp.window.move({ workspace = ws.term }))  -- costs float toggle
-- hl.bind(mod .. " + ALT + T",   hl.dsp.window.move({ workspace = ws.term }))  -- keeps both

-- The messengers workspace, on the ALT layer rather than a plain SUPER letter. NOT a free
-- choice: by 2026-08-11 the only plain-SUPER letters left were D and Z (DMS holds F,H,I,J,K,L,
-- M,N,O,P,Q,R,T,U,V,W,X,Y; this config holds B,C,E,F,G,M,Q,S,T,A), and neither carries a
-- mnemonic. SUPER+ALT+M keeps M for "messengers" next to SUPER+M "mail". Revisit if the DMS
-- vim-motion binds (SUPER+H/J/K/L and the SHIFT+CTRL family) are ever unbound — this config
-- already replaced them with `layoutmsg focus` on the arrow keys, so they are dead weight.
--
-- SUPER+ALT+M opens/arranges (the script is idempotent: an app already running is not
-- relaunched, so a second press just rebuilds the grid). SUPER+SHIFT+ALT+M moves a window there.
--
-- ABSOLUTE PATH for the same reason as `hyprbinds` below: ~/.local/bin is on PATH only for
-- interactive shells, and a compositor-spawned process is not one.
hl.bind(mod .. " + ALT + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/hypr-messengers"),
        { description = "Messengers: open + arrange 2x2 on `chat`" })
hl.bind(mod .. " + SHIFT + ALT + M", hl.dsp.window.move({ workspace = ws_chat }),
        { description = "Move window to `chat`" })

-- The `git` workspace — FLEET-WIDE since 2026-08-24 (MK: "I want a git workspace on all my
-- hyprland machines in the fleet"). Promoted from mkDell's local.lua, where it had lived since
-- 2026-08-10.
--
-- THE SPLIT IS DELIBERATE and is why this is not a straight copy. Portable: the workspace, its
-- keys, its window rule, its launcher. Per-machine: the MONITOR it sits on (mkDell pins it to
-- HDMI-A-1, its second screen) and whether gitaw AUTOSTARTS at login. Both stay in local.lua —
-- a `monitor` field here would name a connector that exists on exactly one machine.
--
-- NOT in the `named_workspaces` table above, for the same reason as `chat`: its keys are on the
-- ALT layer, because SUPER+G is `google` and SUPER+SHIFT+G moves a window there.
--
-- Id 19, so it sorts after the skeleton's 11-18 in the DMS bar.
local ws_git = 19
hl.bind(mod .. " + ALT + G", hl.dsp.focus({ workspace = ws_git }),
        { description = "Workspace: git" })
hl.bind(mod .. " + ALT + SHIFT + G", hl.dsp.window.move({ workspace = ws_git }),
        { description = "Move to workspace: git" })

-- `gitaw` is a zsh FUNCTION (dotfiles/oh-my-zsh-custom/gita.zsh), not a binary and not an alias
-- — `ghostty -e gitaw` dies with "command not found", and `sh -c` cannot see it either (the same
-- trap gitaw's own comment records about `watch`). It needs an INTERACTIVE zsh, which is what
-- sources ~/.zshrc and the oh-my-zsh-custom snippets.
--
-- That snippet is linked only under DF_GITA, so on a machine that answered no this opens a
-- terminal that exits immediately. That is the reason this is a BIND rather than an autostart:
-- a dead keybind is a keypress nobody makes, a dead autostart is a flash at every login.
-- Machines that do want it at login exec it from their own local.lua (mkDell does).
--
-- `--class=mk.git` invents a class for the window rule to match, exactly as herdr does; a
-- terminal otherwise carries ghostty's own class and cannot be pinned separately. The `mk.`
-- prefix is required, not stylistic — ghostty demands a valid GTK application id and silently
-- drops a single-word class. See the note beside `local term`.
--
-- `--title` FORCES the title (2026-08-15): without it the window reads `zsh`, because the title
-- comes from the program `-e` runs. It shows wherever a window list does — the DMS bar and
-- overview, and `hypr-switcher`'s TITLE column, where "zsh" identifies nothing.
--
-- ⚠ mkDell's local.lua REPEATS this command string for its login autostart, because this is a
-- local in this chunk and is not visible there. Change one, change both.
local gitaw_cmd = [[ghostty --class=mk.git --title="gita watch" -e zsh -i -c gitaw]]

-- Re-launch after closing (gitaw is `watch`, so q or CTRL+C ends the terminal with it).
hl.bind(mod .. " + ALT + SHIFT + Return", hl.dsp.exec_cmd(gitaw_cmd),
        { description = "Launch gitaw" })

-- Monitor layout (kanshi profiles; define them in the kanshi package's config.d/).
--
-- SUPER+P opens `hypr-monitors`, a popup listing every kanshi profile this machine defines
-- (MK, 2026-08-22: "I'd rather have one shortcut and a popup menu"). It is name-agnostic —
-- it reads the config — whereas the two binds below hardcode profile names that only exist
-- where a machine happens to define them. Prefer the menu; D/S are kept as direct shortcuts.
--
-- ⚠ SUPER+P IS TAKEN BY DMS AND MUST BE UNBOUND — reversed 2026-08-24, and the paragraph this
-- replaces asserted the opposite for two days. It read "SUPER+P IS FREE — no unbind needed …
-- measured 2026-08-22 … contains no P binding at all". Re-measured on 2026-08-24 with the same
-- command on the same machine, dms-shell 1.5.3:
--     strings -a $(command -v dms) | grep -o 'hl\.bind("SUPER + P".\{0,160\}'
--     hl.bind("SUPER + P", hl.dsp.exec_cmd("dms ipc outputs cycleProfile"))
-- So for two days one press did BOTH: opened `hypr-monitors` and cycled DMS's own output
-- profile — the second half invisible unless a profile happened to change the layout.
--
-- Which of the two measurements was wrong is NOT established, and guessing would be the same
-- error again. The two candidates: DMS was upgraded in between (most likely — the technique is
-- sound and was correctly applied both times), or the earlier grep pattern missed it. Either way
-- the lesson is the same, and it is why the unbind below is unconditional: **a bind list read
-- from a third-party binary is a fact with an expiry date.** Re-run the command above after any
-- DMS upgrade; an unbind on a key DMS no longer binds costs nothing, while a missing one fires a
-- second action silently.
--
-- Binds ACCUMULATE rather than replace, which is what makes this fail quietly: nothing errors,
-- nothing is logged, and the extra action is only noticeable when it has a visible effect.
--
-- DMS *does* have its own display-profile system (SettingsData.displayProfiles, reachable as
-- `dms ipc call outputs listProfiles|setProfile`, and two registry plugins front-end it). It is
-- deliberately NOT adopted: those profiles live in settings.json, which this fleet deploys
-- read-only and fleet-wide, so per-machine geometry could not persist there. kanshi stays the
-- source of truth for multi-monitor arrangements.
-- Moved off SUPER+SHIFT+D/S on 2026-08-10 to free the S pair for the named workspaces
-- above; SUPER+ALT+D and SUPER+ALT+S were both unbound (the ALT layer holds the scrolling
-- motions, which use C/F/comma/period/brackets/L only).
hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd("kanshictl switch docked"), { description = "Monitors: docked" })
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("kanshictl switch solo"),   { description = "Monitors: solo" })

-- ABSOLUTE PATH, as with the cheat sheet and the messengers script: ~/.local/bin is on PATH
-- only for INTERACTIVE shells, and a compositor-spawned process is not one — a bare name would
-- fail to exec, the terminal would close instantly, and the bind would look dead with no error.
local monitors = os.getenv("HOME") .. "/.local/bin/hypr-monitors"
hl.unbind(mod .. " + P")
hl.bind(mod .. " + P",
        hl.dsp.exec_cmd("ghostty --class=mk.monitors -e " .. monitors .. " --fzf"),
        { description = "Monitors: pick a layout" })

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
-- nothing has added it. A bare name therefore fails to exec, the terminal exits instantly, and
-- the keybind looks dead with no error anywhere. herdr and ghostty are unaffected because they
-- live in /usr/bin. Built from $HOME so no home directory is hardcoded, same as the xkb path.
--
-- The window is sized by the window rules below, NOT here. An earlier version passed
-- `-o window.dimensions.columns=… lines=…` to alacritty as a workaround while rule-based sizing
-- appeared broken; that turned out to be a rule-ordering bug (see the rules), so the workaround
-- was removed rather than left as a second mechanism fighting the first. Ghostty's equivalent is
-- `--window-width=`/`--window-height=`, also in CELLS (Config.zig:2159 — "grid dimensions",
-- minimum 10x4) — reach for it if the sheet should ever track the font size instead of the
-- monitor. Note its documented GTK bug: window decorations are not accounted for, so the grid
-- will not match exactly unless decorations are off.
local cheatsheet = os.getenv("HOME") .. "/.local/bin/hyprbinds"
hl.unbind(mod .. " + SHIFT + Slash")
hl.bind(mod .. " + SHIFT + Slash",
        hl.dsp.exec_cmd("ghostty --class=mk.hyprbinds -e " .. cheatsheet .. " --fzf"),
        { description = "Keybind cheat sheet" })

-- THE OVERVIEW IS ON SUPER+TAB AND *ONLY* SUPER+TAB (MK, 2026-08-15). DMS binds the same
-- `dms ipc call hypr toggleOverview` to BOTH SUPER+Tab and SUPER+O (`dms/binds.lua:13-14`);
-- SUPER+O is unbound here so there is one way in, on the key muscle memory expects.
--
-- This REVERSES the 2026-08-14 decision recorded below, and the reason it reversed is the whole
-- point: the overview was unusable then, and is not now. Left as history because the mechanism
-- is worth keeping — and because "we unbound this key" is exactly the kind of note that gets
-- re-applied by someone tidying up.
hl.unbind(mod .. " + O")

-- SUPER+Tab REMOVED, not replaced (MK, 2026-08-14) — SUPERSEDED, see above; the unbind is gone
-- and DMS's own SUPER+Tab binding stands. DMS binds it to its workspace overview
-- (`~/.config/hypr/dms/binds.lua:13`, `dms ipc call hypr toggleOverview`), and that overview
-- CANNOT SHOW THIS SETUP'S WORKSPACES: `OverviewWidget.qml:42-75` builds its cell grid as
-- positive integers only (`for i = 1 .. maxExisting`, padded to rows x columns) and gates
-- `workspaceExists`/`hasWindows` on `workspaceValue > 0`, while Hyprland gives NAMED
-- workspaces negative ids — DMS says so itself in `WorkspaceSwitcher.qml:283` ("from -1337
-- down"). Every workspace here is named, so the overview could only ever render a grid of
-- empty numbered placeholders. Not misconfiguration; a DMS limitation.
--
-- That limitation is FIXED — the workspaces are numbered now (see the `named_workspaces`
-- section), the overview renders real cells with live previews, and MK confirmed it on screen
-- 2026-08-15. Hence the reversal at the top of this block.
--
-- hyprshell WAS TRIED AND REVERTED (2026-08-14/15) — Alt+Tab is now `hypr-switcher`, below.
-- Read this before installing hyprshell again:
-- before installing it again: `hyprshell-bin` ships NO Hyprland plugin (`pacman -Ql` has no
-- .so), so it falls back to registering its binds over the socket — and in that mode it
-- BREAKS OTHER MODIFIER HANDLING. Measured here: with the daemon running, `SUPER+left/right`
-- and every other focus bind stopped working while workspace switching kept working, and
-- `pkill hyprshell` restored them instantly. Upstream is the same report
-- (github.com/H3rmt/hyprshell#333, "mod key inputs are sometimes not recognized during normal
-- usage" — same movefocus binds, same "stopping hyprshell fixes it"), and its reporter saw it
-- with modifiers hyprshell was not configured for, so changing `switch.modifier` is not a
-- workaround. The maintainer's own explanation: the plugin exists precisely to "replicate
-- hyprland internal keyhandling", and without it the socket-registered binds interfere.
--
-- So if this is revisited: build the AUR `hyprshell` (source) package rather than `-bin`, get
-- the plugin loaded and version-matched via hyprpm, and re-test the focus binds FIRST.
--

-- ALT+TAB — MRU window switcher (2026-08-15).
--
-- `hypr-switcher` reads Hyprland's OWN focus stack: `hyprctl -j clients` carries
-- `focusHistoryID` per window (0 = focused, 1 = previously focused, …), so the order is the
-- compositor's and nothing here keeps state that could drift. It lists WINDOWS, not
-- workspaces — DMS's overview covers workspaces and this deliberately does not duplicate it.
--
-- A picker, not a held-modifier switcher: press, choose (ENTER on open = flip to the window
-- you were just in, because the focused window is rotated to the END of the list), ESC to
-- cancel. The held-Alt feel needs a key grab, which is exactly what broke every focus bind
-- when hyprshell tried it — see the block above. This trades that feel for a script that
-- cannot interfere with anything.
--
-- ABSOLUTE PATH, and `--class=mk.switcher` for the float rule, for the same two reasons as the
-- cheat sheet above: ~/.local/bin is on PATH only for interactive shells, and ghostty silently
-- drops a class that is not a valid GTK application id.
local switcher = os.getenv("HOME") .. "/.local/bin/hypr-switcher"
hl.bind("ALT + TAB",
        hl.dsp.exec_cmd("ghostty --class=mk.switcher -e " .. switcher .. " --fzf"),
        { description = "Switch window (MRU)" })

-- Screenshots on CTRL+SHIFT+<n>: Apple keyboards have no Print key, which is what DMS binds.
-- Routed through `dms screenshot` so both paths behave identically.
hl.bind("CTRL + SHIFT + 1", hl.dsp.exec_cmd("dms screenshot"),        { description = "Screenshot: region" })
hl.bind("CTRL + SHIFT + 2", hl.dsp.exec_cmd("dms screenshot full"),   { description = "Screenshot: screen" })
hl.bind("CTRL + SHIFT + 3", hl.dsp.exec_cmd("dms screenshot window"), { description = "Screenshot: window" })

-- SUPER+F: WIDEN THE COLUMN, DON'T FULLSCREEN (2026-08-11). This is niri's `maximize-column`,
-- and it is bound here because Hyprland's fullscreen — even the layout-managed kind the
-- scrolling layout implements — puts the window into a state that OTHER binds then refuse to
-- act on. Both halves were measured in the 0.56.2 source:
--
--   * SUPER+SHIFT+<dir> (move window) is refused outright for any fullscreen window
--     (`ConfigActions.cpp:482`, "Can't move fullscreen window"). No config option exists.
--   * SUPER+<dir> (move focus) finds no candidate, because maximizing marks every other
--     window `!allowedOverFullscreen` and the direction query then skips them all unless
--     `binds:movefocus_cycles_fullscreen` is on (`WindowQuery.cpp:111-120`, default false).
--     NOT set here — the point of this bind is to not enter that state at all.
--
-- `colresize +conf` steps up through scrolling.explicit_column_widths and wraps at the end.
-- That list is deliberately just "0.5, 1.0" (see above), so this is a straight toggle: half
-- width <-> full width, one key, no intermediate steps. At 1.0 it looks exactly like the old
-- maximize, but the window stays an ordinary column: focus and move keep working. Real
-- fullscreen is still SUPER+SHIFT+F (DMS's bind, for video).
--
-- The unbind is mandatory, not tidiness — see the accumulation note above: without it DMS's
-- maximize fires on the same press and puts you straight back into the state this avoids.
hl.unbind(mod .. " + F")
hl.bind(mod .. " + F", hl.dsp.layout("colresize +conf"), { description = "Column width: cycle presets" })

-- DIRECTIONAL FOCUS GOES THROUGH THE LAYOUT, NOT THROUGH movefocus (2026-08-11).
-- DMS binds SUPER+<dir> and SUPER+hjkl to `hl.dsp.focus({direction=...})` = movefocus, which
-- finds its target GEOMETRICALLY: it compares the focused window's rectangle against every
-- other window's and requires the edges to be within 2 px (`WindowQuery.cpp:70-95`). On a
-- scrolling tape that is the wrong question to ask, and it fails in a way that looks random:
-- measured on `browser` with three columns (0.5 / 1.0 / 0.5), focus moved left and right
-- fine until it reached the RIGHTMOST column, from where SUPER+left did nothing at all.
--   * `hl.dsp.focus({direction="l"})`  -> no effect
--   * `hl.dsp.layout("focus l")`       -> works
-- both dispatched by hand in that exact state. The layout message walks the column list by
-- index (`ScrollingAlgorithm.cpp:1451`) and never looks at a rectangle, so it cannot be
-- defeated by a few pixels of gap. This is also literally niri's focus-column-left/right.
--
-- l/r move between columns and u/d within a column, automatically swapped when the scroll
-- direction is vertical (`:1459-1471`) — so this stays correct if scrolling.direction changes.
--
-- TWO BEHAVIOUR CHANGES to know about:
--   * `scrolling:wrap_focus` defaults to TRUE, so focus wrapped around at the ends of the
--     tape instead of stopping. It is set to false in the scrolling block above.
--   * movefocus's cross-monitor fallback is gone from these keys. SUPER+CTRL+<dir> (DMS)
--     still moves focus between monitors, which is the explicit key for it anyway.
for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d",
                        H = "l", L = "r", K = "u", J = "d" }) do
    hl.unbind(mod .. " + " .. key)
    hl.bind(mod .. " + " .. key, hl.dsp.layout("focus " .. dir),
            { description = "Focus " .. dir .. " (scrolling layout)" })
end

-- Scrolling-layout motions, on SUPER+ALT+* because the natural keys are all taken by DMS
-- (SUPER+comma = settings, SUPER+bracket* = preselect, SUPER+CTRL+F = maximize).
-- SUPER+ALT+bracket* run the same +conf/-conf messages as SUPER+F. With a two-entry preset
-- list all three keys now do the same toggle; they are kept because the list is the only thing
-- that makes them equivalent, and adding widths back makes them distinct again.
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
-- (`WorkspaceSwitcher.qml:257`, hyprlandWorkspaceOrder) — TRUE ONLY FOR NAMED (negative-id)
-- WORKSPACES, which these no longer are. Since 2026-08-15 each is a NUMBERED workspace carrying
-- `default_name`, so the same sort function takes the `a.id - b.id` branch and BAR ORDER IS THE
-- ID ORDER declared in `named_workspaces` above:
--   mail · browser · herdr · code · google · social · term · chat
-- The 2026-08-10 note that `herdr` left of `code` "no config change can deliver" is dead; that
-- was a property of named workspaces, not of the shell.
--
-- These rules are generated from the same table as the binds, so a name/id can only be changed
-- in one place. `default_name` is what keeps the bar showing "mail" rather than "11".
for _, w in ipairs(named_workspaces) do
    hl.workspace_rule({ workspace = tostring(w.id), default_name = w.ws, persistent = true })
end
-- No per-workspace `layout` here any more: general.layout is "scrolling" for everything as of
-- 2026-08-11. Add `layout = "dwindle"` to a rule to carve an exception back out.

-- chat: the four messengers (WhatsApp/ZapZap, Signal, Telegram, Threema) as a 2x2 grid.
-- Persistent like the rest, and deliberately NOT autostarted — four Electron/WebEngine apps at
-- login is a slow login. SUPER+ALT+M opens and arranges them on demand; see the bind below.
-- The grid itself cannot be expressed as config (the scrolling layout gives one column per
-- window); `hypr-messengers` builds it. Id 18, so it sorts LAST in the bar (it used to sort
-- first, back when the order was alphabetical).
hl.workspace_rule({ workspace = tostring(ws_chat), default_name = "chat", persistent = true })

-- git: the gitaw watch terminal (id 19), fleet-wide since 2026-08-24 — see the bind section.
-- NO `monitor` field here: that is the per-machine half and lives in
-- workstation-private/<host>/hypr/local.lua. Without such a rule a persistent workspace lands
-- wherever Hyprland picks, and it re-picks on every `hyprctl reload` and every output change.
hl.workspace_rule({ workspace = tostring(ws_git), default_name = "git", persistent = true })

-- herdr is a terminal app with no class of its own, so it is not pinned by an app rule; it is
-- launched at login with `--class mk.herdr`, which invents a class the window rule below can
-- match. Its workspace rule comes from the `named_workspaces` loop above (id 13).
--
-- term: deliberately bare — a scratch terminal workspace, nothing pinned, nothing autostarted
-- (id 17). `code` likewise: visual-studio-code-bin IS installed and its window rule works, it
-- is simply not wanted at login. Add either to the hyprland.start handler if that changes.

-- History of the layout choice, because it moved twice in two days:
--   * numbered workspace 2 carried `layout = "scrolling"` as the original "try it" experiment;
--   * 2026-08-10 that was dropped and scrolling became a deliberate opt-in on `browser`/`code`;
--   * 2026-08-11 it went global (general.layout) instead.
-- The per-workspace layout is still Hyprland's distinguishing feature over niri and is one line
-- away if it is ever wanted again — but a bind that works on two workspaces and silently does
-- nothing on the other five is worse than either layout applied consistently.

--------------------------------------------------------------------------------
-- Window rules
--------------------------------------------------------------------------------
-- NOTE the limitation, it is the same one niri has: `workspace` is a STATIC effect, applied
-- once at open and matched against initialTitle/initialClass. It cannot re-home a window
-- whose title settles later — which is exactly the restored-Firefox case
-- (desktop/niri-window-placement.md). The Hyprland answer is an event handler; see below.
hl.window_rule({ match = { class = "firefox", title = "^Picture-in-Picture$" }, float = true })

-- Windows XP Solitaire under Wine. Class measured off a live window (2026-08-19, mkDell):
-- `sol.exe`, and initialClass matches it, so a class-matched rule fires reliably at open.
-- Floating because the game draws a fixed-size card table; tiled onto a scrolling column it
-- just pads itself with green felt.
hl.window_rule({ match = { class = "sol.exe" }, float = true })

-- NO Thunderbird float rule here, deliberately — a title-matched one CANNOT work for that app.
-- `{ class = "org.mozilla.Thunderbird", title = "Alias" }, float = true` stood here from the
-- original skeleton until 2026-08-11 and had never once fired. See the `window.title` handler
-- further down, which is the working replacement.

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
hl.window_rule({ match = { class = "org.mozilla.Thunderbird" }, workspace = ws.mail })
hl.window_rule({ match = { class = "floorp" },                  workspace = ws.google })
hl.window_rule({ match = { class = "brave-browser" },           workspace = ws.social })
hl.window_rule({ match = { class = "code" },                    workspace = ws.code })

-- The four messengers -> name:chat. These pin the apps however they are started (menu,
-- spotlight, terminal), so SUPER+ALT+M's script only has to build the grid, not the placement.
--
-- ⚠ THE SAME FOUR CLASSES ARE HARDCODED IN `hypr-messengers` (dotfiles hypr package). Change
-- one and change the other, or the script will wait 15s for a window it can never find while
-- the rule below still works — a half-broken state that looks like a slow app.
--
-- ⚠ UNVERIFIED AT THE TIME OF WRITING (2026-08-11): unlike every rule above, these four were
-- NOT read off live windows — ZapZap and Threema were not installed yet. `signal` and
-- `org.telegram.desktop` are also predictions. Confirm all four with `hypr-messengers probe`
-- and correct them here; a wrong class fails silently (the app opens, nothing moves).
hl.window_rule({ match = { class = "com.rtosta.zapzap" },          workspace = ws.chat })
hl.window_rule({ match = { class = "signal" },                     workspace = ws.chat })
hl.window_rule({ match = { class = "org.telegram.desktop" },       workspace = ws.chat })
hl.window_rule({ match = { class = "ch.threema.threema-desktop" }, workspace = ws.chat })

-- The herdr terminal, matched on the custom class set by `ghostty --class=mk.herdr` in the login
-- autostart at the bottom of this file. Plain ghostty windows are class
-- "com.mitchellh.ghostty" and are deliberately NOT matched here — they must stay openable
-- anywhere, the same reasoning as firefox below.
--
-- `mk.herdr`, not `herdr`: ghostty requires a valid GTK application id (two period-separated
-- elements minimum). See the note beside `local term` at the top — an invalid class is accepted
-- by ghostty's parser and dropped by GTK, so this rule would silently never match.
hl.window_rule({ match = { class = "mk.herdr" }, workspace = ws.herdr })

-- The gitaw terminal (id 19), same invented-class trick as herdr directly above and for the
-- same reason. Launched by SUPER+ALT+SHIFT+Return, or at login on machines whose local.lua
-- autostarts it.
hl.window_rule({ match = { class = "mk.git" }, workspace = ws_git })

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
-- width comfortably above ~900px. If proportional sizing is ever wanted, ghostty's
-- `--window-width=`/`--window-height=` (cells) is the working alternative — not a percentage
-- here. That is still not proportional to the monitor, but it does track the font size.
hl.window_rule({ match = { class = "mk.hyprbinds" }, float = true })
hl.window_rule({ match = { class = "mk.hyprbinds" }, size = { 900, 1000 } })

-- The monitor-layout picker, same shape as the cheat sheet: floating, on the current
-- workspace. Small — it lists a handful of profiles, not ~150 binds.
hl.window_rule({ match = { class = "mk.monitors" }, float = true })
hl.window_rule({ match = { class = "mk.monitors" }, size = { 900, 420 } })

-- The MRU switcher, same shape as the cheat sheet: floating, on the CURRENT workspace (no
-- `workspace` field — it must appear where you are, and it is where you leave from). Smaller,
-- because it lists windows rather than ~150 binds. Two rules rather than one for the same
-- ordering reason documented above.
hl.window_rule({ match = { class = "mk.switcher" }, float = true })
hl.window_rule({ match = { class = "mk.switcher" }, size = { 900, 600 } })

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

-- Float the send_as extension's "create identity?" dialog, WITHOUT floating the compose window.
--
-- This is the worked example of the static-rule limitation noted at the top of the rules block,
-- and it is worth reading before writing any title-matched rule for a Firefox-family app.
-- Measured 2026-08-11, `hyprctl -j clients` with the dialog open:
--
--   title                                              initialTitle          floating
--   All (last 100 days) - … - Mozilla Thunderbird      Mozilla Thunderbird   false
--   Write: Re: … - Thunderbird                         Write: (no subject)   false
--   Send As Alias - Create Identity? - Mozilla Th…     Mozilla Thunderbird   false
--
-- The dialog is `messenger.windows.create({type = 'popup'})` (thunderbird_send_as
-- background.js), so its title comes from the popup's <title> and is set only AFTER the window
-- maps. At map time it is indistinguishable from the main window — BOTH are "Mozilla
-- Thunderbird" — so no `float` rule, however well written, can select it. The compose window is
-- the one Thunderbird window with a distinctive initialTitle, which is the wrong way round.
--
-- Note the failure mode: the old rule matched `Alias`, which really does appear in the settled
-- title, so it read as correct and produced no error anywhere. The `floating: false` column above
-- is the whole disproof.
--
-- The dispatcher call form was established by probing a LIVE window (`hyprctl dispatch` evaluates
-- Lua, so a running dialog can be floated by hand). Two things that cost a round each:
--   * `action = "enable"`, not the default. Called without it the dispatcher TOGGLES, so a probe
--     that ran both forms in sequence floated the window and immediately unfloated it — and both
--     calls returned `ok`. "ok" is not evidence; the `floating` field afterwards is.
--   * A raw dispatcher string (`setfloating address:0x…`) is NOT accepted — `hyprctl dispatch`
--     parses its argument as Lua and dies on the space.
--
-- FLOATING IT IS NOT ENOUGH — the dialog also arrives MAXIMIZED, and the second dispatch is what
-- makes this actually useful. Measured with the window already floating:
--
--   floating   fullscreen   fullscreenClient   size
--   true       1            1                  1596x952     <- full logical screen (2880x1800 @1.8
--                                                              is 1600x1000) minus gaps and bar
--
-- `fullscreen = 1` is MAXIMIZED, not true fullscreen (0 none / 1 maximized / 2 fullscreen), and
-- `fullscreenClient = 1` says THUNDERBIRD is asserting it, not Hyprland. That distinction decides
-- the fix: `hl.dsp.window.fullscreen({ action = "unset" })` returns `ok` and changes nothing,
-- because it clears only the internal state while the client's request keeps the geometry. Only
-- `fullscreen_state`, which addresses both, works — clearing both drops the window to 556x404,
-- i.e. the 550x300 the extension asks for in `messenger.windows.create` plus chrome.
--
-- Both dispatchers are self-documenting through their ERRORS, which is where every field name and
-- enum below came from — `strings -a $(command -v Hyprland) | grep fullscreen_state` yields
-- `expected a table { internal, client, action?, window? }` and
-- `invalid action "{}" (expected toggle/set/unset)`. Note `float` takes "enable" while this one
-- takes "set": the vocabularies are per-dispatcher, so do not carry one over to the other.
--
-- `window = "address:…"` IS honoured, verified rather than assumed: floating the COMPOSE window by
-- address while a third window (the terminal) held focus moved the right one. Worth having checked
-- — every earlier probe had targeted the focused window, so "the field works" and "dispatchers act
-- on the active window" fit the evidence equally until that test.
hl.on("window.title", function(w)
    if w == nil or w.class ~= "org.mozilla.Thunderbird" then return end
    if w.title == nil or not w.title:find("Send As Alias", 1, true) then return end
    -- window.title fires on every title change; bail once the window is in the target state.
    -- Both conditions, not just `floating` — the first pass leaves it floating AND maximized, so
    -- guarding on `floating` alone would return early and never clear the maximize.
    if w.floating and (w.fullscreen or 0) == 0 then return end
    local sel = "address:" .. w.address
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel }))
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = sel }))
end)

-- Decline maximize requests from Firefox. This is the second half of the Bitwarden popup fix
-- below, and it addresses a DIFFERENT symptom than the float does — worth keeping straight.
--
-- MEASURED 2026-08-19 by polling `hyprctl -j clients` through a popup's whole lifetime. The
-- window floats correctly and then Firefox asserts maximize ON the floating window before
-- dropping it again, all on ONE address, never leaving the floating state:
--
--   floating=true  fs=0 fsClient=0  485x576   at 956,234   <- our float lands, correct size
--   floating=true  fs=1 fsClient=1  1596x952  at 2,46      <- Firefox asks to be maximized
--   floating=true  fs=1 fsClient=1  1596x956  at 2,42
--   floating=true  fs=0 fsClient=0  485x576   at 956,234   <- releases it by itself
--
-- Read from the screen that looks like "it becomes a full-width tiled window and then floats
-- again", which is why this was nearly diagnosed as the scrolling layout re-adopting the window
-- or as a second float dispatch. It is neither: `floating` is true on every sample and the address
-- never changes. 1596x952 is the full logical screen, the same figure measured for the Thunderbird
-- dialog further down.
--
-- The `window.title` handler below CANNOT fix this — the maximize arrives after the last title
-- change, so the handler never fires again. `suppress_event` is the answer because it is a STATIC
-- rule that needs no discriminator: it declines the request rather than undoing it afterwards.
--
-- SCOPED TO FIREFOX DELIBERATELY. Hyprland's shipped example config (/usr/share/hypr/hyprland.lua)
-- uses `match = { class = ".*" }` for this with the comment "Ignore maximize requests from all
-- apps. You'll probably like this." — widening it is likely right and would probably also retire
-- the `fullscreen_state` dispatch in the Thunderbird handler below, which exists to undo exactly
-- this. Left narrow because that dispatch is measured working today and this session's ask was
-- about Bitwarden; widen it as its own deliberate change, with the Thunderbird dialog re-measured.
hl.window_rule({ match = { class = "firefox" }, suppress_event = "maximize" })

-- Float the Bitwarden extension popup (the window a passkey login pops out into).
--
-- SECOND worked example of the static-rule limitation, and the reason it is a handler rather than
-- a `hl.window_rule` is measured, not inherited from the Thunderbird case above.
-- `hyprctl -j clients` with the popup open (2026-08-19, mkMac2014, six firefox windows):
--
--   title                                                       initialTitle       floating
--   Bookmarks+ — Mozilla Firefox                                Mozilla Firefox    false
--   Dokumente - Paperless-ngx — Mozilla Firefox                 Mozilla Firefox    false
--   Anmeldung | Bundesagentur für Arbeit — Mozilla Firefox      Mozilla Firefox    false
--   Extension: (Bitwarden Password Manager) - Bitwarden — Moz…  Mozilla Firefox    false
--
-- Every firefox window maps as `Mozilla Firefox` and acquires its real title afterwards, so at
-- match time the popup is indistinguishable from an ordinary browser window — a `title` rule can
-- only ever match all of them or none. `xdgTag` and `xdgDescription`, the other fields a rule
-- could plausibly key on, are the empty string on all six, so there is no discriminator at open.
--
-- ONE DISPATCH, NOT TWO — the difference from Thunderbird above, and it is deliberate. That dialog
-- arrives maximized (`fullscreen = 1`, `fullscreenClient = 1`) and needs the `fullscreen_state`
-- call to become useful. This popup does not: measured `fullscreen = 0`, `fullscreenClient = 0`,
-- 784x944, i.e. an ordinary tiled window in the scrolling tape. Adding the second dispatch here
-- would be carrying over an unmeasured fix for a state this window is not in.
--
-- UNMEASURED, deliberately left alone: what size the window takes once floated. Hyprland may keep
-- the 784x944 it currently has or fall back to its own float default. If it comes up wrong, the fix
-- is a `hl.dsp.window.resize` in the same handler — NOT a `size` window rule, which cannot select
-- this window for the reason above.
--
-- Firefox only. Floorp is a Firefox fork and very likely produces the same `Extension: (…)` title
-- under class `floorp`, and Brave almost certainly does not — but neither was measured, and a
-- guessed class fails silently here (the popup opens, nothing floats). Add them by reading a live
-- window with the popup open, not from this comment.
hl.on("window.title", function(w)
    if w == nil or w.class ~= "firefox" then return end
    if w.title == nil or not w.title:find("Extension: (Bitwarden", 1, true) then return end
    -- window.title fires on every title change in every firefox window, so bail once this one is
    -- already in the target state. Unlike the Thunderbird handler, `floating` alone is the whole
    -- condition — there is no maximize to clear.
    --
    -- MEASURED 2026-08-19 (instrumented with prints, see the debugging note near the top): one
    -- popup fires this handler TWICE, because the title arrives in two steps —
    --
    --   Extension: (Bitwarden Password Manager) - — Mozilla Firefox            floating=false
    --   Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox  floating=true
    --
    -- so the guard does its job: dispatch on the first, early-return on the second. `floating` is
    -- fresh in the event payload, not stale. Note the first title is INCOMPLETE — the app name has
    -- not filled in yet — which is why the match literal stops at `Extension: (Bitwarden`. A match
    -- on `- Bitwarden —` would miss the first event and float a frame later than necessary.
    if w.floating then return end
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = "address:" .. w.address }))
end)

-- Post-restore Firefox placement, the in-config replacement for
-- ~/.local/bin/place-firefox-windows.sh. Disabled until the Winger window-name prefixes are
-- confirmed to show up in the Wayland title (open item in desktop/niri-window-placement.md).
--
-- hl.on("window.title", function(w)
--     if w == nil or w.title == nil then return end
--     if w.title:match("^mail") then
--         hl.dispatch(hl.dsp.window.move({ workspace = ws.mail }))
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

    -- -> name:herdr via the `mk.herdr` class rule. `--class` is what makes this pinnable at all:
    -- a bare `ghostty` is class "com.mitchellh.ghostty" like every other ghostty window, so a
    -- rule on that would drag EVERY terminal to the herdr workspace. Keep this command identical
    -- to the one in the workspace's on_created_empty, or the two paths produce differently-
    -- classed windows.
    --
    -- The `mk.` prefix is not decoration: ghostty rejects a single-word class as an invalid GTK
    -- application id, silently, falling back to the default. See the note beside `local term`.
    hl.exec_cmd("ghostty --class=mk.herdr -e herdr")
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
