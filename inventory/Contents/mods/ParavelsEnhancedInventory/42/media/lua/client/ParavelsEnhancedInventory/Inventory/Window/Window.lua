--[[
    Paravel's Enhanced Inventory - themed inventory window

    The inventory and loot windows (ISInventoryPage) in the theme: a rounded
    background and outline, a title bar of container tabs and our own
    buttons (with a faint tint and a divider under it), the pane inset by
    the window's padding, and a footer in place of vanilla's status bar and
    container controls. In either view.

    Vanilla's prerender and render are kept: while they run, their draw
    calls are swapped (Paravel's UI, Draw/DrawOverrides.lua) to leave out what the theme
    replaces. Every frame the window's parts are laid out again
    (Window.layout), since vanilla moves them back on its own.
]]

require "ISUI/ISInventoryPage"
require "ParavelsEnhancedInventory/Inventory/Window/WindowMetrics"
require "ParavelsEnhancedInventory/Inventory/Window/WindowTabs"
require "ParavelsEnhancedInventory/Inventory/Window/TitleButtons"
require "ParavelsEnhancedInventory/Inventory/Window/Footer"
require "ParavelsEnhancedInventory/Inventory/Window/CollapsedBar"
require "ParavelsEnhancedInventory/Inventory/Grid/GridLayout"
require "ParavelsEnhancedInventory/Inventory/List/ListHeader"
require "ParavelsUI/Draw/DrawOverrides"
require "ParavelsUI/Controls/ScrollBar"
require "ParavelsUI/Shapes/WindowFrame"
require "ParavelsUI/Controls/Bounds"
require "ParavelsUI/Shapes/Line"

local Bounds = PUI.Bounds
local CollapsedBar = PEI.CollapsedBar
local Draw = PUI.Draw
local DrawOverrides = PUI.DrawOverrides
local Footer = PEI.Footer
local GridLayout = PEI.GridLayout
local Line = PUI.Line
local ListHeader = PEI.ListHeader
local ScrollBar = PUI.ScrollBar
local Theme = PUI.Theme
local TitleButtons = PEI.TitleButtons
local ViewMode = PEI.ViewMode
local WindowFrame = PUI.WindowFrame
local WindowMetrics = PEI.WindowMetrics
local WindowTabs = PEI.WindowTabs

local Window = PEI.Window or {}
PEI.Window = Window

-- The smallest the window can be made in the grid, in cells.
local MIN_COLUMNS = 5
local MIN_ROWS = 2

-- Vanilla's minimum window size, for the list.
local LIST_MINIMUM_WIDTH_WITHOUT_COLUMN, LIST_MINIMUM_HEIGHT = 256, 100

-- ------------------------------------------------------------------ --
-- Chrome: background, header tint, divider
-- ------------------------------------------------------------------ --

-- The header (from the window's top to the divider) has a faint tint of the
-- text colour over the window's background, so it reads apart from the
-- pane. The selected tab is cut out of it, its rounded top corners
-- included: it keeps the pane's background and reads as one piece with it,
-- which the opening in the divider continues.
local function drawHeaderTint(page)
    local alpha = Theme.headerTintAlpha()
    if alpha <= 0 then return end
    local color = Theme.textColor()
    -- Collapsed, the bar is the whole window.
    if page.isCollapsed then
        local height = page:titleBarHeight()
        Draw.roundedRect(page, 0, 0, page:getWidth(), height, WindowFrame.radius(page, height), color, alpha)
        return
    end
    local column = page.containerButtonPanel
    local width, bottom = page:getWidth(), column:getY() + column:getHeight()
    local radius = WindowFrame.radius(page, bottom)
    local tab = WindowTabs.visibleSelected(page)
    if not tab then
        Draw.roundedRect(page, 0, 0, width, bottom, radius, color, alpha, Draw.TOP_CORNERS)
        return
    end
    local x0 = column:getX() + tab:getX()
    local x1 = x0 + tab:getWidth()
    local y0 = column:getY() + tab:getY()
    local y1 = y0 + tab:getHeight()
    -- Around the tab: above it, beside it, below it (when it does not reach
    -- the divider).
    Draw.roundedRect(page, 0, 0, width, y0, radius, color, alpha, Draw.TOP_CORNERS)
    Draw.rect(page, 0, y0, x0, y1 - y0, color, alpha)
    Draw.rect(page, x1, y0, width - x1, y1 - y0, color, alpha)
    if y1 < bottom then Draw.rect(page, 0, y1, width, bottom - y1, color, alpha) end
    -- Into the tab's rounded top corners, outside their curve.
    local tabRadius = Draw.fitRadius(Theme.smallRadius(), x1 - x0, y1 - y0)
    Draw.outsideCorners(page, x0, y0, x1 - x0, y1 - y0, tabRadius, Draw.TOP_CORNERS, color, alpha)
end

-- A line from one side of the window to the other, under the tabs, so the
-- tabs and the pane read as two parts. It opens under the selected tab,
-- which sits on it, so the tab reads as the way into the pane below.
local function drawDivider(page)
    if page.isCollapsed then return end
    local thickness = Theme.borderWidth()
    if thickness <= 0 or Theme.borderAlpha() <= 0 then return end
    local column = page.containerButtonPanel
    local y = column:getY() + column:getHeight()
    local width = page:getWidth()
    local openFrom, openTo = width, width
    local tab = WindowTabs.visibleSelected(page)
    if tab then
        -- Inside the tab's own outline, which has the same thickness.
        openFrom = column:getX() + tab:getX() + thickness
        openTo = column:getX() + tab:getX() + tab:getWidth() - thickness
    end
    Line.draw(page, 0, y, openFrom, thickness)
    Line.draw(page, openTo, y, width - openTo, thickness)
end

-- ------------------------------------------------------------------ --
-- Draw overrides for vanilla's prerender and render
-- ------------------------------------------------------------------ --

-- Vanilla's container column background and border, both drawn at the
-- column's place on the right; the tabs draw their own.
local function isContainerColumnRect(page, x, w)
    return x == page:getWidth() - page.buttonSize and w == page.buttonSize
end

-- The window's background is the one rectangle drawn from its top left
-- corner across its whole width; it is drawn rounded. The rest goes
-- through vanilla's drawRect, which skips it while the window is collapsed.
local function drawRectRounded(page, x, y, w, h, ...)
    if x == 0 and y == 0 and w == page:getWidth() then
        return WindowFrame.drawBackground(page, h)
    end
    if isContainerColumnRect(page, x, w) then return end
    return ISUIElement.drawRect(page, x, y, w, h, ...)
end

-- The title bar is drawn without vanilla's decorated texture.
local function drawTextureScaledWithoutTitleBar(page, texture, ...)
    if texture == page.titlebarbkg then return end
    return ISUIElement.drawTextureScaled(page, texture, ...)
end

-- The tabs replace the title, which is not drawn; the weight is kept for
-- the footer.
local function drawTextRightIntoFooter(page, text, x)
    Footer.captureWeightLabel(page, text, x)
end

-- The only border vanilla's prerender draws is the title bar's, whose
-- bottom edge divides it from the rest of the window; the divider replaces
-- it. The title text is replaced by the tabs.
local PRERENDER_OVERRIDES = {
    drawRect = drawRectRounded,
    drawTextureScaled = drawTextureScaledWithoutTitleBar,
    drawTextRight = drawTextRightIntoFooter,
    drawRectBorder = DrawOverrides.skip,
    drawText = DrawOverrides.skip,
}

-- render() draws the status bar below the pane: its texture, the resize
-- corner and a border, then the column's border; none are kept. The
-- window's outer border is drawn rounded.
local function drawTextureScaledWithoutStatusBar(page, texture, ...)
    if texture == page.statusbarbkg or texture == page.resizeimage then return end
    return ISUIElement.drawTextureScaled(page, texture, ...)
end

local function drawRectBorderRounded(page, x, y, w, h, ...)
    local isStatusBarBorder = y > page.inventoryPane.y and w == page:getWidth() and y + h == page:getHeight()
    if isStatusBarBorder then return end
    if x == 0 and y == 0 and w == page:getWidth() then
        return WindowFrame.drawOutline(page, h)
    end
    if isContainerColumnRect(page, x, w) then return end
    return ISUIElement.drawRectBorder(page, x, y, w, h, ...)
end

local RENDER_OVERRIDES = {
    drawTextureScaled = drawTextureScaledWithoutStatusBar,
    drawRectBorder = drawRectBorderRounded,
}

-- ------------------------------------------------------------------ --
-- Layout
-- ------------------------------------------------------------------ --

-- The title bar of the open window: the padding, the row of tabs and the gap
-- under it.
local function expandedTitleBarHeight()
    return WindowMetrics.padding() + WindowTabs.height() + Theme.sectionGap()
end

-- Vanilla's resize corner covers the grip and everything from it to the
-- window's bottom right corner; the bottom edge's widget runs from the
-- window's left edge to the transfer buttons (or the corner). It must stop
-- short of the buttons: vanilla's refreshBackpacks brings it to the top,
-- and from then on it took the clicks on their lower half.
local function placeResizeWidgets(page, footer)
    local corner, edge = page.resizeWidget, page.resizeWidget2
    if not (corner and edge) then return end
    -- At least vanilla's own size, kept from before it was first changed.
    corner.pei_vanillaSize = corner.pei_vanillaSize or corner:getWidth()
    local cornerX = math.min(footer.resizeCornerX, page:getWidth() - corner.pei_vanillaSize)
    local cornerY = math.min(footer.resizeCornerY, page:getHeight() - corner.pei_vanillaSize)
    Bounds.setX(corner, cornerX)
    Bounds.setY(corner, cornerY)
    Bounds.setWidth(corner, page:getWidth() - cornerX)
    Bounds.setHeight(corner, page:getHeight() - cornerY)
    Bounds.setX(edge, 0)
    Bounds.setWidth(edge, math.min(cornerX, footer.buttonsLeft or cornerX))
    -- Vanilla does not anchor it to the bottom: it stays where it was made,
    -- which for a window made short was over the title buttons.
    Bounds.setY(edge, page:getHeight() - edge:getHeight())
end

-- The pane, inset by the padding, between the title bar and the footer.
local function placePane(page)
    local padding = WindowMetrics.padding()
    local pane = page.inventoryPane
    Bounds.setX(pane, padding)
    Bounds.setY(pane, expandedTitleBarHeight())
    Bounds.setWidth(pane, page:getWidth() - padding * 2)
    Bounds.setHeight(pane, page.height - pane.y - Footer.height(page))
    -- Its scroll bar is placed against its right edge once, when it is made,
    -- and only follows width changes through its anchor, which drifts as the
    -- pane is resized and re-inset; it is put back where vanilla puts it.
    -- Its height too: vanilla's update() shrinks the pane for a moment (by
    -- its resize widget's height) before this re-sizes it, and the anchored
    -- scroll bar did not always grow back, showing a thumb now and then over
    -- content that fits.
    if pane.vscroll then
        ScrollBar.restyle(pane.vscroll)
    end
end

-- Top to bottom: the tabs, the pane, the footer (whose buttons the resize
-- widgets must stay clear of).
local function placeContents(page)
    WindowTabs.update(page)
    placePane(page)
    placeResizeWidgets(page, Footer.place(page))
end

-- In the grid the window is sized by a number of columns and of rows, so
-- the cells fill it with no space left over. The counts are what the player
-- chose: taken when a resize drag ends (rounded down to what fits, never
-- below the minimum), or from the window's size the first time. Between
-- drags they stay put and the window's size follows from them. While the
-- player drags, the window follows the mouse freely. Returns true when it
-- changed the window's size.
local function snapToGrid(page)
    local pane = page.inventoryPane
    if not ViewMode.isGrid(pane) then
        page.minimumWidth = LIST_MINIMUM_WIDTH_WITHOUT_COLUMN + page.buttonSize
        page.minimumHeight = LIST_MINIMUM_HEIGHT
        return false
    end
    local measures = GridLayout.measure(pane)
    local padding = WindowMetrics.padding()
    local function widthFor(columns)
        return GridLayout.columnsWidth(measures, columns) + padding * 2
    end
    local function heightFor(rows)
        return expandedTitleBarHeight() + GridLayout.rowsHeight(measures, rows) + Footer.height(page)
    end
    -- The smallest the window goes is whole columns and rows too, so
    -- dragging it to its minimum does not snap it back out.
    local minColumns, minRows = MIN_COLUMNS, MIN_ROWS
    page.minimumWidth, page.minimumHeight = widthFor(minColumns), heightFor(minRows)
    for _, widget in ipairs({ page.resizeWidget, page.resizeWidget2 }) do
        -- Snapping during a drag would fight it.
        if widget.resizing then
            page.pei_wasResized = true
            return false
        end
    end
    if page.isCollapsed then return false end
    if page.pei_wasResized or not page.pei_columns then
        local usableWidth = pane:getWidth() - measures.scrollLane - measures.inset + measures.gap
        local usableHeight = pane:getHeight() - measures.inset * 2 + measures.gap
        page.pei_columns = math.max(minColumns, math.floor(usableWidth / measures.stepX))
        page.pei_rows = math.max(minRows, math.floor(usableHeight / measures.stepY))
        page.pei_wasResized = nil
    end
    local width = widthFor(math.max(minColumns, page.pei_columns))
    local height = heightFor(math.max(minRows, page.pei_rows))
    if width == page:getWidth() and height == page:getHeight() then return false end
    page:setWidth(width)
    page:setHeight(height)
    return true
end

-- Makes the window take its grid size from its current size again (a
-- restored layout sets it).
function Window.forgetGridSize(page)
    page.pei_columns, page.pei_rows = nil, nil
end

-- A collapsed window draws only its title bar, which is then the collapsed
-- bar (Window/CollapsedBar.lua). Vanilla collapses the windows when the
-- player is made with a fixed height of 15 pixels (ISPlayerDataObject),
-- which would cut it off until the window was first opened; its own collapse
-- uses titleBarHeight() (as does this), so it is kept equal on every frame.
local function fitCollapsedHeight(page)
    if page.isCollapsed then page:setMaxDrawHeight(page:titleBarHeight()) end
end

-- Run after vanilla's update(), after vanilla moves the window's parts back
-- (refreshBackpacks), and again right before the window is drawn: a resize
-- widget sets the width from mouse events, between update and drawing, and
-- a frame drawn with that width (the pane not yet re-inset, or not yet
-- snapped) shows the cells wrapping for an instant.
function Window.layout(page)
    page.pei_laidOut = true
    -- Vanilla's container controls are hidden here rather than in their
    -- arrange(): update() re-arranges them every frame and a mod loaded
    -- after this one may replace arrange() without calling ours. Hidden
    -- before the window draws, they never show, even when a click arranged
    -- them between two updates.
    local controlsUI = page.controlsUI
    if controlsUI then
        Bounds.setVisible(controlsUI, false)
        Bounds.setHeight(controlsUI, 0)
    end
    placeContents(page)
    if snapToGrid(page) then placeContents(page) end
    fitCollapsedHeight(page)
    ListHeader.layout(page.inventoryPane)
end

-- ------------------------------------------------------------------ --
-- Page overrides
-- ------------------------------------------------------------------ --

-- Everything vanilla places under the title bar (pane, collapsed height, the
-- strip of a collapsed window that opens it) follows it.
PUI.override(ISInventoryPage, "titleBarHeight", function(vanilla, page)
    if page.isCollapsed then return CollapsedBar.height() end
    return expandedTitleBarHeight()
end)

PUI.override(ISInventoryPage, "update", function(vanilla, page)
    vanilla(page)
    Window.layout(page)
end)

PUI.override(ISInventoryPage, "prerender", function(vanilla, page)
    Window.layout(page)
    -- Nothing else depends on where they are, so once a frame is enough.
    TitleButtons.update(page)
    DrawOverrides.run(page, PRERENDER_OVERRIDES, vanilla)
    drawHeaderTint(page)
    drawDivider(page)
    Footer.draw(page)
    CollapsedBar.draw(page)
end)

-- Vanilla rebuilds the window's tabs here, and puts the pane and the tab
-- column back where it has them. It runs on both windows when something
-- moves between containers, from the prerender of whichever draws first, so
-- the other would show its contents in vanilla's places for a frame: the
-- window is laid out again at once (once it has been laid out at all: the
-- first run is while vanilla is still making the window).
PUI.override(ISInventoryPage, "refreshBackpacks", function(vanilla, page, ...)
    local result = vanilla(page, ...)
    if page.pei_laidOut then Window.layout(page) end
    return result
end)

PUI.override(ISInventoryPage, "render", function(vanilla, page)
    DrawOverrides.run(page, RENDER_OVERRIDES, vanilla)
end)
