--[[
    Paravel's Enhanced Inventory - list rows

    Vanilla's renderdetails() is kept whole: it decides what each row shows.
    While it runs, the pane's draw calls are swapped (Paravel's UI, Draw/DrawOverrides.lua)
    for ones that recognise vanilla's colours and draw the theme's instead
    (hover, selection, text, lines), so the list matches the window and the
    grid without a copy of its logic. Anything not recognised is drawn as
    vanilla drew it. Each icon gets the grid's family colour, halo and
    shadow, and a weight column is added on the right.

    The swapped calls run hundreds of times a frame, so what they need (the
    columns, the theme, the options) is read once at the start of each pass
    of rows into `frame`.
]]

require "ISUI/ISInventoryItem"
require "ParavelsEnhancedInventory/Inventory/List/ListColumns"
require "ParavelsEnhancedInventory/Inventory/ItemIcon"
require "ParavelsEnhancedInventory/Inventory/Families"
require "ParavelsEnhancedInventory/Inventory/Options"
require "ParavelsEnhancedInventory/Inventory/Upgrade"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsUI/Draw/DrawOverrides"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/Tile"
require "ParavelsUI/Shapes/Line"
require "ParavelsUI/Theme/GameColors"

local Draw = PUI.Draw
local DrawOverrides = PUI.DrawOverrides
local Families = PEI.Families
local GameColors = PUI.GameColors
local ItemIcon = PEI.ItemIcon
local Options = PEI.Options
local Line = PUI.Line
local ListColumns = PEI.ListColumns
local Text = PUI.Text
local Theme = PUI.Theme
local Tile = PUI.Tile
local Upgrade = PEI.Upgrade
local ViewMode = PEI.ViewMode

local ListRows = PEI.ListRows or {}
PEI.ListRows = ListRows

-- Vanilla's tree arrows sit in a 15 px tall box at the row's top.
local VANILLA_ARROW_BOX = 15
-- Vanilla draws the category this far right of its column's left edge.
local VANILLA_CATEGORY_PAD = 8

-- ------------------------------------------------------------------ --
-- What a frame of rows draws with
-- ------------------------------------------------------------------ --

-- The theme and options as the rows use them, made again only when either
-- changes.
local currentStyle = PUI.Look.derived(function()
    return {
        textColor = Theme.textColor(),
        mutedAlpha = Theme.mutedAlpha(),
        dangerColor = Theme.dangerColor(),
        accentColor = Theme.accentColor(),
        borderColor = Theme.borderColor(),
        borderAlpha = Theme.borderAlpha(),
        borderWidth = Theme.borderWidth(),
        selectedAlpha = Theme.selectedAlpha(),
        hoverAlpha = Theme.hoverAlpha(),
        stripeAlpha = Theme.stripeAlpha(),
        nestedAlpha = Theme.nestedAlpha(),
        -- A row's wash is rounded half as much as the tabs.
        rowRadius = math.floor(Theme.smallRadius() / 2),
        arrowSize = Theme.smallIconSize(),
        showFamilyTint = Options.get("showBackground"),
        showUpgradeMark = Options.get("showUpgradeMark"),
        showVolumeMark = Options.get("showVolumeMark"),
        -- How far the family colour reaches past the icon.
        familyPad = Theme.borderWidth(),
        familyAlpha = Theme.fillAlpha(),
    }
end)

-- While renderdetails() runs: { cols = ListColumns.compute, style =
-- currentStyle(), dx, dy, upgrades = Upgrade.newReference }; nil otherwise. The swapped calls only run
-- inside it. dx, dy: how far the pass draws its rows from their place, the
-- mouse's offset for the rows being dragged (0 for the others). The
-- columns are where a row's draws are before that offset.
local frame = nil

-- ------------------------------------------------------------------ --
-- Draw overrides, by what vanilla's renderdetails() draws
-- ------------------------------------------------------------------ --

local function fillRow(pane, x, y, w, h, alpha)
    if alpha <= 0 then return end
    Draw.roundedRect(pane, x, y, w, h, frame.style.rowRadius, frame.style.textColor, alpha)
end

local function isWhite(r, g, b) return r == 1 and g == 1 and b == 1 end
local function isBlack(r, g, b) return r == 0 and g == 0 and b == 0 end

