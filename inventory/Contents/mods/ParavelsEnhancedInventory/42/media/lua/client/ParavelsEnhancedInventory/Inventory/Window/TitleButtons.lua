--[[
    Paravel's Enhanced Inventory - title bar buttons

    Lucide icons in the window's top right corner, inside its padding, from
    right to left: close, pin, then the list/grid toggle. They replace all
    of vanilla's title buttons (close, info, pin, collapse), which stay
    hidden: setInfo(), collapse() and setPinned() show them again, so this
    runs every frame. While the window is collapsed only close and pin show
    (Window/CollapsedBar.lua).
]]

require "ParavelsEnhancedInventory/Inventory/Window/WindowMetrics"
require "ParavelsEnhancedInventory/Inventory/ViewMode"
require "ParavelsUI/Controls/IconButton"
require "ParavelsUI/Controls/Bounds"

local Bounds = PUI.Bounds
local IconButton = PUI.IconButton
local Theme = PUI.Theme
local ViewMode = PEI.ViewMode
local WindowMetrics = PEI.WindowMetrics

local TitleButtons = PEI.TitleButtons or {}
PEI.TitleButtons = TitleButtons

-- Each view's icon.
local VIEW_ICONS = { list = "list", grid = "layout-grid", compact = "minimize-2" }

-- Right to left. Each is kept on the window under `key`.
local BUTTONS = {
    { key = "pei_closeButton", spec = {
        icon = "x",
        onClick = function(page) page:close() end,
    } },
    -- Pinned, the window stays open; unpinned, it collapses to its title bar
    -- when the mouse leaves. Crossed out while unpinned, so the state shows.
    { key = "pei_pinButton", spec = {
        icon = function(button) return button.parent.pin and "pin" or "pin-off" end,
        onClick = function(page) if page.pin then page:collapse() else page:setPinned() end end,
    } },
    -- Goes through the views; shows the one in use, as the pin shows its state.
    { key = "pei_viewToggleButton", hiddenCollapsed = true, spec = {
        icon = function(button)
            return VIEW_ICONS[ViewMode.viewOf(button.parent.inventoryPane)]
        end,
        onClick = function(page) PEI.ViewMode.cycle(page.inventoryPane) end,
    } },
}

local function isShown(button, collapsed)
    return not (collapsed and button.hiddenCollapsed)
end

-- Width of the buttons together (those of a collapsed window, when asked),
-- with the gap before what is beside them.
function TitleButtons.totalWidth(collapsed)
    local count = 0
    for _, button in ipairs(BUTTONS) do
        if isShown(button, collapsed) then count = count + 1 end
    end
    return count * (Theme.iconSize() + Theme.gap())
end

local function hideVanillaButtons(page)
    for _, key in ipairs({ "closeButton", "pinButton", "collapseButton", "infoButton" }) do
        if page[key] then Bounds.hide(page[key]) end
    end
end

-- Made once per window, placed every frame: the size, the padding and the
-- title's height can all change while it is open.
function TitleButtons.update(page)
    hideVanillaButtons(page)
    local size = Theme.iconSize()
    local padding = WindowMetrics.padding()
    local x = page:getWidth() - padding - size
    for _, button in ipairs(BUTTONS) do
        local control = IconButton.ensure(page, button.key, button.spec)
        if isShown(button, page.isCollapsed) then
            IconButton.place(control, x, padding, size)
            x = x - size - Theme.gap()
        else
            Bounds.hide(control)
        end
    end
end
