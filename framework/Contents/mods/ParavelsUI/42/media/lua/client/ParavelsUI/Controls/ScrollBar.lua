--[[
    Paravel's UI - themed vertical scroll bar

    Restyles any game ISScrollBar (vertical): it keeps vanilla's geometry
    (16 px arrow areas at each end, the thumb between them, sized and placed
    as vanilla does, since its clicks hit-test that geometry), but is drawn
    as Lucide chevrons and a rounded thumb, with no track.

    The thumb follows the mouse: grabbed, it stays under the point it was
    grabbed by, and a click on the track brings its middle there and grabs
    it, so it can be dragged on at once. Vanilla's own drag adds up the
    mouse's moves against a geometry of its own (20 px ends), so the thumb
    drifted from the mouse, and a click on the track only paged.

    Use: PUI.ScrollBar.restyle(scrollBar) every frame. It also puts the bar
    back where vanilla puts it, since its anchor drifts as its parent is
    resized and re-inset.
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Controls/Bounds"
require "ParavelsUI/Theme/Theme"

local Bounds = PUI.Bounds
local Theme = PUI.Theme
local Draw = PUI.Draw

local ScrollBar = PUI.ScrollBar or {}
PUI.ScrollBar = ScrollBar

-- Vanilla's scroll bar: 17 wide, placed 16 from its parent's right edge.
ScrollBar.WIDTH = 17
local INSET = 16
-- Vanilla's width of the clickable area at each end.
ScrollBar.ARROW_AREA = 16
-- Vanilla's hit box of the thumb, which its mouse handling relies on.
local THUMB_HIT_X, THUMB_HIT_WIDTH, THUMB_MIN_HEIGHT = 5, 8, 8

-- The thumb's height and how far its top travels below the top arrow, or
-- nil when the content fits and there is no thumb.
local function thumbGeometry(scrollBar)
    local height = scrollBar:getHeight()
    local contentHeight = scrollBar.parent:getScrollHeight()
    if contentHeight <= height then return nil end
    local track = height - ScrollBar.ARROW_AREA * 2
    local thumbHeight = math.max(math.ceil(height / contentHeight * track), THUMB_MIN_HEIGHT)
    return thumbHeight, track - thumbHeight
end

function ScrollBar.render(scrollBar)
    local thumbHeight, travel = thumbGeometry(scrollBar)
    if not thumbHeight then
        scrollBar.barx, scrollBar.bary, scrollBar.barwidth, scrollBar.barheight = 0, 0, 0, 0
        return
    end
    local height = scrollBar:getHeight()
    local arrowArea = ScrollBar.ARROW_AREA
    scrollBar.barx, scrollBar.bary = THUMB_HIT_X, arrowArea + math.ceil(travel * scrollBar.pos)
    scrollBar.barwidth, scrollBar.barheight = THUMB_HIT_WIDTH, thumbHeight

    local color = Theme.textColor()
    local overThumb = scrollBar.scrolling
        or (scrollBar:isMouseOver() and scrollBar:isPointOverThumb(scrollBar:getMouseX(), scrollBar:getMouseY()))
    -- The thumb, as a bar in the theme's bar shape, on the same axis as the arrows (vanilla's hit box
    -- around it is wide enough to cover it).
    local thumbWidth = Theme.scrollWidth()
    local thumbX = math.floor((scrollBar:getWidth() - thumbWidth) / 2)
    Draw.roundedRect(scrollBar, thumbX, scrollBar.bary, thumbWidth, thumbHeight,
        Theme.barRadius(thumbWidth), color, Theme.interactiveAlpha(overThumb))
    -- The arrows, centred in their areas.
    local size = Theme.smallIconSize()
    if size > 0 then
        local arrowX = math.floor((scrollBar:getWidth() - size) / 2)
        local arrowY = math.floor((arrowArea - size) / 2)
        Draw.icon(scrollBar, "chevron-up", arrowX, arrowY, size, color, Theme.mutedAlpha())
        Draw.icon(scrollBar, "chevron-down", arrowX, height - arrowArea + arrowY, size, color, Theme.mutedAlpha())
    end
end

-- Scrolls the parent so the thumb's top is at `thumbTop` (or as near as it
-- goes). The parent's smooth scrolling, if any, is stopped so it does not
-- pull the content back.
local function moveThumbTo(scrollBar, thumbTop)
    local _, travel = thumbGeometry(scrollBar)
    if not travel or travel <= 0 then return end
    local pos = PUI.clamp((thumbTop - ScrollBar.ARROW_AREA) / travel, 0, 1)
    local parent = scrollBar.parent
    scrollBar.pos = pos
    parent.smoothScrollTargetY = nil
    parent:setYScroll(-(pos * (parent:getScrollHeight() - parent:getScrollAreaHeight())))
end

-- The thumb or the track grabs the thumb; the arrows are vanilla's.
function ScrollBar.onMouseDown(scrollBar, x, y)
    local part = scrollBar:hitTest(x, y)
    if part ~= "thumb" and part ~= "trackUp" and part ~= "trackDown" then
        return ISScrollBar.onMouseDown(scrollBar, x, y)
    end
    if part == "thumb" then
        scrollBar.pui_grabY = y - scrollBar.bary
    else
        scrollBar.pui_grabY = math.floor(thumbGeometry(scrollBar) / 2)
        moveThumbTo(scrollBar, y - scrollBar.pui_grabY)
    end
    scrollBar.scrolling = true
    scrollBar:setCapture(true)
    return true
end

-- Also reached from vanilla's onMouseMoveOutside, while the mouse is off
-- the bar during a drag.
function ScrollBar.onMouseMove(scrollBar, dx, dy)
    if scrollBar.scrolling then moveThumbTo(scrollBar, scrollBar:getMouseY() - scrollBar.pui_grabY) end
end

-- Puts a vertical scroll bar where vanilla places it, along its parent's
-- right edge and as tall as it, and gives it the theme's look and drag.
function ScrollBar.restyle(scrollBar)
    local parent = scrollBar.parent
    Bounds.setX(scrollBar, parent:getWidth() - INSET)
    Bounds.setY(scrollBar, 0)
    Bounds.setHeight(scrollBar, parent:getHeight())
    scrollBar.render = ScrollBar.render
    scrollBar.onMouseDown = ScrollBar.onMouseDown
    scrollBar.onMouseMove = ScrollBar.onMouseMove
end