-- Vanilla's row colours and what each one is.
local function drawRect(pane, x, y, w, h, a, r, g, b)
    -- Rows, highlights and bars all stop at the scroll bar's lane.
    w = math.min(w, frame.cols.rowsRight - (x - frame.dx))
    if w <= 0 then return end
    local current = frame.style
    if isWhite(r, g, b) then
        if h == 1 and a == 0.2 then
            -- The divider above the equipped items.
            return Line.draw(pane, x, y, w, current.borderWidth)
        elseif a == 0.2 then
            -- Selected, or highlighted by another window.
            return fillRow(pane, x, y, w, h, current.selectedAlpha)
        elseif a == 0.05 then
            return fillRow(pane, x, y, w, h, current.hoverAlpha)
        elseif a == 0.02 then
            -- Every other row; the rows in between are dark (below).
            return fillRow(pane, x, y, w, h, current.stripeAlpha)
        end
    elseif isBlack(r, g, b) then
        -- The items of an open stack, and the rows in between.
        if a == 0.4 then return fillRow(pane, x, y, w, h, current.nestedAlpha) end
        if a == 0.2 then return end
    end
    return ISUIElement.drawRect(pane, x, y, w, h, a, r, g, b)
end

-- Vanilla darkens the icon column and draws the column header black over
-- the rows scrolled under it. Both stay the window's own background: the
-- rows are clipped under the header instead (below), so none show through.
local function drawRectStatic(pane, x, y, w, h, a, r, g, b)
    if x == 0 and y == 0 and w == pane.column2 and h == pane.height then return end
    if y == 0 and h == pane.headerHgt and isBlack(r, g, b) then return end
    return ISUIElement.drawRectStatic(pane, x, y, w, h, a, r, g, b)
end

-- Each row's name sets its own clip and then restores the pane's over the
-- row; both are kept below the header.
local function clipBelowHeader(pane, x, y, w, h)
    local top = pane.headerHgt
    if y < top then
        h = h - (top - y)
        y = top
    end
    return x, y, w, math.max(0, h)
end

local function setStencilRect(pane, x, y, w, h)
    return ISUIElement.setStencilRect(pane, clipBelowHeader(pane, x, y, w, h))
end

local function repaintStencilRect(pane, x, y, w, h)
    return ISUIElement.repaintStencilRect(pane, clipBelowHeader(pane, x, y, w, h))
end

