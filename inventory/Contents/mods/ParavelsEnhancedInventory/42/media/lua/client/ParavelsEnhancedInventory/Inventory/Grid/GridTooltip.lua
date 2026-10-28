--[[
    Paravel's Enhanced Inventory - item tooltip in the grid

    The same flow as vanilla's ISInventoryPane:updateTooltip(), with the
    hovered item taken from the grid cell instead of the list row.
]]

require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/Grid/GridState"

local Entries = PEI.Entries
local GridLayout = PEI.GridLayout
local GridState = PEI.GridState
local ViewMode = PEI.ViewMode

local GridTooltip = PEI.GridTooltip or {}
PEI.GridTooltip = GridTooltip

-- The item to describe and, for a stack, the weight of the whole stack.
local function hoveredItem(pane)
    if pane.dragging or pane.draggingMarquis or not pane:isMouseOver() then return nil, 0 end
    if getPlayerContextMenu(pane.player):isAnyVisible() then return nil, 0 end
    local _, layout = GridState.get(pane)
    local cell = GridLayout.cellUnderMouse(pane, layout)
    if not cell then return nil, 0 end
    if cell.sub then return cell.item, 0 end
    local stackWeight = Entries.isStack(cell.entry) and cell.entry.weight or 0
    return Entries.headerItem(cell.entry), stackWeight
end

local function isShowing(pane, item, stackWeight)
    local tooltip = pane.toolRender
    return tooltip and item == tooltip.item and stackWeight == tooltip.tooltip:getWeightOfStack()
        and tooltip:isVisible()
end

local function show(pane, item, stackWeight)
    local tooltip = pane.toolRender
    if tooltip then
        tooltip:setItem(item)
        tooltip:setVisible(true)
        tooltip:addToUIManager()
        tooltip:bringToTop()
    else
        tooltip = ISToolTipInv:new(item)
        tooltip:initialise()
        tooltip:addToUIManager()
        tooltip:setVisible(true)
        tooltip:setOwner(pane)
        tooltip:setCharacter(getSpecificPlayer(pane.player))
        tooltip.anchorBottomLeft = { x = pane:getAbsoluteX() + pane.column2, y = pane:getParent():getAbsoluteY() }
        pane.toolRender = tooltip
    end
    tooltip.followMouse = true
    tooltip.tooltip:setWeightOfStack(stackWeight)
end

local function hide(pane)
    if pane.toolRender then
        pane.toolRender:removeFromUIManager()
        pane.toolRender:setVisible(false)
    end
end

-- The game draws the inventory and loot tooltips through these two slots.
local function publishTooltips(player)
    local inventoryPage = getPlayerInventory(player)
    local inventoryTooltip = inventoryPage and inventoryPage.inventoryPane.toolRender
    local lootPage = getPlayerLoot(player)
    local lootTooltip = lootPage and lootPage.inventoryPane.toolRender
    UIManager.setPlayerInventoryTooltip(player,
        inventoryTooltip and inventoryTooltip.javaObject or nil,
        lootTooltip and lootTooltip.javaObject or nil)
end

-- Joypad players keep vanilla's tooltip, which follows the joypad's row.
ViewMode.overrideForGrid("updateTooltip", function(vanilla, pane)
    if pane.doController then return vanilla(pane) end
    -- The player's own inventory highlights the doors its hovered key opens.
    local highlightsDoors = pane.parent.onCharacter
    if not pane:isReallyVisible() then
        if highlightsDoors then Key.setHighlightDoors(pane.player, nil) end
        return
    end

    local item, stackWeight = hoveredItem(pane)
    if item and isShowing(pane, item, stackWeight) then
        if highlightsDoors then Key.setHighlightDoors(pane.player, item) end
        return
    end

    if item then show(pane, item, stackWeight) else hide(pane) end
    if highlightsDoors then
        local visible = pane.toolRender and pane.toolRender:getIsVisible()
        Key.setHighlightDoors(pane.player, visible and item or nil)
    end
    publishTooltips(pane.player)
end)
