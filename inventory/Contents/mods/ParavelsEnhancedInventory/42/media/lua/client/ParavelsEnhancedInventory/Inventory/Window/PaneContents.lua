--[[
    Paravel's Enhanced Inventory - what the pane lists

    The one hook of ISInventoryPane:refreshContainer (a second one would
    replace it), so everything that changes what the pane lists after a
    refresh is composed here, in order: the open tab's entries (the
    equipped tab splits the player's window, the proximity tab is the loot
    window's), the hotbar's items counted as equipped (Sorting), the grid's
    order (Grid/GridState.lua), and the list's header hidden again in the
    grid (vanilla shows its expand button on every refresh).
]]

require "ISUI/ISInventoryPane"
require "ParavelsEnhancedInventory/Inventory/Window/EquippedTab"
require "ParavelsEnhancedInventory/Inventory/Window/ProximityTab"
require "ParavelsEnhancedInventory/Inventory/List/ListHeader"
require "ParavelsEnhancedInventory/Inventory/Sorting"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/Grid/GridState"

local EquippedTab = PEI.EquippedTab
local GridState = PEI.GridState
local ListHeader = PEI.ListHeader
local ProximityTab = PEI.ProximityTab
local Sorting = PEI.Sorting
local ViewMode = PEI.ViewMode

local PaneContents = PEI.PaneContents or {}
PEI.PaneContents = PaneContents

local function refreshRows(vanilla)
    return function(pane) return Sorting.refreshWithHotbarAsEquipped(vanilla, pane) end
end

PUI.override(ISInventoryPane, "refreshContainer", function(vanilla, pane)
    if pane.parent and not pane.parent.onCharacter then
        ProximityTab.refreshContainer(refreshRows(vanilla), pane)
    else
        EquippedTab.refreshContainer(refreshRows(vanilla), pane)
    end
    if ViewMode.isGrid(pane) then GridState.onRefresh(pane) end
    ListHeader.layout(pane)
end)
