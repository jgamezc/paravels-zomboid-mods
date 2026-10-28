--[[
    Paravel's UI - tooltip frame

    Every tooltip draws its background and its border as a rectangle and an
    outline over its whole box. These draw overrides (Draw/DrawOverrides.lua)
    draw them as the theme's window frame instead; anything smaller is passed
    on as the game would have drawn it.
]]

require "ParavelsUI/Core/PUI"
require "ParavelsUI/Shapes/WindowFrame"

local WindowFrame = PUI.WindowFrame

local TooltipFrame = PUI.TooltipFrame or {}
PUI.TooltipFrame = TooltipFrame

function TooltipFrame.coversWholeBox(tooltip, x, y, w)
    return x == 0 and y == 0 and w == tooltip:getWidth()
end

function TooltipFrame.drawRect(tooltip, x, y, w, h, ...)
    if TooltipFrame.coversWholeBox(tooltip, x, y, w) then return WindowFrame.drawBackground(tooltip, h) end
    return ISUIElement.drawRect(tooltip, x, y, w, h, ...)
end

function TooltipFrame.drawRectBorder(tooltip, x, y, w, h, ...)
    if TooltipFrame.coversWholeBox(tooltip, x, y, w) then return WindowFrame.drawOutline(tooltip, h) end
    return ISUIElement.drawRectBorder(tooltip, x, y, w, h, ...)
end
