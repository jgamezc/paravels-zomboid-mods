--[[
    Paravel's Enhanced Inventory - container tabs

    Vanilla's container buttons (the column on the window's right), laid out
    as a row of tabs along the top of the window, in place of its title.
    Each shows its container's icon; the selected one also shows the
    container's name (except in the compact view and while an item is
    dragged over the tabs), the others show it as a tooltip. The buttons keep
    vanilla's clicks, drops, context menus and hover highlights; only how
    they look and where they are is ours.

    The tabs keep to one row, so the title bar never changes height as
    containers come and go. When they do not fit, the row shows as many
    whole tabs as fit, and an arrow on each side with tabs out of sight
    moves it a tab at a time (the selected tab is always brought into
    sight). Held over during a drag, an arrow keeps moving the row, so an
    item can still be dropped on a container that was out of sight.

    This file places the tabs and the arrows; how a tab looks is
    Window/TabLook.lua's, and which one is open Window/TabSelection.lua's.
]]

require "ISUI/ISInventoryPage"
require "ParavelsEnhancedInventory/Inventory/Window/WindowMetrics"
require "ParavelsEnhancedInventory/Inventory/Window/OpenTab"
require "ParavelsEnhancedInventory/Inventory/Window/TitleButtons"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsUI/Controls/IconButton"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Controls/Bounds"

local Bounds = PUI.Bounds
local Draw = PUI.Draw
local IconButton = PUI.IconButton
local OpenTab = PEI.OpenTab
local Text = PUI.Text
local Theme = PUI.Theme
local TitleButtons = PEI.TitleButtons
local ViewMode = PEI.ViewMode
local WindowMetrics = PEI.WindowMetrics

local WindowTabs = PEI.WindowTabs or {}
PEI.WindowTabs = WindowTabs

-- How long a drag must rest on an arrow before the tabs scroll, in ms.
local SCROLL_DRAG_DELAY = 400

-- The game's "inventory container size" option (small, medium, large) still
-- picks the icons' size, but on whole multiples of the icons' 32 px, so they
-- stay pixel exact.
local TAB_ICON_SIZES = { 32, 64, 96 }

-- ------------------------------------------------------------------ --
-- Measures
-- ------------------------------------------------------------------ --

function WindowTabs.iconSize()
    return TAB_ICON_SIZES[getCore():getOptionInventoryContainerSize()] or TAB_ICON_SIZES[1]
end

-- The margin on each side of a tab's icon.
function WindowTabs.padX()
    return Theme.gap() + Theme.halfGap()
end

-- A tab is the icon plus a margin around it; the selected one adds the name
-- after the icon.
function WindowTabs.height()
    return WindowTabs.iconSize() + Theme.gap() * 2
end

-- The selected tab, when it is in sight (one scrolled away during a drag is not).
function WindowTabs.visibleSelected(page)
    for _, button in ipairs(page.backpacks or {}) do
        if OpenTab.isSelected(page, button) and button:getIsVisible() then return button end
    end
    return nil
end

