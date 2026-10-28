--[[
    Paravel's Enhanced Inventory - window footer

    Under the pane, left to right: Lucide's "weight" icon; the container's
    weight as vanilla words it ("12.4 / 30", with the item limit in
    multiplayer) and, under it, a bar of how full the container is; then the
    transfer buttons (Window/TransferButtons.lua), the sort button and the
    resize grip. The icons are centred on the weight's block. Spaced like
    the title bar: a gap above, the text measured on its figures, the
    window's padding below.

    Footer.place works out where everything goes and places the buttons,
    right to left, in one pass; what it worked out is kept in
    page.pei_footer for the drawing and the window's resize widgets.

    The compact view has no footer: only the window's padding under the
    pane, and the resize corner, unseen, in the window's own corner.
]]

require "ParavelsEnhancedInventory/Inventory/Window/WindowMetrics"
require "ParavelsEnhancedInventory/Inventory/Window/TransferButtons"
require "ParavelsEnhancedInventory/Inventory/Sorting"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsUI/Controls/IconButton"
require "ParavelsUI/Shapes/ProgressBar"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Controls/Bounds"

local Bounds = PUI.Bounds
local Draw = PUI.Draw
local IconButton = PUI.IconButton
local ProgressBar = PUI.ProgressBar
local Sorting = PEI.Sorting
local Text = PUI.Text
local Theme = PUI.Theme
local TransferButtons = PEI.TransferButtons
local ViewMode = PEI.ViewMode
local WindowMetrics = PEI.WindowMetrics

local Footer = PEI.Footer or {}
PEI.Footer = Footer

-- ------------------------------------------------------------------ --
-- Measures
-- ------------------------------------------------------------------ --

-- The block right of the weight icon: the figures, then the bar.
local function blockHeight(page)
    local figures = Text.letterHeight(page.titleFont, Text.FIGURES)
    local barHeight = ProgressBar.height()
    if barHeight <= 0 then return figures end
    return figures + Theme.halfGap() + barHeight
end

-- Where the figures' tops go.
local function blockTop(page)
    return WindowMetrics.paneBottom(page) + Theme.sectionGap()
end

-- The y of an icon of `size` centred on the block.
local function iconYOnBlock(page, size)
    return blockTop(page) + math.floor(blockHeight(page) / 2 - size / 2 + 0.5)
end

local function isCompact(page)
    return ViewMode.isCompact(page.inventoryPane)
end

-- From the pane's bottom to the window's: the gap, the block, the padding.
function Footer.height(page)
    if isCompact(page) then return WindowMetrics.padding() end
    return Theme.sectionGap() + blockHeight(page) + WindowMetrics.padding()
end

-- ------------------------------------------------------------------ --
-- Weight label
-- ------------------------------------------------------------------ --

-- Vanilla draws the weight right-aligned in the title bar, near its pin
-- button. This stands in for page.drawTextRight during vanilla's prerender:
-- it draws nothing and keeps that text for the footer. For the player's own
-- inventory vanilla draws it, then draws an unset label (nil) again.
local function titleBarTextGap()
    return 1 + (5 - getCore():getOptionFontSizeReal()) * 2
end

function Footer.captureWeightLabel(page, text, x)
    if text and x >= page.pinButton:getX() - titleBarTextGap() then page.pei_weightLabel = text end
end

-- How full the container is (0 to 1, and past 1 when over), or nil when it
-- has no capacity (the floor). The player's own inventory is measured
-- against the most the player can carry, as vanilla's label does.
function Footer.fullness(page)
    local inventory = page.inventoryPane.inventory
    if not inventory or not page.totalWeight then return nil end
    local player = getSpecificPlayer(page.player)
    local capacity = page.capacity
    if player and inventory == player:getInventory() then capacity = player:getMaxWeight() end
    if not capacity or capacity <= 0 then return nil end
    return page.totalWeight / capacity
end

-- ------------------------------------------------------------------ --
-- Sort button
-- Lucide's "arrow-up-down", next to the grip, in both views. It opens a
-- menu laid out like vanilla's sort menu: each sort with an ascending and a
-- descending choice, the one in use checked.
-- ------------------------------------------------------------------ --

