--[[
    Paravel's Enhanced Tooltips - where the tooltip goes

    The game's ISToolTipInv places its tooltip next to the mouse (or at the
    spot its owner gave), inside the screen, away from the context menu
    option it belongs to and, with a gamepad, at the corner of the player's
    screen. This is that placement for a tooltip this mod draws itself,
    for a box of `width` x `height`, reusing the overlap helpers of
    ISToolTipInv.
]]

require "ISUI/ISToolTipInv"
require "ParavelsEnhancedTooltips/Core/PET"

local Placement = PET.Placement or {}
PET.Placement = Placement

-- Room kept between the tooltip and the mouse pointer, as the game does.
local MOUSE_OFFSET = 24
-- How far from the corner of the player's screen a gamepad's tooltip goes.
local JOYPAD_MARGIN = 60

-- Where the tooltip would like to be before it is moved inside the screen.
local function wantedPosition(tooltip)
    if tooltip.followMouse then return getMouseX() + MOUSE_OFFSET, getMouseY() + MOUSE_OFFSET end
    if tooltip.anchorBottomLeft then return tooltip.anchorBottomLeft.x, tooltip.anchorBottomLeft.y end
    return tooltip:getX(), tooltip:getY()
end

local function insideScreen(x, y, width, height, anchorsBottomLeft)
    local core = getCore()
    if anchorsBottomLeft then y = y - height end
    return math.max(0, math.min(x, core:getScreenWidth() - width - 1)),
        math.max(0, math.min(y, core:getScreenHeight() - height - 1))
end

-- Moves out of the way of `avoidRect`, to its right, then (if still on it)
-- to its left and then above it, in the game's order for a context menu's
-- option; for anything else its order is right, above, left.
local function moveAwayFrom(tooltip, avoidRect, belongsToOption)
    local box = { x = tooltip:getX(), y = tooltip:getY(), width = tooltip:getWidth(), height = tooltip:getHeight() }
    if belongsToOption then box.y = avoidRect.y end
    if not belongsToOption and not tooltip:overlaps(box, avoidRect) then return end
    local first, second, third = "placeRight", "placeAbove", "placeLeft"
    if belongsToOption then second, third = "placeLeft", "placeAbove" end
    local placed = tooltip[first](tooltip, box, avoidRect)
    if tooltip:overlaps(placed, avoidRect) then placed = tooltip[second](tooltip, box, avoidRect) end
    if tooltip:overlaps(placed, avoidRect) then placed = tooltip[third](tooltip, box, avoidRect) end
    tooltip:setX(placed.x)
    tooltip:setY(placed.y)
end

local function placeBesideContextMenu(tooltip, menu)
    if menu.joyfocus then
        tooltip:setX(getPlayerScreenLeft(menu.player) + JOYPAD_MARGIN)
        tooltip:setY(getPlayerScreenTop(menu.player) + JOYPAD_MARGIN)
    elseif menu.currentOptionRect then
        if menu.currentOptionRect.height > 32 then tooltip:setY(tooltip:getY() + menu.currentOptionRect.height) end
        moveAwayFrom(tooltip, menu.currentOptionRect, true)
    end
end

-- Sizes `tooltip` (an ISToolTipInv) and puts it in place.
function Placement.place(tooltip, width, height)
    local wantedX, wantedY = wantedPosition(tooltip)
    local x, y = insideScreen(wantedX, wantedY, width, height, not tooltip.followMouse and tooltip.anchorBottomLeft)
    tooltip:setX(x)
    tooltip:setY(y)
    tooltip:setWidth(width)
    tooltip:setHeight(height)
    if tooltip.contextMenu then
        placeBesideContextMenu(tooltip, tooltip.contextMenu)
    elseif tooltip.followMouse then
        moveAwayFrom(tooltip, { x = wantedX - 2 * MOUSE_OFFSET, y = wantedY - 2 * MOUSE_OFFSET, width = 2 * MOUSE_OFFSET, height = 2 * MOUSE_OFFSET }, false)
    end
end
