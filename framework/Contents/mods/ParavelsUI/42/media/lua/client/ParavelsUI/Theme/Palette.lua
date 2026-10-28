--[[
    Paravel's UI - colour palette

    Colours for telling categories apart, which every theme decides on its
    own: Palette.COUNT numbered colours (theme tokens paletteColor1 ...),
    each distinct from the others. An interface asks for "category colour n"
    and never for a colour: which colour each number is, is the theme's.
    A row of greys from white to black never changes with the theme, so
    something neutral stays neutral.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/Theme"

local Palette = PUI.Palette or {}
PUI.Palette = Palette

Palette.COUNT = 12
Palette.GREYS = 12

-- Each category colour's token id, by number.
local TOKEN_IDS = {}
for n = 1, Palette.COUNT do TOKEN_IDS[n] = "paletteColor" .. n end

-- The greys, by step, made once: they never change.
local GREY_COLORS = {}
for step = 0, Palette.GREYS - 1 do
    local v = 1 - step / (Palette.GREYS - 1)
    GREY_COLORS[step] = PUI.Color.rgb(v, v, v)
end

-- Category colour n, 1 .. Palette.COUNT.
function Palette.color(n)
    return PUI.Theme.current[TOKEN_IDS[n]]
end

-- Grey `step`, 0 (white) .. Palette.GREYS - 1 (black). The same table on
-- every call: never change it.
function Palette.grey(step)
    return GREY_COLORS[step]
end
