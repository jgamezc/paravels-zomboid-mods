--[[
    Paravel's Enhanced Inventory - transfer buttons

    Vanilla's container controls (transfer all, same type...) are hidden with
    the status bar; their actions come back as Lucide icons in the footer,
    left of the sort button (Window/Footer.lua places them). The window keeps its own copy of each handler
    (vanilla's are tied to the hidden controls and re-take their buttons on
    every arrange), so the decisions of what to offer, what a click does and
    which items light up on hover stay vanilla's. Texts are vanilla's,
    already translated.
]]

require "ISUI/ISInventoryPage"
require "ParavelsEnhancedInventory/Inventory/Window/EquippedTab"
require "ParavelsEnhancedInventory/Inventory/Window/ProximityTab"
require "ParavelsEnhancedInventory/Inventory/Entries"
require "ParavelsUI/Controls/IconButton"
require "ParavelsUI/Controls/Bounds"

local Bounds = PUI.Bounds
local Entries = PEI.Entries
local EquippedTab = PEI.EquippedTab
local IconButton = PUI.IconButton
local ProximityTab = PEI.ProximityTab
local Theme = PUI.Theme

local TransferButtons = PEI.TransferButtons or {}
PEI.TransferButtons = TransferButtons

-- A new table on every load of this file: cached decisions made by an
-- earlier load are not reused.
local LOAD_TOKEN = {}

-- ------------------------------------------------------------------ --
-- Drop all
-- Vanilla has no "move to floor" for the player's inventory, only for a
-- container in the loot window. This one drops what transfer all would
-- move (not equipped, favourite, on the hotbar or a key ring), the same way
-- transfer all does when the loot window shows the floor. On the equipped
-- tab it drops what the tab shows instead (still not favourites): vanilla's
-- drop takes each item off first. The class is made
-- once, so its handlers and buttons survive a reload; its methods are
-- re-set each load.
-- ------------------------------------------------------------------ --

TransferButtons.DropAllHandler = TransferButtons.DropAllHandler
    or ISInventoryWindowControlHandler:derive("PEI_InventoryWindowControlHandler_DropAll")
local DropAll = TransferButtons.DropAllHandler

function DropAll:shouldBeVisible()
    if getCore():getGameMode() == "Tutorial" then return false end
    return not self.container:isEmpty()
end

local function canBeOnFloor(item)
    return not (instanceof(item, "Moveable") and item:getSpriteGrid() == nil and not item:CanBeDroppedOnFloor())
end

-- What vanilla's transfer all leaves where it is.
local function isMovable(item, inventory, playerObj, hotbar)
    local isKeyRing = inventory == playerObj:getInventory()
        and (item:isItemType(ItemType.KEY_RING) or item:hasTag(ItemTag.KEY_RING))
    return not (item:isEquipped() or isKeyRing or hotbar:isInHotbar(item) or item:isFavorite())
end

-- What the equipped tab shows: its entries are the pane's rows.
local function shownItems(pane)
    local items = {}
    for _, entry in ipairs(pane.itemslist or {}) do
        for index = Entries.FIRST_ITEM, #entry.items do
            local item = entry.items[index]
            if not item:isFavorite() and canBeOnFloor(item) then table.insert(items, item) end
        end
    end
    return items
end

-- What transfer all moves out of the pane's container; when it goes to the
-- floor, only what can be put there. The buttons offer exactly this, and
-- drop all does it.
local function itemsToMove(pane, toFloor)
    if EquippedTab.isListing(pane) then return shownItems(pane) end
    local inventory = pane.inventory
    local playerObj = getSpecificPlayer(pane.player)
    local hotbar = getPlayerHotbar(pane.player)
    local items = {}
    local allItems = inventory:getItems()
    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        if isMovable(item, inventory, playerObj, hotbar) and not (toFloor and not canBeOnFloor(item)) then
            table.insert(items, item)
        end
    end
    return items
end

function DropAll:perform()
    if isGamePaused() then return end
    local pane = self.inventoryWindow.inventoryPane
    if not pane.inventory or not luautils.walkToContainer(pane.inventory, self.playerNum) then return end
    pane:transferItemsByWeight(itemsToMove(pane, true), ISInventoryPage.GetFloorContainer(self.playerNum))
    pane.selected = {}
end

function DropAll:new()
    return ISInventoryWindowControlHandler.new(self)
end

-- ------------------------------------------------------------------ --
-- What each window offers
-- ------------------------------------------------------------------ --

-- Vanilla's transfer all reads the loot window's `inventory` field, which is
-- only set when a container is picked by hand; one the window chose by
-- itself (walking up to it) shows in the pane but leaves the field stale.
local function perform(handler)
    local loot = getPlayerLoot(handler.playerNum)
    if loot and loot.inventoryPane.inventory then loot.inventory = loot.inventoryPane.inventory end
    handler:perform()
