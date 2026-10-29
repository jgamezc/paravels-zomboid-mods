--[[
    Paravel's Enhanced Inventory - equipped tab

    The player's window gets one more tab, right before the main inventory
    (the first one, leftmost):
    the same container (the player's inventory), showing what is worn, on a
    key ring or attached to the hotbar. Items held in the hands stay in the
    main inventory tab unless they are also attached. Both are vanilla
    container buttons for the same ItemContainer, so clicks, drops, context
    menus and transfers stay vanilla's; only which entries the pane lists
    depends on the tab, which Window/OpenTab.lua says.
]]

require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPane"
require "TimedActions/ISAttachItemHotbar"
require "ParavelsEnhancedInventory/Inventory/Entries"
require "ParavelsEnhancedInventory/Inventory/Window/OpenTab"

local Entries = PEI.Entries
local OpenTab = PEI.OpenTab

local EquippedTab = PEI.EquippedTab or {}
PEI.EquippedTab = EquippedTab

-- The game's own silhouette (its mannequins' container icon): what the
-- character has on, of any kind, drawn like the other tabs' icons.
EquippedTab.TEXTURE = "media/ui/Container_Mannequin.png"

local function playerInventory(page)
    local playerObj = getSpecificPlayer(page.player)
    return playerObj and playerObj:getInventory()
end

-- Whether the pane lists the player's inventory, the container the two
-- tabs split.
local function isSplitPane(pane)
    local page = pane.parent
    return page and page.onCharacter and pane.inventory ~= nil and pane.inventory == playerInventory(page)
end

-- Whether the pane lists this tab.
function EquippedTab.isListing(pane)
    local page = pane.parent
    return page ~= nil and page.onCharacter and OpenTab.shown(page) == OpenTab.EQUIPPED
end

-- ------------------------------------------------------------------ --
-- The tab
-- ------------------------------------------------------------------ --

-- Added once vanilla has its buttons, before the main inventory's. Vanilla
-- reuses its buttons from a pool, in order, so each container gets the
-- same button object again. A click is handled twice (ISButton's onclick,
-- then onBackpackMouseUp) around a refresh, so the equipped tab must keep
-- its button too: taken out of the pool at the start, it would otherwise
-- go to the next container, and the second handling open that one.
PUI.listen(Events.OnRefreshInventoryWindowContainers, "PEI.EquippedTab.addTab", function(page, state)
    if state == "begin" then
        local previous = OpenTab.buttonOf(page, OpenTab.EQUIPPED)
        OpenTab.removeButton(page, OpenTab.EQUIPPED)
        page.pei_reservedEquippedButton = nil
        for index, button in ipairs(page.buttonPool or {}) do
            if button == previous then
                page.pei_reservedEquippedButton = table.remove(page.buttonPool, index)
                break
            end
        end
        return
    end
    if state ~= "buttonsAdded" then return end
    local reserved = page.pei_reservedEquippedButton
    page.pei_reservedEquippedButton = nil
    if reserved then table.insert(page.buttonPool, 1, reserved) end
    if not page.onCharacter then return end
    local inventory = playerInventory(page)
    if not inventory then return end
    local mainIndex
    for index, button in ipairs(page.backpacks) do
        if button.inventory == inventory then
            mainIndex = index
            break
        end
    end
    if not mainIndex then return end
    local button = page:addContainerButton(inventory, getTexture(EquippedTab.TEXTURE), getText("IGUI_PEI_EquippedTab"), nil)
    button.capacity = page.backpacks[mainIndex].capacity
    OpenTab.addButton(page, OpenTab.EQUIPPED, button)
    table.remove(page.backpacks, #page.backpacks)
    table.insert(page.backpacks, mainIndex, button)
end)

-- ------------------------------------------------------------------ --
-- The entries each tab lists
-- ------------------------------------------------------------------ --

local function isHeld(entry, primaryId, secondaryId)
    if not entry.equipped or entry.inHotbar or not (primaryId or secondaryId) then return false end
    for index = Entries.FIRST_ITEM, #entry.items do
        local itemId = entry.items[index]:getID()
        if itemId == primaryId or itemId == secondaryId then return true end
    end
    return false
end

local function keepOnlyShown(pane)
    local showEquipped = EquippedTab.isListing(pane)
    local playerObj = getSpecificPlayer(pane.player)
    local primary = playerObj and playerObj:getPrimaryHandItem()
    local secondary = playerObj and playerObj:getSecondaryHandItem()
    local primaryId = primary and primary:getID()
    local secondaryId = secondary and secondary:getID()
    local kept = {}
    for _, entry in ipairs(pane.itemslist) do
        local isEquipped = Entries.isEquipped(entry) and not isHeld(entry, primaryId, secondaryId)
        if isEquipped == showEquipped then kept[#kept + 1] = entry end
    end
    pane.itemslist = kept
end

local FILTER_BEFORE_RESTORING = {
    restoreSelection = function(pane, selected)
        keepOnlyShown(pane)
        return ISInventoryPane.restoreSelection(pane, selected)
    end,
}

-- Vanilla only rebuilds a pane when its container is flagged as changed, and
-- equipping an item does not flag it (an item carried in from the floor or
-- another container is moved first, which does, and equipped afterwards).
-- Vanilla can live with that, since it marks equipped items on the fly; the
-- tabs cannot: the item would stay in the tab it was in until the next
-- refresh. So the container is flagged when what is equipped changes.
local function equippedItemIds(playerObj)
    local ids = {}
    local wornItems = playerObj:getWornItems()
    for i = 0, wornItems:size() - 1 do ids[#ids + 1] = wornItems:get(i):getItem():getID() end
    local primary, secondary = playerObj:getPrimaryHandItem(), playerObj:getSecondaryHandItem()
    if primary then ids[#ids + 1] = primary:getID() end
    if secondary then ids[#ids + 1] = secondary:getID() end
    local hotbar = getPlayerHotbar(playerObj:getPlayerNum())
    for _, item in pairs(hotbar and hotbar.attachedItems or {}) do ids[#ids + 1] = item:getID() end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function updateEquipmentState(playerObj, forceRefresh)
    local page = getPlayerInventory(playerObj:getPlayerNum())
    if not page then return end

    local equipped = equippedItemIds(playerObj)
    local changed = page.pei_equippedIds ~= equipped
    page.pei_equippedIds = equipped
    if changed or forceRefresh then playerObj:getInventory():setDrawDirty(true) end
end

-- The vanilla attach action marks its page for rendering, but the split tabs
-- depend on the inventory container's dirty state to move the item between
-- their lists. Flag it as soon as the action has updated hotbar.attachedItems.
PUI.override(ISAttachItemHotbar, "perform", function(vanilla, action)
    local result = vanilla(action)
    if action.character then updateEquipmentState(action.character, true) end
    return result
end)

PUI.listen(Events.OnTick, "PEI.EquippedTab.flagEquipmentChange", function()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then updateEquipmentState(playerObj) end
    end
end)

-- The entries are filtered once vanilla has built and sorted them, just
-- before it restores the selection: the selection is by row, so it must be
-- restored on the rows that show.
function EquippedTab.refreshContainer(vanilla, pane)
    if not isSplitPane(pane) then return vanilla(pane) end
    PUI.withFields(pane, FILTER_BEFORE_RESTORING, vanilla, pane)
end
