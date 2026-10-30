--[[
    Paravel's Enhanced Inventory - proximity tab

    The loot window gets one more tab, the first one (leftmost): every item
    of every container around the player (the floor, furniture, bodies,
    bags on the floor) in a single list. It is open by default; picking
    another tab keeps that one open until its container is out of reach
    (Window/OpenTab.lua keeps which is open).

    The tab is a vanilla container button for the floor's ItemContainer,
    like the equipped tab shares the player's inventory, so the lists that
    gather the containers around the player (crafting, "transfer same type"
    to every container...) never count an item twice. Only while the pane
    lists the tab does it see, in place of the floor, a container of its own
    holding all the items: vanilla builds the rows, the weight and the loot
    controls from it. Its items stay in their real containers (they are put
    in its list, not moved), so transfers, drags, double clicks and context
    menus take each item from where it is, as vanilla's code does. Like the
    floor, it is typed "floor": items given to it are dropped.

    Vanilla's transfers open the container each item comes from, which
    shows what is being taken; once the player is done, a window that was
    on this tab goes back to it.
]]

require "ParavelsEnhancedInventory/Core/PEI"
require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPane"
require "ISUI/LootWindow/ISLootWindowContainerControls"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferAction"
require "ParavelsEnhancedInventory/Inventory/Window/OpenTab"
require "ParavelsEnhancedInventory/Inventory/Options"

local OpenTab = PEI.OpenTab
local Options = PEI.Options

local ProximityTab = PEI.ProximityTab or {}
PEI.ProximityTab = ProximityTab

-- The game's crate (its boxes' container icon), drawn like the other tabs'
-- icons: a container of containers.
ProximityTab.TEXTURE = "media/ui/Container_Crate.png"

-- The container each player's tab lists, kept across refreshes (and reloads).
ProximityTab.containers = ProximityTab.containers or {}

-- Pages a transfer took off the tab, to go back to it when it is done.
ProximityTab.returning = ProximityTab.returning or {}

local function nearbyContainer(playerNum)
    local container = ProximityTab.containers[playerNum]
    if not container then
        container = ItemContainer.new("floor", nil, nil)
        container:setExplored(true)
        ProximityTab.containers[playerNum] = container
    end
    return container
end

local function isProximityTab(page, button)
    return OpenTab.kindOf(page, button) == OpenTab.PROXIMITY
end

-- Whether the page shows the tab: it has one, it was not left for another
-- tab, and the pane lists the floor, the container the tab shares.
function ProximityTab.isShown(page)
    return OpenTab.shown(page) == OpenTab.PROXIMITY
end

local function isListing(pane)
    local page = pane.parent
    return page ~= nil and not page.onCharacter and ProximityTab.isShown(page)
end

-- Runs fn while the pane lists the tab's own container instead of the floor.
local function withNearbyItems(pane, fn, ...)
    return PUI.withFields(pane, { inventory = nearbyContainer(pane.player) }, fn, pane, ...)
end

-- ------------------------------------------------------------------ --
-- The tab
-- ------------------------------------------------------------------ --

local function isLocked(container, playerObj)
    local object = container:getParent()
    return instanceof(object, "IsoThumpable") and object:isLockedToCharacter(playerObj)
end

local function listsContainer(page, inventory)
    for _, button in ipairs(page.backpacks) do
        if button.inventory == inventory and not isProximityTab(page, button) then return true end
    end
    return false
end

-- Gathers the items of the containers the other tabs show.
local function fillNearbyContainer(page)
    local playerObj = getSpecificPlayer(page.player)
    local items = nearbyContainer(page.player):getItems()
    items:clear()
    for _, button in ipairs(page.backpacks) do
        local container = button.inventory
        if not isProximityTab(page, button) and not isLocked(container, playerObj) then
            items:addAll(container:getItems())
        end
    end
end

local function rememberSelection(page)
    page.pei_refreshSelection = nil
    if not page.pei_proximityTabBuiltWith then return end
    page.pei_refreshSelection = {
        kind = OpenTab.chosen(page),
        inventory = page.inventoryPane and page.inventoryPane.inventory,
    }
end

local function restoreSelection(page)
    local selection = page.pei_refreshSelection
    page.pei_refreshSelection = nil

    local pane = page.inventoryPane
    local floor = ISInventoryPage.GetFloorContainer(page.player)
    if selection and selection.kind == OpenTab.PROXIMITY then
        OpenTab.choose(page, OpenTab.PROXIMITY)
        pane.inventory = floor
        page.forceSelectedContainer = nil
        return
    end

    local inventory = selection and selection.inventory
    local playerObj = getSpecificPlayer(page.player)
    if inventory and listsContainer(page, inventory) and not isLocked(inventory, playerObj) then
        OpenTab.choose(page, OpenTab.CONTAINER)
        pane.inventory = inventory
        return
    end

    if selection or not pane.inventory or not listsContainer(page, pane.inventory) then
        OpenTab.choose(page, OpenTab.PROXIMITY)
        pane.inventory = floor
    end