end

-- Vanilla's transfer all leaves equipped items, which are all the equipped
-- tab shows: there it moves what the tab shows (still not favourites) the
-- way vanilla's "move to" does, taking each item off first. To the floor,
-- that is dropping them.
local function transferAll(handler)
    local page = handler.inventoryWindow
    local pane = page.inventoryPane
    local loot = getPlayerLoot(handler.playerNum)
    if not EquippedTab.isListing(pane) then return perform(handler) end
    local destination = loot and loot.inventoryPane.inventory
    if not destination then return end
    local items = shownItems(pane)
    if #items > 0 then ISInventoryPaneContextMenu.onMoveItemsTo(items, destination, handler.playerNum) end
    pane.selected = {}
end

-- One button spec per handler class: a Lucide icon and vanilla's tooltip.
-- `action` replaces vanilla's perform.
-- `rules` (all optional) decide when it shows, besides the handler's own
-- shouldBeVisible: `hasItems(handler)` is whether a click would move at
-- least one item, so a button never shows to do nothing; `isRedundant(page)`
-- leaves it out when another button does its job.
local function transferSpec(class, icon, tooltip, action, rules)
    action = action or perform
    rules = rules or {}
    return { class = class, icon = icon, tooltip = tooltip, hasItems = rules.hasItems,
             isRedundant = rules.isRedundant, onClick = function(handler) action(handler) end }
end

-- Same-type handlers choose their items in getItemsToTransfer: a click moves
-- exactly those.
local function hasMatchingItems(handler)
    return #handler:getItemsToTransfer() > 0
end

local function canDropItems(handler)
    return #itemsToMove(handler.inventoryWindow.inventoryPane, true) > 0
end

-- Transfer all goes to the loot window's container; vanilla's own list is
-- not reachable without running it, so this mirrors it (itemsToMove).
local function canTransferItems(handler)
    local pane = handler.inventoryWindow.inventoryPane
    local destination = getPlayerLoot(handler.playerNum).inventoryPane.inventory
    return #itemsToMove(pane, destination:getType() == "floor") > 0
end

-- Whether the loot window is on the proximity tab. Then "same type to the
-- displayed container" can only reach the floor's own items (the tab's
-- container is typed floor, so they are dropped), which "same type to nearby
-- containers" already does and puts each item in the container that holds its type.
local function isLootOnProximityTab(page)
    local loot = getPlayerLoot(page.player)
    return loot ~= nil and ProximityTab.isShown(loot)
end

-- The player's inventory moves things out to the loot window or drops them.
-- Left to right; transfer all, the most used, is last, next to the sort button.
local INVENTORY_SPECS = {
    transferSpec(DropAll, "arrow-down-to-dot", "ContextMenu_MoveToFloor", nil, { hasItems = canDropItems }),
    transferSpec(ISInventoryWindowControlHandler_TransferSameType, "layers",
        "IGUI_invpage_TransferSameTypeOneContainer_tt", nil,
        { hasItems = hasMatchingItems, isRedundant = isLootOnProximityTab }),
    transferSpec(ISInventoryWindowControlHandler_TransferSameTypeMultiContainer, "boxes",
        "IGUI_invpage_TransferSameTypeMultiContainer_tt", nil, { hasItems = hasMatchingItems }),
    transferSpec(ISInventoryWindowControlHandler_TransferAll, "arrow-up-from-line", "IGUI_invpage_Transfer_all",
        transferAll, { hasItems = canTransferItems }),
}

-- The loot window takes things in, and moves a container's items to the
-- floor. It offers only what its (hidden) controls show now: which handlers
-- apply to a container is theirs to decide, and other mods change it (a
-- virtual container treated like the floor, say) by changing arrange().
-- Left to right; take all is last, next to the sort button, as transfer all is.
local LOOT_SPECS = {
    transferSpec(ISLootWindowObjectControlHandler_TakeSameType, "layers", "IGUI_invpage_Loot_TakeSameType_tt",
        nil, { hasItems = hasMatchingItems }),
    transferSpec(ISLootWindowObjectControlHandler_MoveToFloor, "arrow-down-to-dot", "ContextMenu_MoveToFloor"),
    transferSpec(ISLootWindowObjectControlHandler_TakeAll, "arrow-down-to-line", "IGUI_invpage_Loot_all"),
    transferSpec(ISLootWindowFloorControlHandler_TakeSameType, "layers", "IGUI_invpage_Loot_TakeSameType_tt",
        nil, { hasItems = hasMatchingItems }),
    transferSpec(ISLootWindowFloorControlHandler_TakeAll, "arrow-down-to-line", "IGUI_invpage_Loot_all"),
}

