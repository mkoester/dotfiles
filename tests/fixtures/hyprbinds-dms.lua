-- Fixture: a miniature stand-in for ~/.config/hypr/dms/binds.lua.
-- Deliberately covers one of each shape the real file uses, because those are what the parser
-- can get wrong: an undescribed exec_cmd, a described bind, a key we later take back
-- (SUPER + M), an arrow/letter twin pair, a digit run, and the three noise classes the curated
-- view drops (XF86, mouse:, code:).

-- === Application Launchers ===
hl.bind("SUPER + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))

-- === Window Management ===
hl.bind("SUPER + Q", hl.dsp.window.close())

-- === Focus Navigation ===
hl.bind("SUPER + left", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))

-- === Audio Controls ===
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true })

-- === Numbered Workspaces ===
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }))

-- === Move/resize windows with mainMod + LMB/RMB and dragging ===
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + code:20", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { description = "Expand window left" })
