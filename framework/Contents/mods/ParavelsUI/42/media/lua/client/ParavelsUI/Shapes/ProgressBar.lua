--[[
    Paravel's UI - progress bars

    A horizontal bar of how far along or how full something is (a
    container's load, an item's wear, a task's progress): a faint track its
    whole length and the filled part over it, both with ends in the theme's
    bar shape. The filled part keeps the shape at its start and is cut
    straight where it stops, until it reaches the end. The colour is the
    caller's, from the theme's meanings (Theme.fullnessColor,
    Theme.successColor...).
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local Theme = PUI.Theme

local ProgressBar = PUI.ProgressBar or {}
PUI.ProgressBar = ProgressBar

-- How tall a bar is drawn by default: the theme's bar thickness (0 hides bars).
function ProgressBar.height()
    return Theme.barThickness()
end

-- A bar `width` long at x, y, filled to `fraction` (0..1; past 1 is full;
-- anything above 0 shows at least a pixel). Optional: `thickness` (the
-- theme's when nil), `trackColor` (the bar's colour when nil) and `alpha`,
-- which fades the whole bar (1 when nil).
function ProgressBar.draw(element, x, y, width, fraction, color, thickness, trackColor, alpha)
    thickness, alpha = thickness or ProgressBar.height(), alpha or 1
    if thickness <= 0 or width <= 0 then return end
    local radius = Theme.barRadius(thickness)
    Draw.roundedRect(element, x, y, width, thickness, radius, trackColor or color, Theme.trackAlpha() * alpha)
    fraction = PUI.clamp(fraction, 0, 1)
    if fraction <= 0 then return end
    local filled = math.max(1, math.floor(width * fraction + 0.5))
    local corners = filled < width and Draw.LEFT_CORNERS or Draw.ALL_CORNERS
    Draw.roundedRect(element, x, y, filled, thickness, math.min(radius, filled / 2), color, alpha, corners)
end
