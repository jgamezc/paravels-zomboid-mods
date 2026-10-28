--[[
    Paravel's Enhanced Inventory - collapsed window

    A collapsed window is only its title bar (vanilla draws no more than that
    and opens the window when the mouse enters it). Here the bar keeps to what
    is worth reading at a glance: the name of the open container and, under
    it, the bar of how full it is, with the close and pin buttons on the
    right. The tabs and the view button stay out of sight until the window
    opens (Window/WindowTabs.lua, Window/TitleButtons.lua).

        +--------------------------------------------------+
        | Container name                           pin  x  |
        | [capacity bar=========                         ] |
        +--------------------------------------------------+
]]

require "ParavelsEnhancedInventory/Inventory/Window/WindowMetrics"
require "ParavelsEnhancedInventory/Inventory/Window/OpenTab"
require "ParavelsEnhancedInventory/Inventory/Window/TitleButtons"
require "ParavelsEnhancedInventory/Inventory/Window/Footer"
require "ParavelsUI/Shapes/ProgressBar"
require "ParavelsUI/Draw/Text"

local Draw = PUI.Draw
local Footer = PEI.Footer
local OpenTab = PEI.OpenTab
local ProgressBar = PUI.ProgressBar
local Text = PUI.Text
local Theme = PUI.Theme
local TitleButtons = PEI.TitleButtons
local WindowMetrics = PEI.WindowMetrics

local CollapsedBar = PEI.CollapsedBar or {}
PEI.CollapsedBar = CollapsedBar

-- The row of the name and the buttons is as tall as the buttons.
local function rowHeight()
    return Theme.iconSize()
end

-- The padding, the row, the bar (with its gap above) and the padding.
function CollapsedBar.height()
    local height = WindowMetrics.padding() * 2 + rowHeight()
    local barHeight = ProgressBar.height()
    if barHeight > 0 then height = height + Theme.halfGap() + barHeight end
    return height
end

-- The name of the open container: the open tab's, as it says it on hover.
local function containerName(page)
    for _, button in ipairs(page.backpacks or {}) do
        if button.name and OpenTab.isSelected(page, button) then return button.name end
    end
    return page.title
end

function CollapsedBar.draw(page)
    if not page.isCollapsed then return end
    local padding = WindowMetrics.padding()
    local name = containerName(page)
    if name then
        local room = page:getWidth() - padding * 2 - TitleButtons.totalWidth(true)
        Draw.text(page, Text.fit(name, room, UIFont.Small), padding,
            padding + Text.yCentredIn(rowHeight(), UIFont.Small), Theme.textColor(), 1, UIFont.Small)
    end
    local full = Footer.fullness(page)
    if ProgressBar.height() > 0 and full then
        ProgressBar.draw(page, padding, padding + rowHeight() + Theme.halfGap(), page:getWidth() - padding * 2, full,
            Theme.fullnessColor(full))
    end
end
