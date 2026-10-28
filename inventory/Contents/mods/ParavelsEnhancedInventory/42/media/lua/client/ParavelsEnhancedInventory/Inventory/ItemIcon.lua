--[[
    Paravel's Enhanced Inventory - item icon layers

    The framework's icon layers (Paravel's UI, Shapes/IconLayers.lua) under an
    item's icon, a halo and a shadow, as the player's options say: whether
    each is shown and how strong the halo is. The grid, the list and the
    container tabs all use them, so an icon looks the same everywhere. The
    marks drawn over an icon (the upgrade mark, a skill book's volume) and
    the outline that keeps them readable are here too, for the same reason.
]]

require "ISUI/ISInventoryItem"
require "ParavelsUI/Core/Look"
require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/IconLayers"
require "ParavelsUI/Theme/Theme"
require "ParavelsEnhancedInventory/Inventory/Families"
require "ParavelsEnhancedInventory/Inventory/Options"
require "ParavelsEnhancedInventory/Inventory/Upgrade"

local Draw = PUI.Draw
local Families = PEI.Families
local IconLayers = PUI.IconLayers
local Options = PEI.Options
local Text = PUI.Text
local Theme = PUI.Theme
local Upgrade = PEI.Upgrade

local ItemIcon = PEI.ItemIcon or {}
PEI.ItemIcon = ItemIcon

-- The game's DrawItemIcon (Java) draws most icons with DrawTextureScaledAspect:
-- the texture's trimmed opaque part, scaled evenly to fit and centred. Items
-- with a fluid mask go through DrawTextureIcon instead, which keeps the
-- part's own offset in the texture. Same test as the game's.
function ItemIcon.usesFluidMask(item)
    if not item:getTextureFluidMask() then return false end
    if item:getFluidContainer() then return true end
    local worldItem = item:getWorldItem()
    return worldItem ~= nil and worldItem:getFluidContainer() ~= nil
end

-- The halo behind an icon of iconSize at x, y, when the player shows it, as
-- strong as the player sets it next to the theme's glow. It keeps the grid
-- cell's size relative to its icon, so in a grid cell it fills the cell
-- exactly and an icon in a list row or a tab looks the same.
function ItemIcon.drawHalo(element, x, y, iconSize, alpha)
    if not Options.get("showIconHalo") then return end
    IconLayers.drawHalo(element, x, y, iconSize, Options.gridCellSize() / Options.gridIconSize(),
        alpha * Options.get("iconHaloIntensity") / 100)
end

-- The icon's shadow, when the player shows it. `drawnAsFluidIcon` follows
-- ItemIcon.usesFluidMask.
function ItemIcon.drawShadow(element, texture, x, y, iconSize, alpha, drawnAsFluidIcon)
    if not Options.get("showIconShadow") then return end
    IconLayers.drawShadow(element, texture, x, y, iconSize, alpha, drawnAsFluidIcon and "icon" or "aspect")
end

-- Halo and shadow for an inventory item's icon.
function ItemIcon.drawLayers(element, item, x, y, iconSize, alpha)
    ItemIcon.drawHalo(element, x, y, iconSize, alpha)
    ItemIcon.drawShadow(element, item:getTex(), x, y, iconSize, alpha, ItemIcon.usesFluidMask(item))
end

-- The icon itself, drawn by vanilla's ISInventoryItem.renderItemIcon.
function ItemIcon.drawIcon(element, item, x, y, iconSize, alpha)
    ISInventoryItem.renderItemIcon(element, item, x, y, alpha, iconSize, iconSize)
end

-- ------------------------------------------------------------------ --
-- Marks over the icon
-- ------------------------------------------------------------------ --

