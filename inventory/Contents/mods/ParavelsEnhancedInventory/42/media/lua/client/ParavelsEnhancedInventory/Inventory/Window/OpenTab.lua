--[[
    Paravel's Enhanced Inventory - which tab is open

    Two tabs share their container with another tab: the equipped tab
    (Window/EquippedTab.lua) the player's inventory, and the proximity tab
    (Window/ProximityTab.lua) the floor. Vanilla tells containers apart by
    their ItemContainer alone, so which kind of tab the player opened is
    kept here, one value per window (page.pei_openTab): OpenTab.CONTAINER
    (a container's own tab), OpenTab.EQUIPPED or OpenTab.PROXIMITY. The
    player chooses it (Window/TabSelection.lua), and the proximity tab takes
    it back when the container picked instead is gone. The loot window
    starts on the proximity tab, the player's on its containers.

    Each shared tab keeps its button on the page by kind (OpenTab.addButton);
    every other button is a container's own tab. The kind chosen shows while the pane lists that
    button's container; on any other container, its own tab is the open one.
]]

require "ParavelsEnhancedInventory/Core/PEI"

local OpenTab = PEI.OpenTab or {}
PEI.OpenTab = OpenTab

OpenTab.CONTAINER = "container"
OpenTab.EQUIPPED = "equipped"
OpenTab.PROXIMITY = "proximity"

function OpenTab.kindOf(page, button)
    for kind, tabButton in pairs(page.pei_tabButtons or {}) do
        if tabButton == button then return kind end
    end
    return OpenTab.CONTAINER
end

-- Makes `button` the page's tab of `kind`. Vanilla reuses its buttons from
-- a pool, so it is taken off (OpenTab.removeButton) whenever the tabs are
-- made again.
function OpenTab.addButton(page, kind, button)
    page.pei_tabButtons = page.pei_tabButtons or {}
    page.pei_tabButtons[kind] = button
end

function OpenTab.removeButton(page, kind)
    if page.pei_tabButtons then page.pei_tabButtons[kind] = nil end
end

-- The page's tab of `kind`, when it has one now.
function OpenTab.buttonOf(page, kind)
    return page.pei_tabButtons and page.pei_tabButtons[kind]
end

function OpenTab.chosen(page)
    return page.pei_openTab or (page.onCharacter and OpenTab.CONTAINER or OpenTab.PROXIMITY)
end

function OpenTab.choose(page, kind)
    page.pei_openTab = kind
end

-- The kind of tab the pane shows: the one chosen, while the pane lists its
-- button's container.
function OpenTab.shown(page)
    local kind = OpenTab.chosen(page)
    if kind == OpenTab.CONTAINER then return kind end
    local button = OpenTab.buttonOf(page, kind)
    local pane = page.inventoryPane
    if button and pane and pane.inventory == button.inventory then return kind end
    return OpenTab.CONTAINER
end

-- Whether `button` is the open tab.
function OpenTab.isSelected(page, button)
    return button.inventory == page.inventoryPane.inventory and OpenTab.kindOf(page, button) == OpenTab.shown(page)
end
