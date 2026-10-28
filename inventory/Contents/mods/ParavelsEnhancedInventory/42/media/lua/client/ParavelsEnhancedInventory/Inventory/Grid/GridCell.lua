--[[
    Paravel's Enhanced Inventory - drawing one grid cell

    A cell is drawn back to front: family background, transfer progress,
    selection or hover; halo, shadow; icon and marks as the list draws them
    (Grid/GridRowContent.lua); top indicator, wear bar, upgrade mark; stack
    count; outline. Everything that tints the cell sits
    under the icon, every mark over it, and the outline closes the cell over
    all of it.

    - Background: the item's family colour (Inventory/Families.lua), one
      opacity for every family so none reads stronger.
    - Top indicator: a band of that colour along the top edge, following the
      tile's corners, for items that stand out in their family: the theme's
      accent of that colour (Theme.accentOf, Theme.accentAlpha).
    - Wear bar: in the text colour, as long as the icon is wide, floating
      near the bottom edge, once an item is worn. Stacks never show it: it would speak for one item out of
      many.
    - Upgrade mark: top right, under the top indicator's band, for gear
      better than what the player has on (Inventory/Upgrade.lua). A skill
      book's volume takes the same corner (no item is both).

    A cell is a tile (Paravel's UI, Shapes/Tile.lua) and every colour, opacity and line comes
    from the theme; the player's options only say what is shown and how big
    the icon and its cell are.
]]

require "ParavelsEnhancedInventory/Inventory/Entries"
require "ParavelsEnhancedInventory/Inventory/ItemIcon"
require "ParavelsEnhancedInventory/Inventory/Families"
require "ParavelsEnhancedInventory/Inventory/Grid/GridRowContent"
require "ParavelsEnhancedInventory/Inventory/Options"
require "ParavelsUI/Theme/Theme"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/Tile"
require "ParavelsUI/Shapes/ProgressBar"

local Draw = PUI.Draw
local Entries = PEI.Entries
local Families = PEI.Families
local GridRowContent = PEI.GridRowContent
local ItemIcon = PEI.ItemIcon
local Options = PEI.Options
local ProgressBar = PUI.ProgressBar
local Text = PUI.Text
local Theme = PUI.Theme
local Tile = PUI.Tile

local GridCell = PEI.GridCell or {}
PEI.GridCell = GridCell

-- How a cell is drawn: in place, dimmed in place while its items are being
-- dragged, or as the copy under the mouse during a drag.
GridCell.NORMAL = "normal"
GridCell.DRAG_SOURCE = "dragSource"
GridCell.DRAG_GHOST = "ghost"
local DRAG_SOURCE_FADE = 0.3

local WEAR_BAR_BOTTOM_MARGIN = 5
-- Marks never sit closer than this to the cell's edge, even in a square tile.
local MIN_INSET = 3

local COUNT_FONTS = { "Small", "Medium", "Large" }

-- ------------------------------------------------------------------ --
-- What a cell draws, read once
-- ------------------------------------------------------------------ --

-- The player's options and the theme as the cells use them, made again only
-- when either changes: a grid draws hundreds of cells a frame.
local currentStyle = PUI.Look.derived(function()
    local countFont = UIFont[COUNT_FONTS[Options.get("stackFont")]]
    local countBold = Options.get("stackBold")
    return {
        textColor = Theme.textColor(),
        selectedAlpha = Theme.selectedAlpha(),
        hoveredAlpha = Theme.hoverAlpha(),
        stateAlpha = Theme.stateAlpha(),
        successColor = Theme.successColor(),
        dangerColor = Theme.dangerColor(),
        shadowColor = Theme.shadowColor(),
        shadowAlpha = Theme.shadowAlpha(),
        borderWidth = Theme.borderWidth(),
        showBackground = Options.get("showBackground"),
        backgroundAlpha = Theme.fillAlpha(),
        showTopIndicator = Options.get("showTopIndicator"),
        topThickness = Theme.barThickness(),
        topAlpha = Theme.accentAlpha(),
        -- The band's colour for each family tint, made as cells are drawn.
        topColors = {},
        showWearBar = Options.get("showDurabilityBar"),
        wearThickness = Theme.barThickness(),
        countFont = countFont,
        countFontHeight = getTextManager():getFontHeight(countFont),
        countBold = countBold,
        countOutline = ItemIcon.outlineOffsets(countBold),
        showUpgradeMark = Options.get("showUpgradeMark"),
        showVolumeMark = Options.get("showVolumeMark"),
    }
end)

--[[
    What every cell of one drawing pass shares, made once per pass:
        measures     the grid's (GridLayout.measure)
        style        the theme and options as cells use them
        isBusy       GridCell.isPlayerBusy, asked once for the pass
        rowIconSize  the row icon's size GridRowContent.collect measured from
        upgrades     Upgrade.newReference of the pane's player
]]
function GridCell.newFrame(measures, isBusy, rowIconSize, upgrades)
    return { measures = measures, style = currentStyle(), isBusy = isBusy, rowIconSize = rowIconSize,
             upgrades = upgrades }
end

-- The item a cell shows and how many it stands for.
local function shownItem(cell)
    if cell.sub then return cell.item, 1 end
    return Entries.headerItem(cell.entry), Entries.itemCount(cell.entry)
end

-- 0..1 condition left, for a single worn item; nil otherwise.
local function wearOf(item, count)
    if count ~= 1 or not Entries.isWorn(item) then return nil end
    return math.max(0, item:getCondition() / item:getConditionMax())
end

-- Progress (0..1) of a transfer in flight for this cell.
-- ISInventoryTransferAction writes it on the item being moved. Vanilla's
-- collapsed row only reads the header item, but a stack here may be moving
-- any of its items, so take the most advanced.
local function transferProgress(cell)
    if cell.sub then return cell.item:getJobDelta() end
    local items, progress = cell.entry.items, 0
    for i = Entries.FIRST_ITEM, #items do
        progress = math.max(progress, items[i]:getJobDelta())
    end
    return progress
end

-- Whether any item of the pane can be in a transfer: the player has timed
-- actions queued (every action that moves an item resets its progress when
-- it ends). Asked once a frame, so an idle grid reads no item's progress.
function GridCell.isPlayerBusy(pane)
    local queue = ISTimedActionQueue and ISTimedActionQueue.queues[getSpecificPlayer(pane.player)]
    return queue ~= nil and #queue.queue > 0
end

-- The top indicator's colour for a tint. A tint is the theme's own table
-- until the theme changes, which also makes a new style.
local function topColorOf(style, tint)
    local color = style.topColors[tint]
    if not color then
        color = Theme.accentOf(tint)
        style.topColors[tint] = color
    end
    return color
end

-- How far marks keep from the cell's edges: clear of the tile's corner.
local function cornerInset(measures)
    return math.max(MIN_INSET, Tile.radius(measures.cellW))
end

local function drawWearBar(element, style, wear, x, y, w, h, length, fade)
    local thickness = style.wearThickness
    local barX, barY = x + math.floor((w - length) / 2), y + h - WEAR_BAR_BOTTOM_MARGIN - thickness
    -- The track is the shadow colour at the theme's track opacity, so over
    -- any cell it reads as a shade of that cell's own background.
    ProgressBar.draw(element, barX, barY, length, wear, style.textColor, thickness, style.shadowColor, fade)
end

-- Bottom right, inset to clear the tile's corner; the left side is where
-- mods put their marks on the list. The theme's outline or shadow keeps it
-- readable: the count sits on top of the icon, which can be any colour.
local function drawStackCount(element, style, text, x, y, w, h, inset, fade)
    local font, color = style.countFont, style.textColor
    local textWidth = Text.width(text, font) + (style.countBold and 1 or 0)
    local textX = x + w - textWidth - math.floor(inset * 0.6) - 1
    local textY = y + h - style.countFontHeight - math.floor(inset / 4)
    if style.countOutline then
        for _, offset in ipairs(style.countOutline) do
            Draw.text(element, text, textX + offset[1], textY + offset[2], style.shadowColor,
                style.shadowAlpha * fade, font)
        end
    end
    if style.countBold then Draw.text(element, text, textX + 1, textY, color, fade, font) end
    Draw.text(element, text, textX, textY, color, fade, font)
end

-- The mark of the top right corner: the upgrade mark for gear better than
-- the player's, or a skill book's volume. Like the game's marks
-- (Grid/GridRowContent.lua) it sits against the cell's corner, not against the
-- icon: just inside the outline on the right, and below the top indicator's
-- band by the margin the stack count keeps from the bottom edge, so the two
-- are symmetric.
local function drawCornerMark(element, frame, item, x, y, w, bandHeight, fade)
    local style = frame.style
    local top = y + bandHeight + math.max(2 * style.borderWidth, math.floor(cornerInset(frame.measures) / 4))
    local right = x + w - style.borderWidth
    ItemIcon.drawCornerMark(element, style, frame.upgrades, item, right, top, fade)
end

-- The fills under the icon: the family's colour, a transfer's progress,
-- then the cell's own state (blocked, selected or hovered).
local function drawFills(element, style, state, tint, progress, x, y, w, h, fade)
    if style.showBackground then
        Tile.fill(element, x, y, w, h, tint, style.backgroundAlpha * fade)
    end
    if progress > 0 then
        local filled = math.max(1, math.floor(h * math.min(progress, 1)))
        Tile.band(element, x, y, w, h, h - filled, h, style.successColor, style.stateAlpha)
    end
    if state.isBlocked then
        Tile.fill(element, x, y, w, h, style.dangerColor, style.stateAlpha)
    elseif state.isSelected then
        Tile.fill(element, x, y, w, h, style.textColor, style.selectedAlpha)
    elseif state.isHovered then
        Tile.fill(element, x, y, w, h, style.textColor, style.hoveredAlpha)
    end
end

--[[
    Draws `cell` at x, y. `frame` is GridCell.newFrame's, for the whole pass;
    `state` says how this cell is drawn:
        look        GridCell.NORMAL, DRAG_SOURCE or DRAG_GHOST
        isSelected, isHovered
        isBlocked   none of its items can be dropped where the mouse is
                    (drag ghost only)
        content     what GridRowContent.collect gave for the cell
    The caller reuses `state` for the next cell, so it must not be kept.
]]
function GridCell.draw(pane, cell, x, y, frame, state)
    local style, measures = frame.style, frame.measures
    local fade = state.look == GridCell.DRAG_SOURCE and DRAG_SOURCE_FADE or 1
    local w, h = measures.cellW, measures.cellH
    local item, count = shownItem(cell)
    local family, hasTopIndicator = Families.classify(item)
    local tint = Families.tintOf(family)
    -- The progress belongs to the cell in its container, not to the ghost.
    local progress = 0
    if frame.isBusy and state.look ~= GridCell.DRAG_GHOST then progress = transferProgress(cell) end

    drawFills(pane, style, state, tint, progress, x, y, w, h, fade)

    -- The icon is centred in the whole cell.
    local iconSize = measures.iconSize
    local iconX = x + math.floor((w - iconSize) / 2)
    local iconY = y + math.floor((h - iconSize) / 2)
    ItemIcon.drawLayers(pane, item, iconX, iconY, iconSize, fade)
    -- Without the list's drawing (it failed), the icon alone.
    if not GridRowContent.draw(pane, state.content, frame.rowIconSize, x, y, w, h, iconX, iconY, iconSize, fade,
            measures.markOverhang) then
        ItemIcon.drawIcon(pane, item, iconX, iconY, iconSize, fade)
    end

    -- The outline covers the top rows, hence the extra ones.
    local bandHeight = 0
    if hasTopIndicator and style.showTopIndicator then
        bandHeight = style.topThickness + style.borderWidth
        -- Cut from the whole tile and drawn under the outline, so its curve
        -- meets the outline with no gap and the border stays one unbroken
        -- line.
        Tile.band(pane, x, y, w, h, 0, bandHeight, topColorOf(style, tint), style.topAlpha * fade)
    end
    local wear = wearOf(item, count)
    if wear and style.showWearBar then
        drawWearBar(pane, style, wear, x, y, w, h, iconSize, fade)
    end

    drawCornerMark(pane, frame, item, x, y, w, bandHeight, fade)

    if count > 1 then drawStackCount(pane, style, tostring(count), x, y, w, h, cornerInset(measures), fade) end

    Tile.outline(pane, x, y, w, h, fade)
end
