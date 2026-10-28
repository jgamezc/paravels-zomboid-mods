--[[
    Paravel's UI - window frames

    The theme's look for a window as a whole: its background, rounded by
    the theme's window radius, and its outline. Anything inside (title bar,
    tabs, contents) is the window's own. To restyle a game window, draw
    these where the game drew its background and border, through
    DrawOverrides while the game's prerender and render run.

    Both take the height to draw, since a window collapsed to its title bar
    is drawn that tall and its corners must still fit, and optionally the y
    of its top (0 when nil), for a frame that leaves room above it (a
    scrolling menu's arrows).
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Shapes/Line"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local Line = PUI.Line
local Theme = PUI.Theme

local WindowFrame = PUI.WindowFrame or {}
PUI.WindowFrame = WindowFrame

-- The corner radius of `element` drawn `height` tall.
function WindowFrame.radius(element, height)
    return Draw.fitRadius(Theme.radius(), element:getWidth(), height)
end

function WindowFrame.drawBackground(element, height, top)
    Draw.roundedRect(element, 0, top or 0, element:getWidth(), height, WindowFrame.radius(element, height),
        Theme.backgroundColor(), Theme.backgroundAlpha())
end

function WindowFrame.drawOutline(element, height, top)
    Line.outline(element, 0, top or 0, element:getWidth(), height, WindowFrame.radius(element, height))
end