-- Width of one scroll arrow: the chevron and, beside it, room for how many
-- tabs are out of sight on its side (as many digits as the count of all the
-- tabs), so the row does not shift as the count changes.
local function scrollArrowWidth(page)
    local digits = tostring(#(page.backpacks or {}))
    return Theme.iconSize() + Theme.halfGap() + Text.width(digits, UIFont.Small)
end

-- ------------------------------------------------------------------ --
-- Row layout
-- ------------------------------------------------------------------ --

local function isDragging()
    return ISMouseDrag.dragging ~= nil and #ISMouseDrag.dragging > 0
end

-- Whether an item is being dragged over the title bar, where the tabs are.
local function isDraggingOverTabs(page)
    if not isDragging() then return false end
    local x, y = page:getMouseX(), page:getMouseY()
    return x >= 0 and x < page:getWidth() and y >= 0 and y < WindowMetrics.padding() * 2 + WindowTabs.height()
end

-- Each tab's width with side margins `padX`, and the selected one's name (when
-- `showsName`), cut short only if it would not fit `room` on its own.
local function measureTabs(page, padX, room, showsName)
    local iconSize, nameGap = WindowTabs.iconSize(), Theme.gap()
    local widths, names, selectedIndex = {}, {}, nil
    for index, button in ipairs(page.backpacks or {}) do
        widths[index] = padX * 2 + iconSize
        if OpenTab.isSelected(page, button) then
            selectedIndex = index
            if button.name and showsName then
                -- The tab's margin goes around the icon and the name alike.
                names[index] = Text.fit(button.name, room - (padX * 2 + iconSize + nameGap), UIFont.Small)
                widths[index] = padX + iconSize + nameGap + Text.width(names[index], UIFont.Small) + padX
            end
        end
    end
    return widths, names, selectedIndex
end

-- Width of tabs first..last side by side.
local function spanWidth(widths, first, last, gap)
    local width = 0
    for index = first, last do width = width + widths[index] end
    return width + gap * math.max(0, last - first)
end

--[[
    The row as it is laid out now:
        tabs         where each tab goes, in the row's coordinates, as
                     { button, x, w, name } (x is nil for a tab out of sight)
        overflowing  whether the tabs do not all fit, so arrows may show
        inset        where the row starts, after the left arrow
        rowEnd       where the last tab in sight ends
        hiddenLeft, hiddenRight  how many tabs are out of sight on each side
        maxFirst     the furthest the row scrolls
    The first tab in sight is kept in page.pei_tabFirst between frames (the
    arrows move it), with what the row last brought into sight.
]]
local function layoutRow(page)
    local fullRoom = page:getWidth() - WindowMetrics.padding() * 2 - TitleButtons.totalWidth()
    local gap = Theme.halfGap()
    local padX = WindowTabs.padX()
    local buttons = page.backpacks or {}
    local count = #buttons
    local showsName = not ViewMode.isCompact(page.inventoryPane)
    local widths, names, selectedIndex = measureTabs(page, padX, fullRoom, showsName)
    -- The name is left out while an item is dragged over the tabs, but only
    -- if the tabs do not all fit with it: then more of them fit for the item
    -- to be dropped on. Decided on the width with the name, so that leaving
    -- it out does not make it come back on the next frame.
    if showsName and isDraggingOverTabs(page) and count > 0 and spanWidth(widths, 1, count, gap) > fullRoom then
        showsName = false
        widths, names, selectedIndex = measureTabs(page, padX, fullRoom, showsName)
    end

    local overflowing = count > 0 and spanWidth(widths, 1, count, gap) > fullRoom
    local room, first, inset, maxFirst = fullRoom, 1, 0, 1
    if overflowing then
        -- An arrow, with its gap to the tabs, takes room only on a side with
        -- tabs out of sight: the left one when the row does not start at the
        -- first tab, the right one when the rest do not fit without it.
        local arrowRoom = scrollArrowWidth(page) + Theme.gap()
        local function roomStartingAt(firstShown)
            local r = fullRoom - (firstShown > 1 and arrowRoom or 0)
            if spanWidth(widths, firstShown, count, gap) > r then r = r - arrowRoom end
            return r
        end
        -- Names are cut to the least room the row can have.
        widths, names, selectedIndex = measureTabs(page, padX, fullRoom - arrowRoom * 2, showsName)
        maxFirst = count
        while maxFirst > 1 and spanWidth(widths, maxFirst - 1, count, gap) <= roomStartingAt(maxFirst - 1) do
            maxFirst = maxFirst - 1
        end
        first = PUI.clamp(page.pei_tabFirst or 1, 1, maxFirst)
        -- A newly selected container, a change in the containers, or the name
        -- coming or going (the tabs change width) brings the selected tab into
        -- sight; otherwise the arrows may leave it out.
        if selectedIndex and (buttons[selectedIndex].inventory ~= page.pei_tabSelectedInventory
                or count ~= page.pei_tabCount or showsName ~= page.pei_tabShowsName) then
            if selectedIndex < first then first = selectedIndex end
            while first < selectedIndex and spanWidth(widths, first, selectedIndex, gap) > roomStartingAt(first) do
                first = first + 1
            end
        end
        room = roomStartingAt(first)
        inset = first > 1 and arrowRoom or 0
    end
    page.pei_tabFirst = first
    -- Kept on every frame, overflowing or not: kept only while overflowing,
    -- a container selected while all tabs fit (whose long name then makes
    -- them overflow) could match a stale one and not be brought into sight.
    page.pei_tabSelectedInventory = selectedIndex and buttons[selectedIndex].inventory
    page.pei_tabCount = count
    page.pei_tabShowsName = showsName

    local tabs, x, lastShown, rowEnd = {}, 0, 0, 0
    for index, button in ipairs(buttons) do
        local tab = { button = button, w = widths[index], name = names[index] }
        if index >= first then
            if x + widths[index] <= room then
                tab.x = x
                rowEnd = x + widths[index]
                x = x + widths[index] + gap
                lastShown = index
            else
                -- Once one does not fit, none after it shows either.
                x = room + 1
            end
        end
        table.insert(tabs, tab)
    end
    return { tabs = tabs, overflowing = overflowing, inset = inset, rowEnd = rowEnd,
             hiddenLeft = overflowing and first - 1 or 0, hiddenRight = overflowing and count - lastShown or 0,
             maxFirst = maxFirst }
end

-- Moves the row by `step` tabs; layoutRow keeps it in range.
function WindowTabs.scroll(page, step)
    local maxFirst = page.pei_tabRow and page.pei_tabRow.maxFirst or 1
    page.pei_tabFirst = PUI.clamp((page.pei_tabFirst or 1) + step, 1, maxFirst)
end

-- How many tabs are out of sight on the side an arrow of `step` moves to.
local function hiddenTowards(row, step)
    if step < 0 then return row.hiddenLeft end
    return row.hiddenRight
end

-- ------------------------------------------------------------------ --
-- Scroll arrows
-- A Lucide chevron pointing out, with how many containers are out of sight
-- on that side between it and the tabs. The left one is at the row's
-- start, the right one follows the last tab in sight; a hidden one gives
-- its room back to the tabs. Each is as tall as the tabs, so it is easy to
-- hit.
-- ------------------------------------------------------------------ --

-- A click moves the row and selects the leftmost tab in sight, either way,
-- so the selection moves with the row. Vanilla's selectContainer leaves a
-- locked container unselected.
local function onArrowClick(page, step)
    WindowTabs.scroll(page, step)
    local button = page.backpacks and page.backpacks[page.pei_tabFirst]
    if button then page:selectContainer(button) end
end

-- During a drag, the arrow moves the row while the mouse rests on it.
local function scrollWhileDragging(button, page, step, hiddenCount)
    if hiddenCount > 0 and isDragging() and button:isMouseOver() then
        local now = getTimestampMs()
        if not button.pei_dragAt then
            button.pei_dragAt = now
        elseif now - button.pei_dragAt >= SCROLL_DRAG_DELAY then
            WindowTabs.scroll(page, step)
            button.pei_dragAt = now
        end
    else
        button.pei_dragAt = nil
    end
end

local function renderArrow(button, spec)
    local arrow = spec.arrow
    local row = button.parent.pei_tabRow
    local hiddenCount = row and hiddenTowards(row, arrow.step) or 0
    local color = Theme.textColor()
    local alpha = Theme.interactiveAlpha(button:isMouseOver())
    local size, w, h = Theme.iconSize(), button:getWidth(), button:getHeight()
    -- The chevron at the outer end, the count on its inner side.
    local pointsLeft = arrow.step < 0
    Draw.icon(button, arrow.icon, pointsLeft and 0 or w - size, math.floor((h - size) / 2), size, color, alpha)
    if hiddenCount > 0 then
        local text = tostring(hiddenCount)
        local gap = Theme.halfGap()
        local textX = pointsLeft and size + gap or w - size - gap - Text.width(text, UIFont.Small)
        Draw.text(button, text, textX, Text.yCentredIn(h, UIFont.Small), color, alpha, UIFont.Small)
    end
end

local ARROWS = {
    { key = "pei_tabLeft", icon = "chevron-left", step = -1 },
    { key = "pei_tabRight", icon = "chevron-right", step = 1 },
}
for _, arrow in ipairs(ARROWS) do
    arrow.spec = {
        arrow = arrow,
        render = renderArrow,
        onClick = function(page) onArrowClick(page, arrow.step) end,
    }
end

local function updateArrows(page, row)
    local padding = WindowMetrics.padding()
    local leftX = padding
    local rightX = padding + row.inset + row.rowEnd + Theme.gap()
    for index, arrow in ipairs(ARROWS) do
        local button = IconButton.ensure(page, arrow.key, arrow.spec)
        local hiddenCount = hiddenTowards(row, arrow.step)
        if hiddenCount > 0 then
            IconButton.place(button, index == 1 and leftX or rightX, padding, scrollArrowWidth(page), WindowTabs.height())
        else
            Bounds.hide(button)
        end
        scrollWhileDragging(button, page, arrow.step, hiddenCount)
    end
end

-- ------------------------------------------------------------------ --
-- Placing the tabs
-- ------------------------------------------------------------------ --

-- A collapsed window shows no tabs (Window/CollapsedBar.lua).
local function hideRow(page)
    Bounds.hide(page.containerButtonPanel)
    for _, arrow in ipairs(ARROWS) do
        local button = page[arrow.key]
        if button then Bounds.hide(button) end
    end
end

-- Vanilla's container column becomes the tab row: it moves to the top of
-- the window and its buttons are placed and sized as tabs. Vanilla places
-- them again whenever buttons are added or the size option changes, so this
-- runs every frame.
function WindowTabs.update(page)
    if page.isCollapsed then return hideRow(page) end
    local row = layoutRow(page)
    -- Kept for the arrows, which draw and scroll between layouts.
    page.pei_tabRow = row
    updateArrows(page, row)
    local padding = WindowMetrics.padding()
    local height = WindowTabs.height()
    local column = page.containerButtonPanel
    -- Between the arrows, when they show.
    Bounds.setVisible(column, true)
    Bounds.setX(column, padding + row.inset)
    Bounds.setY(column, padding)
    -- Only as wide as the tabs in sight: the right arrow follows the last
    -- one, and vanilla brings the column above it, so a wider column took
    -- the arrow's clicks.
    Bounds.setWidth(column, row.rowEnd)
    Bounds.setHeight(column, height)
    column:setScrollHeight(height)
    column:setYScroll(0)
    -- The column covers the whole header and swallows its clicks, so the
    -- window could only be dragged by the padding around it. With this flag
    -- ISPanel moves its parent (the window) when the empty part is dragged.
    column.moveWithMouse = true
    for _, tab in ipairs(row.tabs) do
        local button = tab.button
        -- Out of sight, a tab takes no clicks or drops either.
        Bounds.setVisible(button, tab.x ~= nil)
        Bounds.setX(button, tab.x or 0)
        Bounds.setY(button, 0)
        Bounds.setWidth(button, tab.w)
        Bounds.setHeight(button, height)
        button.pei_name = tab.name
        -- The name shows on the selected tab; the others say it on hover.
        button.tooltip = not tab.name and button.name or nil
    end
end
