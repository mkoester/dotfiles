-- swayimg config — only the deltas from the built-in defaults.
-- The full default config, with every key binding, is /usr/share/swayimg/example.lua;
-- the API reference is /usr/share/swayimg/swayimg.lua (both shipped by the package).
--
-- Already the default, so not repeated here: swayimg.viewer.default_scale = "optimal"
-- (100% or less to fit the window — large images open zoomed out, small ones are not blown up).

-- Opening one file from Nautilus loads only that file unless this is on (default false):
-- with it, its siblings in the same directory join the list, so next/prev has something to walk.
swayimg.imagelist.adjacent = true

-- Left/Right flip images, like feh and imv. The defaults use them to pan the image
-- (next/prev is on PgDn/PgUp, which still work). Bindings are a map, so these replace the
-- defaults rather than adding a second action. Up/Down keep panning; mouse drag pans too.
swayimg.viewer.on_key("left", function()
  swayimg.viewer.open("prev")
end)
swayimg.viewer.on_key("right", function()
  swayimg.viewer.open("next")
end)
