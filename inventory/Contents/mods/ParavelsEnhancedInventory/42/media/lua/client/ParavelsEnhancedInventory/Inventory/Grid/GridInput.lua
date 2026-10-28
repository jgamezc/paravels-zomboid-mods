--[[
    Paravel's Enhanced Inventory - mouse input in the grid

    Vanilla's handlers find the hovered row from y / itemHgt, so in the grid
    they are replaced by cell hit-testing (GridLayout.cellAt); the list
    always runs vanilla's.

    Dragging follows vanilla's protocol: the source pane fills ISMouseDrag
    and sets pane.dragging; drop targets (other panes, container tabs,
    hotbar, equipped slots) accept the drop, and ISInventoryPane:update()
    drops on the floor when the mouse is released outside any UI.
]]

require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/Grid/GridState"

local Entries = PEI.Entries
local GridLayout = PEI.GridLayout
local GridSelection = PEI.GridSelection
local GridState = PEI.GridState
local ViewMode = PEI.ViewMode

local GridInput = PEI.GridInput or {}
PEI.GridInput = GridInput

-- Pixels the mouse must move with the button down before a drag starts.
local DRAG_THRESHOLD = 4

-- Only the first local player uses the mouse.
local function isMousePlayer(pane)
    return pane.player == 0
end

local function noModifierKeys()
    return not isShiftKeyDown() and not isCtrlKeyDown()
end

local function modifierKeys()
    return { shift = isShiftKeyDown(), ctrl = isCtrlKeyDown() }
end

local function startDrag(pane, model, cell)
    local things = GridSelection.selectedThings(pane, model)
    if #things == 0 then return end
    pane.dragging = cell.idx or 1
    pane.draggingX = pane:getMouseX()
    pane.draggingY = pane:getMouseY()
    pane.dragStarted = false
    pane.draggedItems:reset()
    ISMouseDrag.dragging = things
    ISMouseDrag.draggingFocus = pane
end

local function endDrag(pane)
    pane.dragging = nil
    pane.dragStarted = false
    pane.draggedItems:reset()
    if ISMouseDrag.draggingFocus == pane then
        ISMouseDrag.dragging = nil
        ISMouseDrag.draggingFocus = nil
    end
    pane.draggingMarquis = false
end

ViewMode.overrideForGrid("onMouseDown", function(vanilla, pane, x, y)
    if not isMousePlayer(pane) then return true end
    getSpecificPlayer(pane.player):nullifyAiming()
    pane.downX = x
    pane.downY = y
    local model, layout = GridState.get(pane)

    local cell = GridLayout.cellUnderMouse(pane, layout)
    pane.pei_clickedKey = nil
    if not cell then
        if noModifierKeys() then GridSelection.clear(model) end
        GridState.publish(pane)
        return true
    end
    pane.pei_collapseOnMouseUp = GridSelection.click(model, layout, cell, modifierKeys())
    GridState.publish(pane)
    pane.pei_clickedKey = cell.key
    startDrag(pane, model, cell)
    return true
end)

ViewMode.overrideForGrid("onMouseUp", function(vanilla, pane, x, y)
    if not isMousePlayer(pane) then return end

    -- Items dropped here from another pane: vanilla's drop logic only
    -- depends on the container, so it is reused. mouseOverOption = 0 skips
    -- its row selection. Nothing stays selected here afterwards.
    local draggingFocus = ISMouseDrag.draggingFocus
    if ISMouseDrag.dragging ~= nil and draggingFocus ~= pane and draggingFocus ~= nil then
        pane.mouseOverOption = 0
        local result = vanilla(pane, x, y)
        GridSelection.clear(GridState.get(pane))
        GridState.publish(pane)
        return result
    end

    -- A plain click on a selected cell keeps the selection for dragging;
    -- without a drag it collapses to that cell.
    local model, layout = GridState.get(pane)
    local clicked = not pane.dragStarted and pane.pei_clickedKey ~= nil and layout.byKey[pane.pei_clickedKey]
    if pane.pei_collapseOnMouseUp and clicked then
        GridSelection.selectOnly(model, clicked)
        GridState.publish(pane)
    end
    -- A plain click on a stack opens or closes it. Done on mouse-up so that
    -- dragging a stack, or Ctrl/Shift selecting it, does not toggle it.
    if clicked and not clicked.sub and Entries.isStack(clicked.entry) and noModifierKeys() then
        GridState.toggleExpanded(pane, clicked.entry)
    end
    pane.pei_collapseOnMouseUp = false
    pane.pei_clickedKey = nil

    -- Also reached as draggingFocus:onMouseUp(0, 0) after another target
    -- accepted our drag: the drag state is cleared either way.
    endDrag(pane)
    return true
end)