end

local function nearbyHighlightObjects(page)
    local objects = {}
    local playerObj = getSpecificPlayer(page.player)
    for _, button in ipairs(page.backpacks) do
        local container = button.inventory
        if not isProximityTab(page, button) and not isLocked(container, playerObj) then
            local object = page:getContainerParent(container)
            if object and not (instanceof(object, "IsoPlayer") and not instanceof(object, "IsoDeadBody")) then
                objects[object] = true
            end
        end
    end
    return objects
end

local function clearNearbyHighlights(page, keep)
    local previous = page.pei_nearbyHighlighted or {}
    for object in pairs(previous) do
        if not keep or not keep[object] then
            object:setHighlighted(page.player, false)
            object:setOutlineHighlight(page.player, false)
            object:setOutlineHlAttached(page.player, false)
            previous[object] = nil
        end
    end
end

local function hoveredTabButton(page)
    for _, button in ipairs(page.backpacks) do
        if button:getIsVisible() and button:isPointOver(getMouseX(), getMouseY()) then return button end
    end
end

local function highlightNearbyObjects(page)
    local isNearbyActive = not page.isCollapsed and ProximityTab.isShown(page)
    local objects = isNearbyActive and nearbyHighlightObjects(page) or {}
    local hoveredButton = isNearbyActive and hoveredTabButton(page) or nil
    if hoveredButton then
        local hoveredObject = page:getContainerParent(hoveredButton.inventory)
        objects = hoveredObject and { [hoveredObject] = true } or {}
    end
    clearNearbyHighlights(page, objects)
    local color = getCore():getObjectHighlitedColor()
    local outlineColor = hoveredButton and getCore():getWorldItemHighlightColor() or color
    for object in pairs(objects) do
        object:setHighlighted(page.player, true, false)
        if getCore():getOptionDoContainerOutline() then
            object:setOutlineHighlight(page.player, true)
            object:setOutlineHlAttached(page.player, true)
            object:setOutlineHighlightCol(page.player, outlineColor:getR(), outlineColor:getG(), outlineColor:getB(), 1)
        end
        object:setHighlightColor(page.player, color)
    end
    page.pei_nearbyHighlighted = objects
end

PUI.override(ISInventoryPage, "updateContainerHighlight", function(vanilla, page, ...)
    local result = vanilla(page, ...)
    if not page.onCharacter then highlightNearbyObjects(page) end
    return result
end)

PUI.override(ISInventoryPage, "close", function(vanilla, page, ...)
    local result = vanilla(page, ...)
    if not page.onCharacter then clearNearbyHighlights(page) end
    return result
end)

-- Added first, so it is the leftmost tab. Vanilla reuses its buttons from a
-- pool, in order, so the tab gets the same button again on every refresh.
-- Inside a vehicle, this adds a floor button of its own alongside the
-- vehicle's part buttons; the nearby list can then gather those containers.
PUI.listen(Events.OnRefreshInventoryWindowContainers, "PEI.ProximityTab.addTab", function(page, state)
    if page.onCharacter then return end
    if state == "begin" then
        OpenTab.removeButton(page, OpenTab.PROXIMITY)
        -- What the tabs of this window are made with: followOption compares it
        -- with the option to know the window is out of date.
        page.pei_proximityTabBuiltWith = Options.get("showProximityTab")
        rememberSelection(page)
        local playerObj = getSpecificPlayer(page.player)
        if not playerObj then return end
        if not page.pei_proximityTabBuiltWith then
            -- Never left chosen with no tab to show: the floor's own tab, or
            -- the container the game picks, takes over.
            if OpenTab.chosen(page) == OpenTab.PROXIMITY then OpenTab.choose(page, OpenTab.CONTAINER) end
            return
        end
        local floor = ISInventoryPage.GetFloorContainer(page.player)
        local button = page:addContainerButton(floor, getTexture(ProximityTab.TEXTURE), getText("IGUI_PEI_ProximityTab"), nil)
        button.capacity = floor:getMaxWeight()
        OpenTab.addButton(page, OpenTab.PROXIMITY, button)
        return
    end
    if state ~= "buttonsAdded" or not OpenTab.buttonOf(page, OpenTab.PROXIMITY) then return end
    fillNearbyContainer(page)
    -- Vanilla temporarily selects the first container it finds while the
    -- player moves. Restore the user's choice before vanilla finalizes it.
    restoreSelection(page)
end)

