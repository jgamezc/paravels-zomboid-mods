--[[
    Paravel's Enhanced Inventory - list columns

    The list's geometry, left to right: the stacks' expand arrows (under the
    expand-all button), the icons (under the family sort), the name, the
    category and the weight. The rows end before the scroll bar, which keeps
    a lane of its own, as in the grid.

    Vanilla's drawing, hit-testing and scrolling all read pane.itemHgt,
    pane.column2 and pane.column3, and its header buttons resize themselves,
    so the columns are worked out every frame (ListColumns.compute) from what
    the player chose (the name/category divider, kept in pane.column3, and
    the weight column's width, pane.pei_weightW) and written to the pane and
    its headers in one place (ListColumns.apply). Vanilla's own resizing
    puts the category back at the pane's right edge, hence every frame.
    How far the dividers drag is set again just before the rows are drawn
    (ListColumns.limitDividers): vanilla's prerender sets it for its own
    columns every frame, after the window has been laid out.
]]

require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsUI/Controls/Bounds"
require "ParavelsUI/Controls/ScrollBar"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Theme/Theme"

local Bounds = PUI.Bounds
local ScrollBar = PUI.ScrollBar
local Text = PUI.Text
local Theme = PUI.Theme

local ListColumns = PEI.ListColumns or {}
PEI.ListColumns = ListColumns

-- Width of the weight column until the player drags its divider.
local WEIGHT_WIDTH = 56

-- The game's item sprites' own size: an icon drawn at it is pixel exact.
local SPRITE_SIZE = 32

-- Vanilla's row height for the pane's font and zoom (onInventoryFontChanged).
local function vanillaRowHeight(pane)
    return math.ceil(math.max(18, pane.fontHgt or 18) * (pane.zoom or 1))
end

--[[
    The columns as they are now, a new table:
        rowHeight                vanilla's row, or the icon when taller, plus
                                 the theme's gap
        iconSize                 the icons' size: the sprites' own, which is
                                 what vanilla asks for in a row this tall
        expandWidth              the expand arrows' column, from 0
        iconLeft, iconWidth      the icon column
        nameLeft                 where the name starts (pane.column2)
        categoryLeft             where the category starts (pane.column3)
        weightLeft, weightRight  the weight column
        rowsRight                where the rows end, before the scroll bar
        pad                      the text's margin inside a column
]]
function ListColumns.compute(pane)
    local cols = {}
    local rowHeight = vanillaRowHeight(pane)
    cols.rowHeight = math.max(rowHeight, SPRITE_SIZE) + Theme.gap()
    cols.iconSize = SPRITE_SIZE
    cols.expandWidth = Theme.smallIconSize() + Theme.halfGap()
    cols.iconLeft = cols.expandWidth
    cols.iconWidth = cols.iconSize + Theme.halfGap() * 2
    cols.nameLeft = cols.iconLeft + cols.iconWidth
    cols.pad = Theme.gap()
    cols.rowsRight = pane.width - ScrollBar.WIDTH - Theme.gap()
    cols.weightRight = cols.rowsRight
    -- The weight column is never narrower than its header's text, which is longer in
    -- some languages (a width saved in another language may be too narrow).
    local weightWidth = pane.pei_weightW or WEIGHT_WIDTH
    local weightHeader = pane.pei_weightHeader
    if weightHeader then
        weightWidth = math.max(weightWidth, Text.width(weightHeader.title, weightHeader.font) + cols.pad * 2)
    end
    cols.weightLeft = cols.rowsRight - weightWidth
    -- The name and the category each keep their header's minimum width; the
    -- name wins when there is not room for both.
    local nameMinimum = pane.nameHeader and pane.nameHeader.minimumWidth or 0
    local categoryMinimum = pane.typeHeader and pane.typeHeader.minimumWidth or 0
    cols.categoryLeft = math.max(cols.nameLeft + nameMinimum,
        math.min(pane.column3 or cols.nameLeft, cols.weightLeft - categoryMinimum + 1))
    return cols
end

-- Puts the rows and the headers where `cols` says. The weight header is
-- left alone while the player drags its divider.
function ListColumns.apply(pane, cols)
    if pane.itemHgt ~= cols.rowHeight then pane.itemHgt = cols.rowHeight end
    pane.column2 = cols.nameLeft
    pane.column3 = cols.categoryLeft
    local nameHeader, categoryHeader, weightHeader = pane.nameHeader, pane.typeHeader, pane.pei_weightHeader
    local height = pane.headerHgt
    Bounds.show(nameHeader, cols.nameLeft, 0, cols.categoryLeft - cols.nameLeft, height)
    -- Vanilla's category header starts a pixel before the divider.
    Bounds.show(categoryHeader, cols.categoryLeft - 1, 0, math.max(0, cols.weightLeft - cols.categoryLeft + 1), height)
    if weightHeader then
        weightHeader.minimumWidth = Text.width(weightHeader.title, weightHeader.font) + cols.pad * 2
        weightHeader.maximumWidth = math.max(weightHeader.minimumWidth,
            cols.weightRight - cols.categoryLeft - categoryHeader.minimumWidth)
        if weightHeader.resizing then
            Bounds.setVisible(weightHeader, true)
        else
            Bounds.show(weightHeader, cols.weightLeft, 0, cols.weightRight - cols.weightLeft, height)
        end
    end
end

-- How far vanilla's divider drags may go: the other column keeps its
-- minimum, and both stay clear of the weight column.
function ListColumns.limitDividers(pane, cols)
    local nameHeader, categoryHeader = pane.nameHeader, pane.typeHeader
    nameHeader.maximumWidth = cols.weightLeft - categoryHeader.minimumWidth - cols.nameLeft
    categoryHeader.maximumWidth = cols.weightLeft - nameHeader.minimumWidth - cols.nameLeft + 1
end
