--[[
    Paravel's UI - draw overrides

    The way to restyle a game element without copying its drawing code: while
    the game's own prerender or render runs, some of the element's draw
    methods (drawRect, drawText, drawTextureScaled...) are swapped for ones
    that recognise what the game is drawing (by colour, place or texture) and
    draw the theme's version instead, or nothing. Anything not recognised is
    passed on to the ISUIElement method, as the game would have drawn it.

    An override has the same signature as the method it replaces.
]]

require "ParavelsUI/Core/PUI"

local DrawOverrides = PUI.DrawOverrides or {}
PUI.DrawOverrides = DrawOverrides

-- Runs fn(element, ...) with element's methods replaced by `overrides`
-- ({ methodName = function }), and puts back what was there afterwards, even
-- when fn fails. Runs nest: an inner one restores the outer one's overrides.
function DrawOverrides.run(element, overrides, fn, ...)
    return PUI.withFields(element, overrides, fn, element, ...)
end

-- Draws nothing: for parts of the game's drawing the theme leaves out.
function DrawOverrides.skip() end
