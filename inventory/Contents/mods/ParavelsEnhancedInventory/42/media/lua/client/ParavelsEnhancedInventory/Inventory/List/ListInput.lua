--[[
    Paravel's Enhanced Inventory - mouse input in the list

    Vanilla's list takes a row as the item only left of the category column
    (pane.column3): over the category it shows per-row quick buttons
    instead, so an item could not be picked or dragged from there or from
    the weight. Its expand column is everything left of the name
    (pane.column2), which in the list is the stacks' arrows and the icons,
    so a stack's icon opened it instead of picking it up.

    Here the whole row is the item, and only the arrows' column opens and
    closes stacks: vanilla's handlers run with the columns they test moved
    there. They draw nothing, so the columns the rows are drawn in stay as
    they are. The quick buttons no longer show; the transfers they offer
    stay in the context menu, double-click, dragging and the footer.
]]

require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/List/ListColumns"

local ListColumns = PEI.ListColumns
local ViewMode = PEI.ViewMode

-- Runs a vanilla handler with the arrows' column as its expand column and
-- no category column: every x past the arrows is on the item.
local function withWholeRows(vanilla, pane, ...)
    local fields = { column2 = ListColumns.compute(pane).expandWidth, column3 = math.huge }
    return PUI.withFields(pane, fields, vanilla, pane, ...)
end

ViewMode.overrideForList("onMouseDown", withWholeRows)
ViewMode.overrideForList("onMouseUp", withWholeRows)
ViewMode.overrideForList("onMouseMove", withWholeRows)
ViewMode.overrideForList("onMouseMoveOutside", withWholeRows)
ViewMode.overrideForList("onMouseDoubleClick", withWholeRows)
ViewMode.overrideForList("updateTooltip", withWholeRows)
