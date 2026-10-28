--[[
    Paravel's Enhanced Inventory - inventory window measures

    Measures shared by the parts of the themed inventory window (the
    ISInventoryPage around a pane): title buttons, tabs, footer and the
    window itself (Window/Window.lua).

        +--------------------------------------------------+
        | < [tab] [tab  name] [tab] >        view  pin  x  |  title bar (WindowTabs, TitleButtons)
        |------        ------------------------------------|  divider, open under the selected tab
        | pane: list or grid                               |
        |                                                  |
        | (w) 12.4 / 30                 transfers sort grip|  footer (Footer, TransferButtons)
        |     [capacity bar======    ]                     |
        +--------------------------------------------------+
]]

require "ParavelsEnhancedInventory/Core/PEI"
require "ParavelsUI/Theme/Theme"

local Theme = PUI.Theme

local WindowMetrics = PEI.WindowMetrics or {}
PEI.WindowMetrics = WindowMetrics

-- Space between the window's border and everything inside it: the tabs, the
-- pane and the footer.
function WindowMetrics.padding()
    return Theme.padding()
end

-- Where the pane ends, which is where the footer begins.
function WindowMetrics.paneBottom(page)
    local pane = page.inventoryPane
    return pane:getY() + pane:getHeight()
end
