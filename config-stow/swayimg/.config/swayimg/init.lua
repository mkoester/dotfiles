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

-- Keypad + zooms in. The defaults bind zoom-in to "equal" only (the unshifted +/= key), so
-- KP_Add reported "unhandled" while keypad - already worked. Same step size as the defaults.
swayimg.viewer.on_key("kp_add", function()
  swayimg.viewer.scale = swayimg.viewer.scale + swayimg.viewer.scale / 10
end)
-- Mouse wheel zooms (around the pointer); Ctrl+wheel pans. The default is the other way round.
-- on_scroll REPLACES the built-in handler (src/defaults.cpp), so both halves are restated here
-- with the default's own factors (scale step /10, pan step 50). Horizontal scrolling (touchpad,
-- tilt wheel) keeps panning without a modifier. Setting `scale` zooms around the mouse pointer
-- (luaengine.cpp). `mods` is "" without a modifier, else e.g. "Ctrl" or "Ctrl+Shift".
swayimg.viewer.on_scroll(function(mods, dh, dv)
  if mods == "" then
    if dv ~= 0 then
      swayimg.viewer.scale = swayimg.viewer.scale - swayimg.viewer.scale * dv / 10
    end
    dv = 0
  end
  if dh ~= 0 or dv ~= 0 then
    -- read after any zoom above, which moves the image to keep the pointer spot fixed
    local pos = swayimg.viewer.get_position()
    swayimg.viewer.set_abs_position(math.floor(pos.x + dh * 50), math.floor(pos.y + dv * 50))
  end
end)

swayimg.gallery.on_key("kp_add", function()
  swayimg.gallery.thumb_size = swayimg.gallery.thumb_size + 10
end)
