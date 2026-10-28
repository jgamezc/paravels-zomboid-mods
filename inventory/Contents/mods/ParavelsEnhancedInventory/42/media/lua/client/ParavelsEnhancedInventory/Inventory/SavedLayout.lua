--[[
    Paravel's Enhanced Inventory - what each window keeps in layout.ini

    Vanilla's layout manager saves each window (inventory, loot) with its
    pane. Besides what vanilla keeps, the pane saves its view (list, grid or compact),
    the sorts vanilla does not save (weight, family), where the list's
    name/category divider is and the width of its weight column once that
    divider has been dragged. Vanilla saves the name's width instead, which
    it adds to its own name column's start on loading; the list's starts
    elsewhere, so the divider would move on every load.
]]

require "ISUI/ISInventoryPage"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/Sorting"
require "ParavelsEnhancedInventory/Inventory/Window/Window"

local Sorting = PEI.Sorting
local ViewMode = PEI.ViewMode
local Window = PEI.Window

PUI.override(ISInventoryPane, "SaveLayout", function(vanilla, pane, name, layout)
    vanilla(pane, name, layout)
    layout.peiView = ViewMode.viewOf(pane)
    local sortName = Sorting.savedName(pane.itemSortFunc)
    if sortName then layout.sortBy = sortName end
    if pane.pei_weightW then layout.peiWeightW = pane.pei_weightW end
    if pane.column3 then layout.peiNameRight = pane.column3 end
end)

PUI.override(ISInventoryPane, "RestoreLayout", function(vanilla, pane, name, layout)
    vanilla(pane, name, layout)
    if tonumber(layout.peiWeightW) then pane.pei_weightW = tonumber(layout.peiWeightW) end
    if tonumber(layout.peiNameRight) then pane.column3 = tonumber(layout.peiNameRight) end
    local sortFunction = Sorting.fromSavedName(layout.sortBy)
    if sortFunction then Sorting.set(pane, sortFunction) end
    if ViewMode.isView(layout.peiView) then ViewMode.setView(pane, layout.peiView) end
end)

-- A restored layout sets the window's size: its grid columns and rows are
-- taken from that size again.
PUI.override(ISInventoryPage, "RestoreLayout", function(vanilla, page, name, layout)
    vanilla(page, name, layout)
    Window.forgetGridSize(page)
end)