-- `text` drawn at x: one in the category column (the category, or a
-- transfer's name) is cut to end before the weight column; nil when no room
-- is left.
local function fitInColumn(text, x, font)
    local cols = frame.cols
    local columnX = x - frame.dx
    if columnX < cols.categoryLeft then return text end
    local room = cols.weightLeft - cols.pad - columnX
    if room <= 0 then return nil end
    return Text.fit(text, room, font)
end

local function drawMutedText(pane, text, x, y, font)
    local current = frame.style
    local color = current.textColor
    ISUIElement.drawText(pane, text, x, y, color.r, color.g, color.b, current.mutedAlpha, font)
end

-- Item names are vanilla's grey (0.7), unwanted items a darker one; the
-- category and the details (condition, uses left...) are a pale blue. They
-- become the theme's text, at full strength for names and muted for the
-- rest. Vanilla's dark red (an item that does not fit where it is dragged,
-- a transfer's name) becomes the theme's danger colour.
local function drawText(pane, text, x, y, r, g, b, a, font)
    local current = frame.style
    text = fitInColumn(text, x, font)
    if not text then return end
    local color = current.textColor
    if r == g and g == b then
        local alpha = r >= 0.7 and a or a * current.mutedAlpha
        return ISUIElement.drawText(pane, text, x, y, color.r, color.g, color.b, alpha, font)
    elseif r == 0.6 and g == 0.6 and b == 0.8 then
        return drawMutedText(pane, text, x, y, font)
    elseif r == 0.7 and g == 0 and b == 0 then
        local danger = current.dangerColor
        return ISUIElement.drawText(pane, text, x, y, danger.r, danger.g, danger.b, a, font)
    end
    return ISUIElement.drawText(pane, text, x, y, r, g, b, a, font)
end

-- The open and closed stack arrows become Lucide chevrons, centred in the
-- expand column, under the expand-all button.
local function drawTextureScaled(pane, texture, x, y, w, h, a, r, g, b)
    if texture == pane.treeexpicon or texture == pane.treecolicon then
        local current = frame.style
        local size = current.arrowSize
        local icon = texture == pane.treeexpicon and "chevron-down" or "chevron-right"
        Draw.icon(pane, icon, math.floor((frame.cols.expandWidth - size) / 2),
            math.floor(y + VANILLA_ARROW_BOX / 2 - size / 2), size, current.textColor, current.mutedAlpha)
        return
    end
    return ISUIElement.drawTextureScaled(pane, texture, x, y, w, h, a, r, g, b)
end

-- The selection box drawn while dragging over empty space.
local function drawRectBorder(pane, x, y, w, h, a, r, g, b)
    local color = frame.style.borderColor
    return ISUIElement.drawRectBorder(pane, x, y, w, h, 1, color.r, color.g, color.b)
end

local ROW_DRAW_OVERRIDES = {
    drawRect = drawRect,
    drawRectStatic = drawRectStatic,
    drawText = drawText,
    drawTextureScaled = drawTextureScaled,
    drawRectBorder = drawRectBorder,
    setStencilRect = setStencilRect,
    repaintStencilRect = repaintStencilRect,
}

-- ------------------------------------------------------------------ --
-- Icons
-- ------------------------------------------------------------------ --

-- Each icon sits on a small rounded square of its family's colour, the grid
-- cell's background in miniature.
local function drawFamilyTint(pane, item, x, y, size, alpha)
    local current = frame.style
    if not current.showFamilyTint then return end
    local pad = current.familyPad
    Tile.fill(pane, x - pad, y - pad, size + pad * 2, size + pad * 2, Families.tintOf(Families.classify(item)),
        current.familyAlpha * alpha)
end

-- A stand-in for ISInventoryItem.renderItemIcon while this pane's rows are
-- drawn: every icon, a stack's and its items', centred in the icon column
-- (vanilla shifts the items' icons right of the stack's), over its tint,
-- halo and shadow, and under the upgrade mark (or a skill book's volume) at
-- its top right corner.
-- `offsetX` is how far dragged rows are shifted.
local function themedIconRenderer(pane, renderIcon, offsetX)
    local cols = frame.cols
    return function(target, item, x, y, alpha, w, h)
        if target ~= pane or not (w and h) then return renderIcon(target, item, x, y, alpha, w, h) end
        alpha = alpha or 1
        -- At the size and height vanilla gives it.
        local iconX = math.floor(cols.iconLeft + (cols.iconWidth - w) / 2 + offsetX)
        drawFamilyTint(pane, item, iconX, y, w, alpha)
        ItemIcon.drawLayers(pane, item, iconX, y, w, alpha)
        renderIcon(target, item, iconX, y, alpha, w, h)
        ItemIcon.drawCornerMark(pane, frame.style, frame.upgrades, item, iconX + w, y, alpha)
    end
end

-- ------------------------------------------------------------------ --
-- Weight column
-- ------------------------------------------------------------------ --

-- Every weight with one decimal (0.5, 1.0, 12.3), so the figures line up.
local function formatWeight(weight)
    return string.format("%.1f", weight)
end

local function isDraggingRows(pane)
    return pane.dragging ~= nil and pane.dragStarted
end

-- Whether a row is drawn in the pass that draws the rows being dragged
-- (doDragged) or in the one that draws the rest, those in sight.
local function isDrawnInPass(doDragged, isDragged, inSight)
    if doDragged then return isDragged end
    return inSight and not isDragged
end

-- Each row's weight, left-aligned just after the column's divider (so it
-- follows it when dragged), in the muted text of the category: a stack's
-- row shows the whole stack, as vanilla sorts it, and the rows of an open
-- stack each item's own. The rows follow pane.items, which renderdetails()
-- has drawn, one per row. Each pass draws the rows vanilla's does: the
-- rows in sight except those being dragged, or only those.
local function drawWeights(pane, doDragged)
    local x = frame.cols.weightLeft + frame.cols.pad + frame.dx
    local font = pane.font or UIFont.Small
    local rowHeight, scroll, height = pane.itemHgt, pane:getYScroll(), pane:getHeight()
    local textOffsetY = (rowHeight - (pane.fontHgt or getTextManager():getFontHeight(font))) / 2
    local dragging = isDraggingRows(pane)
    for index, row in ipairs(pane.items) do
        local isDragged = dragging and pane.selected[index] ~= nil
        local top = (index - 1) * rowHeight + scroll
        local inSight = top + rowHeight >= 0 and top <= height
        if isDrawnInPass(doDragged, isDragged, inSight) then
            local weight
            if type(row) == "table" then weight = row.weight else weight = row:getUnequippedWeight() end
            if weight then
                local y = (index - 1) * rowHeight + pane.headerHgt + textOffsetY + frame.dy
                drawMutedText(pane, formatWeight(weight), x, y, font)
            end
        end
    end
end

-- Vanilla leaves the category out of the stacks' rows being dragged (an
-- item's row shows its details instead); they keep it here, as vanilla
-- draws it (a transfer's name in its place), in the category's muted text.
local function drawDraggedCategories(pane)
    local font = pane.font or UIFont.Small
    local rowHeight = pane.itemHgt
    local textOffsetY = (rowHeight - (pane.fontHgt or getTextManager():getFontHeight(font))) / 2
    local x = frame.cols.categoryLeft + VANILLA_CATEGORY_PAD + frame.dx
    for index, row in ipairs(pane.items) do
        if pane.selected[index] ~= nil and type(row) == "table" then
            local item = row.items[1]
            if item:getJobDelta() <= 0 then
                local category = item:getDisplayCategory() or item:getCategory()
                local y = (index - 1) * rowHeight + pane.headerHgt + textOffsetY + frame.dy
                local text = fitInColumn(getText("IGUI_ItemCat_" .. category), x, font)
                if text then drawMutedText(pane, text, x, y, font) end
            end
        end
    end
end

-- The rows being dragged, besides what vanilla draws of them: their
-- category and weight, outside the pane's clip as vanilla draws them.
local function drawDraggedColumns(pane)
    if not isDraggingRows(pane) then return end
    pane:suspendStencil()
    drawDraggedCategories(pane)
    drawWeights(pane, true)
    pane:resumeStencil()
end

-- The line under the header, where the rows are cut.
local function drawHeaderLine(pane)
    local current = frame.style
    local thickness, alpha = current.borderWidth, current.borderAlpha
    if thickness > 0 and alpha > 0 then
        local color = current.borderColor
        pane:drawRectStatic(0, pane.headerHgt - thickness, frame.cols.rowsRight, thickness,
            alpha, color.r, color.g, color.b)
    end
end

-- ------------------------------------------------------------------ --
-- Pane overrides
-- ------------------------------------------------------------------ --

-- The rows (doDragged false, from prerender) or the rows being dragged
-- (true, from render), in the columns the window's layout placed.
local function renderRows(vanilla, pane, doDragged)
    -- Rows being dragged are drawn shifted by the mouse; vanilla's offset.
    local dx, dy = 0, 0
    if doDragged and pane.draggingX then
        dx, dy = pane:getMouseX() - pane.draggingX, pane:getMouseY() - pane.draggingY
    end
    frame = { style = currentStyle(), cols = ListColumns.compute(pane), dx = dx, dy = dy,
              upgrades = Upgrade.newReference(pane.player) }
    if not doDragged then ListColumns.limitDividers(pane, frame.cols) end

    local iconRenderer = { renderItemIcon = themedIconRenderer(pane, ISInventoryItem.renderItemIcon, dx) }
    -- Inside the pane's own clip (set by prerender), as vanilla nests the
    -- rows' clips: the rows end at the header. The clip is in the pane's
    -- unscrolled space, so it stays put while the rows scroll under it.
    -- It is lifted even when the rows fail, hence the pcall.
    local clipped = not doDragged
    if clipped then pane:setStencilRect(clipBelowHeader(pane, 0, 0, pane.width - 1, pane.height - 1)) end
    local ok, err = pcall(PUI.withFields, ISInventoryItem, iconRenderer,
        DrawOverrides.run, pane, ROW_DRAW_OVERRIDES, vanilla, doDragged)
    if ok and doDragged then drawDraggedColumns(pane) end
    if clipped then
        if ok then drawWeights(pane, false) end
        pane:clearStencilRect()
        pane:repaintStencilRect(0, 0, pane.width - 1, pane.height - 1)
        drawHeaderLine(pane)
    end
    frame = nil
    if not ok then error(err, 0) end
end

ViewMode.overrideForList("renderdetails", renderRows)

-- Vanilla's detail bars (condition, uses left, cooking...): a thin track in
-- the theme's line colour and a fill in its accent, or its danger colour
-- when vanilla uses its bad colour (burning). Drawn by renderdetails().
ViewMode.overrideForList("drawProgressBar", function(vanilla, pane, x, y, w, h, fraction, fg)
    if not frame then return vanilla(pane, x, y, w, h, fraction, fg) end
    local cols, current = frame.cols, frame.style
    -- It ends before the weight column.
    w = math.min(w, cols.weightLeft - cols.pad - (x - frame.dx))
    if w <= 0 then return end
    fraction = PUI.clamp(fraction, 0, 1)
    local barHeight = math.max(1, h - 2)
    Draw.rect(pane, x, y, w, barHeight, current.borderColor, current.borderAlpha)
    local isBad = GameColors.isBad(fg.r, fg.g, fg.b)
    local filled = math.floor(w * fraction)
    if fraction > 0 then filled = math.max(filled, 1) end
    if filled > 0 then Draw.rect(pane, x, y, filled, barHeight, isBad and current.dangerColor or current.accentColor, 1) end
end)