-- Offsets of the shadow-coloured copies that keep a mark or text readable
-- over an icon of any colour, as the theme says (Theme.textOnImage): none
-- (nil), one copy, or copies all around. The game has no bold at this size
-- (its bold fonts are SDF fonts, over twice as tall as Small, and blur when
-- scaled down), so bold is the digits drawn twice, one pixel apart; the
-- outline then reaches one pixel further right.
local OUTLINE_PLAIN = {
    { -1, -1 }, { 0, -1 }, { 1, -1 },
    { -1, 0 },             { 1, 0 },
    { -1, 1 },  { 0, 1 },  { 1, 1 },
}
local OUTLINE_BOLD = {
    { -1, -1 }, { 0, -1 }, { 1, -1 }, { 2, -1 },
    { -1, 0 },                        { 2, 0 },
    { -1, 1 },  { 0, 1 },  { 1, 1 },  { 2, 1 },
}

function ItemIcon.outlineOffsets(isBold)
    local textOnImage = Theme.textOnImage()
    if textOnImage == "outline" then
        return isBold and OUTLINE_BOLD or OUTLINE_PLAIN
    elseif textOnImage == "shadow" then
        local offset = math.max(1, Theme.shadowOffset())
        local offsets = { { offset, offset } }
        if isBold then offsets[2] = { offset + 1, offset } end
        return offsets
    end
    return nil
end

local UPGRADE_MARK = "chevron-up"
local VOLUME_FONT = UIFont.Small
local ROMAN_NUMERALS = { "I", "II", "III", "IV", "V" }

-- The marks' theme, made again only when the theme changes.
local currentMark = PUI.Look.derived(function()
    return {
        size = Theme.smallIconSize(),
        upgradeColor = Theme.successColor(),
        volumeColor = Theme.textColor(),
        shadowColor = Theme.shadowColor(),
        shadowAlpha = Theme.shadowAlpha(),
        outline = ItemIcon.outlineOffsets(false),
    }
end)

-- Draws `drawAt(x, y, color, alpha)` once per outline copy, then in `color`.
local function drawOutlined(mark, x, y, color, alpha, drawAt)
    if mark.outline then
        for _, offset in ipairs(mark.outline) do
            drawAt(x + offset[1], y + offset[2], mark.shadowColor, mark.shadowAlpha * alpha)
        end
    end
    drawAt(x, y, color, alpha)
end

-- The mark for gear better than the player's (Inventory/Upgrade.lua): a
-- chevron pointing up in the theme's success colour, outlined like any mark
-- over an icon, with its top right corner at `right`, `top`.
local function drawUpgradeMark(element, right, top, alpha)
    local mark = currentMark()
    drawOutlined(mark, right - mark.size, top, mark.upgradeColor, alpha, function(x, y, color, markAlpha)
        Draw.icon(element, UPGRADE_MARK, x, y, mark.size, color, markAlpha)
    end)
end

-- The mark for a skill book's volume (Families.skillVolume): a Roman numeral
-- in the theme's text colour, outlined like any mark over an icon. It takes
-- the upgrade mark's place (no item is both gear and a book): the numeral's
-- letters are centred in the box that mark's chevron fills, whose top right
-- corner is at `right`, `top`, so the two look to be in the same spot.
local function drawVolumeMark(element, right, top, volume, alpha)
    local mark = currentMark()
    local text = ROMAN_NUMERALS[volume] or tostring(volume)
    local width = Text.width(text, VOLUME_FONT)
    -- Never past `right`, where a numeral wider than the box would stick out.
    local x = math.min(right - math.floor((mark.size + width) / 2), right - width)
    local y = top + Text.yCentredIn(mark.size, VOLUME_FONT)
    drawOutlined(mark, x, y, mark.volumeColor, alpha, function(textX, textY, color, markAlpha)
        Draw.text(element, text, textX, textY, color, markAlpha, VOLUME_FONT)
    end)
end

-- The mark of an icon's top right corner, at `right`, `top`: the upgrade mark
-- for gear better than the player's, or a skill book's volume, as `style`
-- (showUpgradeMark, showVolumeMark) allows. `upgrades` is an
-- Upgrade.newReference of the player.
function ItemIcon.drawCornerMark(element, style, upgrades, item, right, top, alpha)
    if style.showUpgradeMark and Upgrade.isBetter(upgrades, item) then
        return drawUpgradeMark(element, right, top, alpha)
    end
    local volume = style.showVolumeMark and Families.skillVolume(item)
    if volume then drawVolumeMark(element, right, top, volume, alpha) end
end
