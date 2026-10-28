--[[
    Paravel's Enhanced Inventory - list column header

    The name, category and weight headers are their titles in the theme's
    muted text, lit on hover, with a line between them; each sorts by its
    column, and the dividers between them can be dragged. The expand buttons
    and the family sort (in place of vanilla's sort menu, which is hidden)
    are Lucide icons. Where the headers go is List/ListColumns.lua's; this
    file makes them, restyles them and says which are shown, in one pass
    (ListHeader.layout) whenever the window is laid out.
]]

require "ParavelsEnhancedInventory/Inventory/List/ListColumns"
require "ParavelsEnhancedInventory/Inventory/Sorting"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsUI/Controls/IconButton"
require "ParavelsUI/Draw/DrawOverrides"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/Line"
require "ParavelsUI/Controls/Bounds"

local Bounds = PUI.Bounds
local Draw = PUI.Draw
local DrawOverrides = PUI.DrawOverrides
local IconButton = PUI.IconButton
local Line = PUI.Line
local ListColumns = PEI.ListColumns
local Sorting = PEI.Sorting
local Text = PUI.Text
local Theme = PUI.Theme
local ViewMode = PEI.ViewMode

local ListHeader = PEI.ListHeader or {}
PEI.ListHeader = ListHeader

-- ------------------------------------------------------------------ --
-- Column titles and dividers
-- ------------------------------------------------------------------ --

-- A divider between two columns is lit while it is hovered or dragged. Each
-- divider is the left edge of the column after it; the one between the name
-- and the category can also be grabbed by the name's right edge.
local function isDividerActive(pane, header)
    if header.resizing or header.mouseOverResize then return true end
    local nameHeader = pane.nameHeader
    return header == pane.typeHeader and nameHeader and (nameHeader.resizing or nameHeader.mouseOverResize) or false
end

local function renderColumnTitle(header)
    local font = header.font or UIFont.Small
    local pad = Theme.gap()
    local title = Text.fit(header.title or "", header:getWidth() - pad * 2, font)
    local textHeight = getTextManager():getFontHeight(font)
    Draw.text(header, title, pad, math.floor((header:getHeight() - textHeight) / 2), Theme.textColor(),
        Theme.interactiveAlpha(header:isMouseOver()), font)
    -- The line on the left edge divides it from the column before.
    if header ~= header.parent.nameHeader then
        local thickness = Theme.borderWidth()
        if isDividerActive(header.parent, header) then
            Draw.rect(header, 0, 0, math.max(1, thickness), header:getHeight(), Theme.textColor(), 1)
        else
            Line.draw(header, 0, 2, thickness, header:getHeight() - 4)
        end
    end
end

-- What a dragged divider changes: only what the player chose, the divider
-- between the name and the category (pane.column3) or the weight column's
-- width; ListColumns works out the rest. Vanilla's own handler would also
-- move the headers, a pixel apart depending on which edge was dragged.
local function onNameResized(pane, header) pane.column3 = header:getX() + header:getWidth() end
local function onCategoryResized(pane, header) pane.column3 = header:getX() + 1 end
local function onWeightResized(pane, header) pane.pei_weightW = header:getWidth() end

-- Only the title is drawn: ISButton's prerender, which draws the background
-- and border, is replaced by the part that shows the tooltip. Clicks and
-- resizing stay vanilla's.
local function prerenderColumnHeader(header)
    header:updateTooltip()
end

local function restyleColumnHeader(pane, header, onResized)
    if not header or header.pei_restyledWith == renderColumnTitle then return end
    header.prerender = prerenderColumnHeader
    header.render = renderColumnTitle
    header.onresize = { function(target, button) onResized(target, button) end, pane, header }
    header.pei_restyledWith = renderColumnTitle
end

-- The weight column's header, made once: dragging its left edge resizes the
-- weight column, as the one between the name and the category resizes those.
local function ensureWeightHeader(pane)
    local header = pane.pei_weightHeader
    if not header then
        header = ISResizableButton:new(0, 0, 1, 1, getText("IGUI_invpanel_weight"), pane, nil)
        header:initialise()
        header.resizeLeft = true
        pane:addChild(header)
        pane.pei_weightHeader = header
    end
    if header.pei_restyledWith ~= renderColumnTitle then
        header.onclick = function(target) PEI.Sorting.toggleWeight(target) end
    end
    restyleColumnHeader(pane, header, onWeightResized)
    return header
end

-- ------------------------------------------------------------------ --
-- Icon buttons
-- ------------------------------------------------------------------ --

local EXPAND_ALL_LOOK = { icon = "chevrons-up-down", iconSize = Theme.smallIconSize }
local COLLAPSE_ALL_LOOK = { icon = "chevrons-down-up", iconSize = Theme.smallIconSize }

-- One tag in the family order, two once reversed.
local FAMILY_SORT_BUTTON = {
    icon = function(button)
        return button.parent.itemSortFunc == Sorting.byFamilyDescending and "tags" or "tag"
    end,
    iconSize = Theme.smallIconSize,
    tooltip = "IGUI_PEI_SortByFamily",
    onClick = function(pane) PEI.Sorting.toggleFamily(pane) end,
}

-- Makes and restyles the header's controls and places the icon buttons:
-- the expand buttons head the expand column, the family sort the icons'.
-- The column headers are placed by ListColumns.apply.
local function placeControls(pane, cols)
    restyleColumnHeader(pane, pane.nameHeader, onNameResized)
    restyleColumnHeader(pane, pane.typeHeader, onCategoryResized)
    IconButton.restyle(pane.expandAll, EXPAND_ALL_LOOK)
    IconButton.restyle(pane.collapseAll, COLLAPSE_ALL_LOOK)
    ensureWeightHeader(pane)
    local familySort = IconButton.ensure(pane, "pei_familySortButton", FAMILY_SORT_BUTTON)
    for _, button in ipairs({ pane.expandAll, pane.collapseAll }) do
        Bounds.setX(button, 0)
        Bounds.setWidth(button, cols.iconLeft)
    end
    IconButton.place(familySort, cols.iconLeft, 0, cols.iconWidth, pane.headerHgt)
end

-- The header's controls only exist for the list: in the grid they are
-- hidden, and hidden elements get no mouse events either, so the grid's top
-- holds nothing of theirs. In the list they are made, restyled and placed
-- where the columns are. Vanilla's sort menu is hidden in both views: the
-- footer's sort button and the column headers sort instead. Runs whenever
-- the window is laid out and after every refreshContainer(), which shows
-- vanilla's expand or collapse button again.
function ListHeader.layout(pane)
    if not pane.nameHeader then return end
    if pane.filterMenu then Bounds.hide(pane.filterMenu) end
    if ViewMode.isGrid(pane) then
        for _, control in ipairs({ pane.expandAll, pane.collapseAll, pane.nameHeader, pane.typeHeader,
                                   pane.pei_weightHeader, pane.pei_familySortButton }) do
            if control then Bounds.hide(control) end
        end
        return
    end
    local cols = ListColumns.compute(pane)
    placeControls(pane, cols)
    ListColumns.apply(pane, cols)
end

-- ------------------------------------------------------------------ --
-- Divider lines
-- ------------------------------------------------------------------ --

-- While a divider is hovered or dragged, a line runs down the whole list
-- from it, in the theme's text colour.
local function drawDividerLines(pane)
    local thickness = math.max(1, Theme.borderWidth())
    for _, header in ipairs({ pane.typeHeader, pane.pei_weightHeader }) do
        if header and header:isVisible() and isDividerActive(pane, header) then
            -- Lifting the clip leaves nothing drawable until the area is
            -- opened again, as vanilla does for its line.
            pane:repaintStencilRect(header:getX(), 0, thickness, pane.height)
            local color = Theme.textColor()
            ISUIElement.drawRectStatic(pane, header:getX(), 0, thickness, pane.height, 1, color.r, color.g, color.b)
        end
    end
end

-- Vanilla draws its own line, white, for the name's divider only; it is
-- left out for the one above.
local function drawRectStaticWithoutResizeLine(pane, x, y, w, h, a, r, g, b)
    if w == 2 and a == 0.5 and r == 1 and g == 1 and b == 1 then return end
    return ISUIElement.drawRectStatic(pane, x, y, w, h, a, r, g, b)
end

local RENDER_OVERRIDES = { drawRectStatic = drawRectStaticWithoutResizeLine }

-- After vanilla's render, whose last step lifts the pane's clip.
ViewMode.overrideForList("render", function(vanilla, pane)
    DrawOverrides.run(pane, RENDER_OVERRIDES, vanilla)
    drawDividerLines(pane)
end)
