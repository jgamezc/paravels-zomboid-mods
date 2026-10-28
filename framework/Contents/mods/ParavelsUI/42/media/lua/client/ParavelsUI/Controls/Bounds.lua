--[[
    Paravel's UI - placing elements

    The windows are laid out again every frame, since vanilla moves their
    parts back on its own. ISUIElement's setters always call into Java,
    several times each (setX asks whether the element keeps on screen,
    setWidth sets x again, setVisible reads visibility and may lay out the
    element), so placing an element where it already is still costs. These
    do nothing when the value is already set; the Lua fields they compare
    (x, y, width, height) are the ones ISUIElement's setters keep.
]]

require "ParavelsUI/Core/PUI"

local Bounds = PUI.Bounds or {}
PUI.Bounds = Bounds

function Bounds.setX(element, x)
    if element.x ~= x then element:setX(x) end
end

function Bounds.setY(element, y)
    if element.y ~= y then element:setY(y) end
end

function Bounds.setWidth(element, width)
    if element.width ~= width then element:setWidth(width) end
end

function Bounds.setHeight(element, height)
    if element.height ~= height then element:setHeight(height) end
end

function Bounds.setVisible(element, visible)
    visible = visible and true or false
    if element:isVisible() ~= visible then element:setVisible(visible) end
end

-- Shows the element as a w x h box at x, y. Whoever places an element
-- calls this or Bounds.hide once a frame, never both: showing it and then
-- hiding it again would cost a layout every frame.
function Bounds.show(element, x, y, w, h)
    Bounds.setWidth(element, w)
    Bounds.setHeight(element, h)
    Bounds.setX(element, x)
    Bounds.setY(element, y)
    Bounds.setVisible(element, true)
end

function Bounds.hide(element)
    Bounds.setVisible(element, false)
end