-- The tabs are only made when the game asks, so a change of the option
-- asks for them again, on the windows built with the other value. That
-- request goes through "begin" above, which stores the new value, so it
-- is made once and not on every tick.
PUI.listen(Events.OnTick, "PEI.ProximityTab.followOption", function()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local page = getPlayerLoot(playerNum)
        if page and page.pei_proximityTabBuiltWith ~= nil and page.pei_proximityTabBuiltWith ~= Options.get("showProximityTab") then
            page:refreshBackpacks()
        end
    end
end)

-- ------------------------------------------------------------------ --
-- Back to the tab after a transfer
-- ------------------------------------------------------------------ --

local SELECTING_FOR_TRANSFER = { pei_selectingForTransfer = true }

-- Only a "take all" / "transfer all" follows the items from container to
-- container; a single item, or a hand-picked few, leave the tab as it is.
-- The actions are marked when created, as they run later, one at a time.
ProximityTab.creatingBatch = false

PUI.override(ISInventoryTransferAction, "new", function(vanilla, ...)
    local action = vanilla(...)
    action.pei_batch = ProximityTab.creatingBatch or nil
    return action
end)

local function asBatch(vanilla, pane)
    return PUI.withFields(ProximityTab, { creatingBatch = true }, vanilla, pane)
end

PUI.override(ISInventoryPane, "transferAll", asBatch)

-- Runs the action's start, update and perform knowing whether it is part of a batch.
local function overrideStep(name)
    PUI.override(ISInventoryTransferAction, name, function(vanilla, action)
        local page = getPlayerLoot(action.character:getPlayerNum())
        return PUI.withFields(page, { pei_singleTransfer = not action.pei_batch }, vanilla, action)
    end)
end
overrideStep("start")
overrideStep("update")
overrideStep("perform")

-- Transfers open the container they take from (or put into) through this.
-- A tab picked by hand meanwhile cancels the return (Window/TabSelection.lua).
PUI.override(ISInventoryPage, "selectButtonForContainer", function(vanilla, page, container)
    local wasOnTab = ProximityTab.isShown(page) or ProximityTab.returning[page] ~= nil
    if wasOnTab and page.pei_singleTransfer then return end
    PUI.withFields(page, SELECTING_FOR_TRANSFER, vanilla, page, container)
    if wasOnTab and OpenTab.buttonOf(page, OpenTab.PROXIMITY) and not ProximityTab.isShown(page) then
        ProximityTab.returning[page] = true
    end
end)

-- A tab picked by hand, or a container the game chose, stays open after the
-- transfers: no return. What a transfer opens itself does not count.
function ProximityTab.cancelReturn(page)
    if not page.pei_selectingForTransfer then ProximityTab.returning[page] = nil end
end

PUI.listen(Events.OnTick, "PEI.ProximityTab.returnAfterTransfers", function()
    if PUI.isEmpty(ProximityTab.returning) then return end
    for page in pairs(ProximityTab.returning) do
        local playerObj = getSpecificPlayer(page.player)
        if not playerObj or not ISTimedActionQueue.isPlayerDoingAction(playerObj) then
            ProximityTab.returning[page] = nil
            local button = OpenTab.buttonOf(page, OpenTab.PROXIMITY)
            if playerObj and button and not ProximityTab.isShown(page) then page:selectContainer(button) end
        end
    end
end)

-- ------------------------------------------------------------------ --
-- What the pane sees while the tab is open
-- ------------------------------------------------------------------ --

-- The rows. Vanilla clears the dirty mark of the container it lists; the
-- floor's is cleared too, or the pane would rebuild on every frame.
function ProximityTab.refreshContainer(vanilla, pane)
    if not isListing(pane) then return vanilla(pane) end
    local floor = pane.inventory
    withNearbyItems(pane, vanilla)
    floor:setDrawDirty(false)
end

PUI.override(ISInventoryPane, "lootAll", function(vanilla, pane)
    if not isListing(pane) then return asBatch(vanilla, pane) end
    -- withNearbyItems calls its function as fn(pane), while asBatch takes
    -- (vanilla, pane): the batch wraps a step that lists the nearby items.
    return asBatch(function(listingPane) return withNearbyItems(listingPane, vanilla) end, pane)
end)

-- The weight shown, read by the page from the container the pane lists.
PUI.override(ISInventoryPage, "loadWeight", function(vanilla, inventory)
    for playerNum, container in pairs(ProximityTab.containers) do
        if inventory == ISInventoryPage.GetFloorContainer(playerNum) then
            local loot = getPlayerLoot(playerNum)
            if loot and ProximityTab.isShown(loot) then return vanilla(container) end
        end
    end
    return vanilla(inventory)
end)

-- The loot controls (and the window's transfer buttons, which follow them)
-- act on all the items: having no object, the container gets the floor's.
PUI.override(ISLootWindowContainerControls, "getDisplayedContainer", function(vanilla, controls)
    local page = controls.lootWindow
    if page and ProximityTab.isShown(page) then return nearbyContainer(page.player) end
    return vanilla(controls)
end)
