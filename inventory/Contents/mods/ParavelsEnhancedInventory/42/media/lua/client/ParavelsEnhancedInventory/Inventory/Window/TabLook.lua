--[[
    Paravel's Enhanced Inventory - how the container tabs look

    Each tab shows its container's icon at its pixel-exact size, with the
    grid's halo and shadow; the selected one also shows the container's
    name. Hovered tabs get the theme's hover wash, and every tab its outline,
    rounded on top. Where the tabs go is Window/WindowTabs.lua's.
]]

require "ISUI/ISInventoryPage"
require "ParavelsEnhancedInventory/Inventory/Window/WindowTabs"
require "ParavelsEnhancedInventory/Inventory/Window/OpenTab"
require "ParavelsEnhancedInventory/Inventory/ItemIcon"
require "ParavelsUI/Controls/IconButton"
require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Shapes/Line"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local IconButton = PUI.IconButton
local ItemIcon = PEI.ItemIcon
local Line = PUI.Line
local OpenTab = PEI.OpenTab
local Text = PUI.Text
local Theme = PUI.Theme
local WindowTabs = PEI.WindowTabs

local TabLook = PEI.TabLook or {}
PEI.TabLook = TabLook

local TAB_SIDES = { top = true, left = true, right = true }

-- A tab's icon, at the left at its pixel-exact size, with the grid's halo
-- and shadow, and the selected tab's name after it. What vanilla's render
-- does besides (the lock mark over a locked container, the mouse-over
-- callback that highlights the container in the world) is kept.
function TabLook.renderTab(button)
    local page = button.parent and button.parent.parent
    if not (page and page.inventoryPane) then return end
    local padX, iconSize, h = WindowTabs.padX(), WindowTabs.iconSize(), button:getHeight()
    local iconY = math.floor((h - iconSize) / 2)
    if button.image then
        local isActive = OpenTab.isSelected(page, button) or button:isMouseOver()
        local alpha = isActive and 1 or Theme.mutedAlpha()
        ItemIcon.drawHalo(button, padX, iconY, iconSize, alpha)
        ItemIcon.drawShadow(button, button.image, padX, iconY, iconSize, alpha, false)
        Draw.texture(button, button.image, padX, iconY, iconSize, iconSize, Draw.UNTINTED, alpha, "aspect")
    end
    if button.pei_name then
        Draw.text(button, button.pei_name, padX + iconSize + Theme.gap(), Text.yCentredIn(h, UIFont.Small),
            Theme.textColor(), 1, UIFont.Small)
    end
    local lock = button.textureOverride
    if lock then
        local lockW, lockH = lock:getWidth(), lock:getHeight()
        Draw.texture(button, lock, padX + iconSize / 2 - lockW / 2, iconY + iconSize / 2 - lockH / 2, lockW, lockH,
            Draw.UNTINTED, 1, "scaled")
    end
    IconButton.keepVanillaRenderEffects(button)
end

-- Every tab is a container button, made (or taken from vanilla's pool) here:
-- it draws its own icon and name, and none of ISButton's background, which
-- the tab's hover wash replaces. Vanilla sets neither again.
PUI.override(ISInventoryPage, "addContainerButton", function(vanilla, page, ...)
    local button = vanilla(page, ...)
    button.displayBackground = false
    button.render = TabLook.renderTab
    return button
end)

-- Each tab's hover wash and outline, behind its button. The selected tab is
-- left as the window's own background, like the pane below it (the
-- header's tint is cut around it, Window/Window.lua). Rounded on top only:
-- the bottom sits on the divider, which the outline joins into one line.
PUI.override(ISInventoryPageContainerButtonPanel, "prerender", function(vanilla, column)
    vanilla(column)
    local page = column.parent
    if not (page and page.inventoryPane and page.backpacks) then return end
    for _, button in ipairs(page.backpacks) do
        -- A tab scrolled out of sight draws nothing.
        if button:getIsVisible() then
            local x, y, w, h = button:getX(), button:getY(), button:getWidth(), button:getHeight()
            local radius = Draw.fitRadius(Theme.smallRadius(), w, h)
            if button:isMouseOver() and not OpenTab.isSelected(page, button) then
                local hoverAlpha = Theme.hoverAlpha()
                if hoverAlpha > 0 then
                    Draw.roundedRect(column, x, y, w, h, radius, Theme.textColor(), hoverAlpha, Draw.TOP_CORNERS)
                end
            end
            Line.outline(column, x, y, w, h, radius, Draw.TOP_CORNERS, TAB_SIDES)
        end
    end
end)
