--[[
    Paravel's Enhanced Inventory - choosing a tab

    Which tab is open, with the mouse wheel over the window and with tabs
    that share a container: the equipped tab (Window/EquippedTab.lua) and
    the proximity tab (Window/ProximityTab.lua) are vanilla buttons for a
    container another tab has too. Vanilla tells containers apart by their
    ItemContainer alone, so these hooks choose the kind of tab that is open
    (Window/OpenTab.lua).
]]

require "ISUI/ISInventoryPage"
require "ParavelsEnhancedInventory/Inventory/Window/OpenTab"
require "ParavelsEnhancedInventory/Inventory/Window/ProximityTab"
require "ParavelsEnhancedInventory/Inventory/Options"

local OpenTab = PEI.OpenTab
local Options = PEI.Options
local ProximityTab = PEI.ProximityTab

local TabSelection = PEI.TabSelection or {}
PEI.TabSelection = TabSelection

-- ------------------------------------------------------------------ --
-- The mouse wheel
-- ------------------------------------------------------------------ --

-- Vanilla cycles containers with the wheel over its column, which it finds
-- by the column's place on the right. Over the tabs, the page's handler is
-- given the mouse's x as if it were there; it is called through the page so
-- mods that patch it on the instance still run. The tabs consume the wheel
-- themselves, so it never falls through to zoom the world even when such a
-- patch returns false.
--
-- Past the last tab the wheel goes on to the first (and back) when the
-- player loops the tabs, and stops otherwise; vanilla loops only once the
-- wheel has rested for a moment. A container shown without a tab (index
-- -1) goes to the first or last tab, as vanilla's. Vanilla's own search is
-- run without wrapping, since its wrap calls the page's method again,
-- which is this one while the wheel turns.
local function nextTab(page, index)
    local found = ISInventoryPage.nextUnlockedContainer(page, index, false)
    if found == -1 and (Options.get("loopTabs") or index < 0) then
        found = ISInventoryPage.nextUnlockedContainer(page, 0, false)
    end
    return found
end

local function previousTab(page, index)
    local found = ISInventoryPage.prevUnlockedContainer(page, index, false)
    if found == -1 and (Options.get("loopTabs") or index < 0) then
        found = ISInventoryPage.prevUnlockedContainer(page, #page.backpacks + 1, false)
    end
    return found
end

local WHEEL_OVER_TABS = {
    pei_wheelOverTabs = true,
    getMouseX = function(page) return page:getWidth() end,
    nextUnlockedContainer = nextTab,
    prevUnlockedContainer = previousTab,
}
local WHEEL_ELSEWHERE = {
    getMouseX = function() return 0 end,
    nextUnlockedContainer = nextTab,
    prevUnlockedContainer = previousTab,
}

PUI.override(ISInventoryPageContainerButtonPanel, "onMouseWheel", function(vanilla, column, delta)
    local page = column.parent
    PUI.withFields(page, WHEEL_OVER_TABS, page.onMouseWheel, page, delta)
    return true
end)

-- Elsewhere in the window, vanilla's check would cycle near the right edge.
PUI.override(ISInventoryPage, "onMouseWheel", function(vanilla, page, delta)
    if page.pei_wheelOverTabs then
        vanilla(page, delta)
        return true
    end
    PUI.withFields(page, WHEEL_ELSEWHERE, vanilla, page, delta)
    return true
end)

-- ------------------------------------------------------------------ --
-- Tabs that share a container
-- ------------------------------------------------------------------ --

-- Clicking a tab (or the wheel, or the scroll arrows) opens it. Vanilla
-- leaves a locked container unselected; then the open tab stays as it was.
PUI.override(ISInventoryPage, "selectContainer", function(vanilla, page, button)
    local before = page.pei_openTab
    OpenTab.choose(page, OpenTab.kindOf(page, button))
    ProximityTab.cancelReturn(page)
    local result = vanilla(page, button)
    if page.inventoryPane.inventory ~= button.inventory then OpenTab.choose(page, before) end
    return result
end)

-- A container chosen by the game (not by a tab) is shown as itself.
PUI.override(ISInventoryPage, "setNewContainer", function(vanilla, page, inventory)
    OpenTab.choose(page, OpenTab.CONTAINER)
    ProximityTab.cancelReturn(page)
    return vanilla(page, inventory)
end)

-- Vanilla finds the open tab by its container alone: the wheel and the
-- joypad then step from the right one.
PUI.override(ISInventoryPage, "getCurrentBackpackIndex", function(vanilla, page)
    for index, button in ipairs(page.backpacks) do
        if OpenTab.isSelected(page, button) then return index end
    end
    return vanilla(page)
end)