ViewMode.overrideForGrid("onMouseMove", function(vanilla, pane, dx, dy)
    if not isMousePlayer(pane) then return end
    -- The per-row "Grab/Drop" buttons only make sense in the list.
    pane.contextButton1:setVisible(false)
    pane.contextButton2:setVisible(false)
    pane.contextButton3:setVisible(false)
    pane.mouseOverOption = 0

    if pane.dragging and not pane.dragStarted then
        local movedX = math.abs(pane:getMouseX() - pane.draggingX)
        local movedY = math.abs(pane:getMouseY() - pane.draggingY)
        if movedX > DRAG_THRESHOLD or movedY > DRAG_THRESHOLD then pane.dragStarted = true end
    end
end)

-- Vanilla's double-click for a single item (the InventoryItem branch of
-- ISInventoryPane:onMouseDoubleClick): take it, or use it if already carried.
local function doubleClickItem(pane, item)
    local playerObj = getSpecificPlayer(pane.player)
    local playerInventory = getPlayerInventory(pane.player).inventory
    if item:getContainer() == playerInventory then
        pane:doContextualDblClick(item)
        return
    end
    if item:isHumanCorpse() and playerObj:getVehicle() then return end
    if isForceDropHeavyItem(item) then
        ISInventoryPaneContextMenu.equipHeavyItem(playerObj, item)
    elseif luautils.walkToContainer(item:getContainer(), pane.player) then
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(playerObj, item,
            item:getContainer(), playerInventory))
    end
end

ViewMode.overrideForGrid("onMouseDoubleClick", function(vanilla, pane, x, y)
    if pane.vscroll and pane:isMouseOverScrollBar() then return vanilla(pane, x, y) end
    local _, layout = GridState.get(pane)
    local cell = GridLayout.cellUnderMouse(pane, layout)
    if not cell then return end
    if cell.sub then
        doubleClickItem(pane, cell.item)
        return
    end
    -- Point vanilla's row index at the cell so its double-click logic
    -- (transfer, equip, wear with Shift...) applies unchanged. x = column2
    -- avoids vanilla's expand/collapse branch.
    pane.mouseOverOption = cell.idx
    pane.previousMouseUp = cell.idx
    return vanilla(pane, pane.column2, y)
end)

ViewMode.overrideForGrid("onRightMouseUp", function(vanilla, pane, x, y)
    if not isMousePlayer(pane) then return end
    local model, layout = GridState.get(pane)

    local cell = GridLayout.cellUnderMouse(pane, layout)
    if cell and not GridSelection.isSelected(model, cell) then
        GridSelection.selectOnly(model, cell)
        GridState.publish(pane)
    end

    local things = GridSelection.selectedThings(pane, model)
    local isInPlayerInventory = pane.inventory:isInCharacterInventory(getSpecificPlayer(pane.player))
    local menuX = pane:getAbsoluteX() + x
    local menuY = pane:getAbsoluteY() + y + pane:getYScroll()

    local menu
    if #things == 0 then
        menu = ISInventoryPaneContextMenu.createMenuNoItems(pane.player, not isInPlayerInventory, menuX, menuY)
    else
        if pane.toolRender then pane.toolRender:setVisible(false) end
        menu = ISInventoryPaneContextMenu.createMenu(pane.player, isInPlayerInventory, things, menuX, menuY)
    end
    if menu and menu.numOptions > 1 and JoypadState.players[pane.player + 1] then
        menu.origin = pane.inventoryPage
        menu.mouseOver = 1
        setJoypadFocus(pane.player, menu)
    end
    return true
end)

-- One grid row per wheel step; vanilla's updateSmoothScrolling() animates it.
ViewMode.overrideForGrid("onMouseWheel", function(vanilla, pane, delta)
    if pane.inventoryPage.isCollapsed then return false end
    if pane.inventoryPage:isCycleContainerKeyDown() then return false end
    local measures = GridLayout.measure(pane)
    if not pane.smoothScrollTargetY then pane.smoothScrollY = pane:getYScroll() end
    local target = (pane.smoothScrollTargetY or pane:getYScroll()) - delta * measures.stepY
    local maxScroll = math.max(0, pane:getScrollHeight() - pane:getScrollAreaHeight())
    pane.smoothScrollTargetY = PUI.clamp(target, -maxScroll, 0)
    return true
end)

-- Vanilla's update() writes pane.selected by list row (Ctrl+A, a stack's
-- header); the grid takes it in right after.
ViewMode.overrideForGrid("update", function(vanilla, pane)
    vanilla(pane)
    GridState.adoptVanillaSelection(pane)
end)
