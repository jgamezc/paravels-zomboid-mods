--[[
    Paravel's Enhanced Inventory - mouse input in the list

    Vanilla's expand column is everything left of the name (pane.column2),
    which in the list is the stacks' arrows and the icons, so a stack's icon
    opened it instead of picking it up.

    Here only the arrows' column opens and closes stacks: vanilla's handlers
    run with the column they test moved there. It draws nothing, so the
    columns the rows are drawn in stay as they are. The category and weight
    columns stay vanilla's: a drag from them selects several rows, as from
    the empty area, and the quick buttons show over both and may reach over the weight.
]]

require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/List/ListColumns"

local ListColumns = PEI.ListColumns
local ViewMode = PEI.ViewMode

-- Runs a vanilla handler with the arrows' column as its expand column, so
-- the icon is on the item.
local function withArrowsColumn(vanilla, pane, ...)
    local fields = { column2 = ListColumns.compute(pane).expandWidth }
    return PUI.withFields(pane, fields, vanilla, pane, ...)
end

-- Vanilla only sets pane.mouseOverOption when the mouse moves (and per frame
-- only left of the category), and the columns are laid out again every
-- frame, so a cursor that rests where a column now is keeps the row it was
-- last over. A press there would then drag that row instead of starting the
-- selection, so the press derives the row from where it lands.
local function onMouseDown(vanilla, pane, x, y)
    if x >= pane.column3 then pane.mouseOverOption = 0 end
    return withArrowsColumn(vanilla, pane, x, y)
end

-- A quick button under the cursor takes the mouse from the pane, which then
-- gets a move-outside that hides every button; the next move shows them
-- again, so they flicker. Vanilla's buttons start at the category's left
-- edge and are sized by their titles, so in narrow category and weight
-- columns the cursor lands on them. They stay while it is over one.
local function isMouseOverQuickButton(pane)
    local x, y = pane:getMouseX(), pane:getMouseY()
    for _, button in ipairs({ pane.contextButton1, pane.contextButton2, pane.contextButton3 }) do
        if button:isVisible() and x >= button:getX() and x < button:getRight()
            and y >= button:getY() and y < button:getBottom() then
            return true
        end
    end
    return false
end

local function onMouseMoveOutside(vanilla, pane, ...)
    if isMouseOverQuickButton(pane) then return end
    return withArrowsColumn(vanilla, pane, ...)
end

ViewMode.overrideForList("onMouseDown", onMouseDown)
ViewMode.overrideForList("onMouseUp", withArrowsColumn)
ViewMode.overrideForList("onMouseMove", withArrowsColumn)
ViewMode.overrideForList("onMouseMoveOutside", onMouseMoveOutside)
ViewMode.overrideForList("onMouseDoubleClick", withArrowsColumn)
ViewMode.overrideForList("updateTooltip", withArrowsColumn)