-- The handler classes whose control the last arrange() put in the controls.
-- A handler keeps its control after the container changes, but the list of
-- controls is rebuilt by every arrange().
local function shownHandlerClasses(controlsUI)
    local isListed = {}
    for _, control in ipairs(controlsUI.controls or {}) do isListed[control] = true end
    local shown = {}
    for class, handler in pairs(controlsUI.handlers or {}) do
        if handler.control and isListed[handler.control] then shown[class] = true end
    end
    return shown
end

local function candidateSpecs(page)
    if page.onCharacter then
        local specs = {}
        for _, spec in ipairs(INVENTORY_SPECS) do
            if not (spec.isRedundant and spec.isRedundant(page)) then table.insert(specs, spec) end
        end
        return specs
    end
    local shown = shownHandlerClasses(page.controlsUI)
    local specs = {}
    for _, spec in ipairs(LOOT_SPECS) do
        if shown[spec.class] then table.insert(specs, spec) end
    end
    return specs
end

-- The window's own handler of a class, set up for the container shown.
local function windowHandler(page, class, object, container)
    page.pei_handlers = page.pei_handlers or {}
    local handler = page.pei_handlers[class]
    if not handler then
        handler = class:new()
        page.pei_handlers[class] = handler
    end
    -- Both kinds of handler are given the window under the name they use.
    handler.inventoryWindow, handler.lootWindow = page, page
    handler.playerNum = page.player
    handler.playerObj = getSpecificPlayer(page.player)
    handler.object, handler.container = object, container
    return handler
end

-- The specs whose handler is visible now and whose click would move
-- something. Deciding that walks the containers' items, so it is redone only
-- when one of the two panes refreshed, or the container or the tab changed.
local function visibleSpecs(page)
    local pane, controlsUI = page.inventoryPane, page.controlsUI
    local otherPage = page.onCharacter and getPlayerLoot(page.player) or getPlayerInventory(page.player)
    local container = controlsUI and controlsUI:getDisplayedContainer()
    local otherPane = otherPage and otherPage.inventoryPane
    local cached = page.pei_transferCache
    if cached and cached.container == container and cached.refresh == pane.refreshContainerCount
        and cached.otherRefresh == (otherPane and otherPane.refreshContainerCount)
        and cached.loadToken == LOAD_TOKEN and cached.proximity == isLootOnProximityTab(page)
        and cached.equipped == EquippedTab.isListing(pane) then
        return cached.specs
    end
    local specs = {}
    -- Both windows are made before either has a container.
    if container and otherPane and otherPane.inventory then
        local object = (not page.onCharacter) and controlsUI:getDisplayedObject() or nil
        for _, spec in ipairs(candidateSpecs(page)) do
            local handler = windowHandler(page, spec.class, object, container)
            if handler:shouldBeVisible() and (not spec.hasItems or spec.hasItems(handler)) then
                table.insert(specs, spec)
            end
        end
    end
    page.pei_transferCache = { container = container, refresh = pane.refreshContainerCount,
                               otherRefresh = otherPane and otherPane.refreshContainerCount,
                               loadToken = LOAD_TOKEN, proximity = isLootOnProximityTab(page),
                               equipped = EquippedTab.isListing(pane), specs = specs }
    return specs
end

-- ------------------------------------------------------------------ --
-- Buttons
-- ------------------------------------------------------------------ --

-- Places the buttons of what the window offers now right to left, ending
-- at `right`, each a size x size square at y; hides the rest (all of them
-- when `right` is nil). Made once per window and handler class. Returns the
-- x of the leftmost button, or nil when none shows.
function TransferButtons.place(page, right, y, size)
    page.pei_transferButtons = page.pei_transferButtons or {}
    -- Buttons are hidden at the end, only those not placed now: hiding all
    -- and showing some again would flip them every frame.
    local placed, left = {}, nil
    if right then
        local specs = visibleSpecs(page)
        local x = right
        for index = #specs, 1, -1 do
            local spec = specs[index]
            local handler = page.pei_handlers[spec.class]
            local key = "pei_transfer_" .. spec.class.Type
            local button = IconButton.ensure(page, key, spec, handler)
            page.pei_transferButtons[key] = button
            button.onmouseover = handler.onMouseOverButton
            button.onmouseoutfunction = handler.onMouseOutButton
            -- The handler lights up items for whoever owns the highlight, and
            -- the pane drops it when that owner is not on screen.
            handler.control = button
            x = x - size
            IconButton.place(button, x, y, size)
            placed[button] = true
            left = x
            x = x - Theme.gap()
        end
    end
    for _, button in pairs(page.pei_transferButtons) do
        if not placed[button] then Bounds.hide(button) end
    end
    return left
end
