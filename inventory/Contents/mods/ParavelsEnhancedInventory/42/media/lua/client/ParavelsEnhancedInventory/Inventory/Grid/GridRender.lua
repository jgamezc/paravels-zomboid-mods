--[[
    Paravel's Enhanced Inventory - drawing the grid

    Vanilla calls rendericons() twice per frame in "icons" mode: from
    prerender() for the pane's content and from render() as its drag pass.
    The first draws the grid, the second the cells being dragged.
]]

require "ParavelsEnhancedInventory/Inventory/Upgrade"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsEnhancedInventory/Inventory/Grid/GridCell"
require "ParavelsEnhancedInventory/Inventory/Grid/GridRowContent"

local Draw = PUI.Draw
local Entries = PEI.Entries
local GridLayout = PEI.GridLayout
local GridSelection = PEI.GridSelection
local GridState = PEI.GridState
local GridCell = PEI.GridCell
local GridRowContent = PEI.GridRowContent
local Theme = PUI.Theme
local Upgrade = PEI.Upgrade
local ViewMode = PEI.ViewMode

local GridRender = PEI.GridRender or {}
PEI.GridRender = GridRender

local function isDraggingFrom(pane)
    return pane.dragging and pane.dragStarted and ISMouseDrag.draggingFocus == pane
end

-- True when none of the cell's items can be dropped where the mouse is.
local function cannotDrop(pane, cell)
    local dragged = pane.draggedItems
    if cell.sub then return dragged:cannotDropItem(cell.item) end
    for i = Entries.FIRST_ITEM, #cell.entry.items do
        if not dragged:cannotDropItem(cell.entry.items[i]) then return false end
    end
    return true
end

local function hoveredCell(pane, layout)
    local menu = getPlayerContextMenu(pane.player)
    if pane:isMouseOver() and not (menu and menu:isAnyVisible()) then
        return GridLayout.cellUnderMouse(pane, layout)
    end
    return nil
end

-- An open stack and its inline items share a backdrop (the theme's nested
-- wash), which also fills the gap between neighbours, so the group reads as
-- one run.
local function drawOpenStackBackdrops(pane, model, measures, cells)
    local color, alpha = Theme.textColor(), Theme.nestedAlpha()
    if PUI.isEmpty(model.expanded) or alpha <= 0 then return end
    for _, cell in ipairs(cells) do
        if cell.sub or model.expanded[cell.entry.name] then
            Draw.rect(pane, cell.x - 1, cell.y - 1, measures.stepX, measures.cellH + 2, color, alpha)
        end
    end
end

-- The cells of the rows between top and bottom. Cells fill the grid's
-- slots in on-screen order, `columns` to a row, so the walk starts at the
-- first cell of the first row that reaches the top and stops past the
-- bottom.
local function cellsInSight(layout, top, bottom)
    local measures, cells = layout.measures, layout.cells
    local firstRow = math.max(0, math.ceil((top - measures.inset - measures.cellH) / measures.stepY))
    local visible = {}
    for index = firstRow * measures.columns + 1, #cells do
        local cell = cells[index]
        if cell.y > bottom then break end
        if cell.y + measures.cellH >= top then visible[#visible + 1] = cell end
    end
    return visible
end

-- Only the rows in sight are drawn.
function GridRender.drawGrid(pane)
    GridState.refreshIfStale(pane)
    local model, layout = GridState.get(pane)
    local measures = layout.measures
    local hovered = hoveredCell(pane, layout)
    local dragging = isDraggingFrom(pane)
    local isBusy = GridCell.isPlayerBusy(pane)
    local top = -pane:getYScroll()
    local visible = cellsInSight(layout, top, top + pane.height)
    local contents = GridRowContent.collect(pane, visible)

    drawOpenStackBackdrops(pane, model, measures, visible)
    local frame = GridCell.newFrame(measures, isBusy, contents.iconSize, Upgrade.newReference(pane.player))
    -- One state for every cell, filled in for each: hundreds a frame.
    local state = { isBlocked = false }
    for i, cell in ipairs(visible) do
        local isSelected = GridSelection.isSelected(model, cell)
        state.isSelected = isSelected
        state.isHovered = cell == hovered
        state.look = (dragging and isSelected) and GridCell.DRAG_SOURCE or GridCell.NORMAL
        state.content = contents[i]
        GridCell.draw(pane, cell, cell.x, cell.y, frame, state)
    end

    pane:setScrollHeight(layout.contentHeight)
    pane:setScrollWidth(0)
end

-- Selected cells follow the mouse while dragging, keeping their layout, as
-- the list does with its rows. Red cells cannot be dropped there.
function GridRender.drawDragGhost(pane)
    if not isDraggingFrom(pane) then return end
    pane.draggedItems:update()
    local model, layout = GridState.get(pane)
    local dx = pane:getMouseX() - pane.draggingX
    local dy = pane:getMouseY() - pane.draggingY
    local selected = {}
    for _, cell in ipairs(layout.cells) do
        if GridSelection.isSelected(model, cell) then selected[#selected + 1] = cell end
    end
    local contents = GridRowContent.collect(pane, selected)
    local frame = GridCell.newFrame(layout.measures, false, contents.iconSize, Upgrade.newReference(pane.player))
    local state = { look = GridCell.DRAG_GHOST, isSelected = true, isHovered = false }
    pane:suspendStencil()
    for i, cell in ipairs(selected) do
        state.isBlocked = cannotDrop(pane, cell)
        state.content = contents[i]
        GridCell.draw(pane, cell, cell.x + dx, cell.y + dy, frame, state)
    end
    pane:resumeStencil()
end

-- ------------------------------------------------------------------ --
-- Pane overrides
-- ------------------------------------------------------------------ --

-- Marks the content pass for rendericons().
local IN_PRERENDER = { pei_inPrerender = true }

ViewMode.overrideForGrid("prerender", function(vanilla, pane)
    PUI.withFields(pane, IN_PRERENDER, vanilla, pane)
end)

ViewMode.overrideForGrid("rendericons", function(vanilla, pane)
    if pane.pei_inPrerender then
        GridRender.drawGrid(pane)
    else
        GridRender.drawDragGhost(pane)
    end
end)

-- Vanilla takes the list's column header off the visible height, so the
-- furthest scroll went that much past the last row; the grid has no header.
ViewMode.overrideForGrid("getScrollAreaHeight", function(vanilla, pane)
    return pane:getHeight()
end)
