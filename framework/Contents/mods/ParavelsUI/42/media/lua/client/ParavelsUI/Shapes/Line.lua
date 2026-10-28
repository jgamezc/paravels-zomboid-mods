--[[
    Paravel's UI - lines and outlines

    Dividers, separators and the outlines of boxes, in the theme's line
    colour, opacity and thickness.
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local Theme = PUI.Theme

local Line = PUI.Line or {}
PUI.Line = Line

-- A line or divider: a w x h box in the theme's line colour and opacity.
function Line.draw(element, x, y, w, h)
    local alpha = Theme.borderAlpha()
    if alpha > 0 and w > 0 and h > 0 then Draw.rect(element, x, y, w, h, Theme.borderColor(), alpha) end
end

-- The outline of a w x h box at x, y. `corners` says which corners are
-- rounded and `sides` which sides are drawn (all when nil).
function Line.outline(element, x, y, w, h, radius, corners, sides)
    local alpha = Theme.borderAlpha()
    local thickness = math.floor(math.min(Theme.borderWidth(), w / 2, h / 2))
    if thickness <= 0 or alpha <= 0 then return end
    Draw.outline(element, x, y, w, h, radius, corners, sides, Theme.borderColor(), alpha, thickness)
end