function Footer.openSortMenu(page, button)
    local pane = page.inventoryPane
    local menu = ISContextMenu.get(page.player, button:getAbsoluteX(), button:getAbsoluteY() + button:getHeight())
    for _, choice in ipairs(Sorting.CHOICES) do
        local option = menu:addOption(getText(choice.titleKey), nil, nil)
        local subMenu = ISContextMenu:getNew(menu)
        menu:addSubMenu(option, subMenu)
        menu:setOptionChecked(option, pane.itemSortFunc == choice.ascending or pane.itemSortFunc == choice.descending)
        local ascending = subMenu:addOption(getText("IGUI_invpanel_ascending"), pane, Sorting.set, choice.ascending)
        subMenu:setOptionChecked(ascending, pane.itemSortFunc == choice.ascending)
        local descending = subMenu:addOption(getText("IGUI_invpanel_descending"), pane, Sorting.set, choice.descending)
        subMenu:setOptionChecked(descending, pane.itemSortFunc == choice.descending)
    end
end

local SORT_BUTTON = {
    icon = "arrow-up-down",
    tooltip = "IGUI_PEI_Sort",
    onClick = function(page, button) PEI.Footer.openSortMenu(page, button) end,
}

-- ------------------------------------------------------------------ --
-- Placing
-- ------------------------------------------------------------------ --

--[[
    Places the footer's buttons and keeps in page.pei_footer where its parts go:
        top           where the figures' tops go
        iconSize      the footer's icons' size
        iconY         the y of an icon centred on the weight's block
        gripX         the resize grip's x (Lucide's "move-diagonal-2" at the
                      right end; vanilla's corner resize widget is laid over it)
        buttonsLeft   x of the leftmost button, or nil when none shows
        barRight      where the capacity bar ends
        resizeCornerX, resizeCornerY
                      where vanilla's corner resize widget starts: the grip
    In the compact view, which has no footer, only resizeCornerX and
    resizeCornerY: the window's bottom right corner, which the widget keeps to.
    Runs whenever the window is laid out.
]]
function Footer.place(page)
    local size = Theme.smallIconSize()
    local padding = WindowMetrics.padding()
    local sortButton = IconButton.ensure(page, "pei_sortButton", SORT_BUTTON)
    if isCompact(page) then
        Bounds.hide(sortButton)
        TransferButtons.place(page, nil)
        page.pei_footer = { resizeCornerX = page:getWidth(), resizeCornerY = page:getHeight() }
        return page.pei_footer
    end
    local footer = { top = blockTop(page), iconSize = size, iconY = iconYOnBlock(page, size),
                     gripX = page:getWidth() - padding - size }
    footer.resizeCornerX, footer.resizeCornerY = footer.gripX, footer.iconY
    if page.isCollapsed or size <= 0 then
        Bounds.hide(sortButton)
        TransferButtons.place(page, nil)
    else
        -- The sort button next to the grip, the transfer buttons on its left.
        local sortX = footer.gripX - Theme.gap() - size
        IconButton.place(sortButton, sortX, footer.iconY, size)
        local transferLeft = TransferButtons.place(page, sortX - Theme.gap(), footer.iconY, size)
        footer.buttonsLeft = transferLeft or sortX
    end
    footer.barRight = footer.buttonsLeft and footer.buttonsLeft - Theme.gap()
        or (size > 0 and footer.gripX - Theme.gap() or page:getWidth() - padding)
    page.pei_footer = footer
    return footer
end

-- ------------------------------------------------------------------ --
-- Drawing
-- ------------------------------------------------------------------ --

local function drawGrip(page, footer)
    local size = footer.iconSize
    if size <= 0 then return end
    local corner = page.resizeWidget
    local isHovered = corner and (corner.resizing or corner:isMouseOver())
    Draw.icon(page, "move-diagonal-2", footer.gripX, footer.iconY, size, Theme.textColor(),
        Theme.interactiveAlpha(isHovered))
end

-- The bar runs from under the text to just before the buttons (or the
-- grip), in the colour of how full the container is.
local function drawCapacityBar(page, footer, x, y)
    local full = Footer.fullness(page)
    if ProgressBar.height() <= 0 or not full then return end
    ProgressBar.draw(page, x, y, footer.barRight - x, full, Theme.fullnessColor(full))
end

function Footer.draw(page)
    local label, footer = page.pei_weightLabel, page.pei_footer
    if page.isCollapsed or isCompact(page) or not (label and footer) then return end
    local color, alpha = Theme.textColor(), Theme.mutedAlpha()
    local x = WindowMetrics.padding()
    local size = footer.iconSize
    if size > 0 then
        Draw.icon(page, "weight", x, footer.iconY, size, color, alpha)
        x = x + size + Theme.gap()
    end
    Draw.text(page, label, x, Text.yForLettersTop(footer.top, page.titleFont, Text.FIGURES), color, alpha,
        page.titleFont)
    drawCapacityBar(page, footer, x, footer.top + Text.letterHeight(page.titleFont, Text.FIGURES) + Theme.halfGap())
    drawGrip(page, footer)
end
