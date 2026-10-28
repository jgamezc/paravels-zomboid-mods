--[[
    Paravel's Enhanced Tooltips - the item tooltip

    The tooltip of an inventory item (ISToolTipInv) in the theme: its window
    frame, the item's name and the rows of what it says (Content/), drawn by
    Lua. For an item whose content is not rebuilt yet the game's Java code
    (InventoryItem:DoTooltip) still draws it, in colours of its own, light on
    dark, which Lua cannot restyle: in the theme's window frame, and, on a
    theme with a light background, inverted (the theme's text colour as the
    background) for that text to read.
]]

require "ISUI/ISToolTipInv"
require "ParavelsEnhancedTooltips/Content/Clothing"
require "ParavelsEnhancedTooltips/Content/Common"
require "ParavelsEnhancedTooltips/Content/Container"
require "ParavelsEnhancedTooltips/Content/Food"
require "ParavelsEnhancedTooltips/Content/Gadgets"
require "ParavelsEnhancedTooltips/Content/Literature"
require "ParavelsEnhancedTooltips/Content/Plain"
require "ParavelsEnhancedTooltips/Content/Weapon"
require "ParavelsEnhancedTooltips/Tooltip/Placement"
require "ParavelsUI/Core/Color"
require "ParavelsUI/Core/Look"
require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Draw/DrawOverrides"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/RowList"
require "ParavelsUI/Shapes/TooltipFrame"
require "ParavelsUI/Shapes/WindowFrame"
require "ParavelsUI/Theme/Theme"

local Common = PET.Common
local Draw = PUI.Draw
local DrawOverrides = PUI.DrawOverrides
local Placement = PET.Placement
local RowList = PUI.RowList
local Text = PUI.Text
local Theme = PUI.Theme
local TooltipFrame = PUI.TooltipFrame
local WindowFrame = PUI.WindowFrame

local ItemTooltip = PET.ItemTooltip or {}
PET.ItemTooltip = ItemTooltip

-- Who wants to know how each tooltip was drawn, by name.
ItemTooltip.drawnListeners = ItemTooltip.drawnListeners or {}

-- Calls `listener(tooltip, drawnByMod)` after every item tooltip is drawn:
-- `drawnByMod` is true when this mod drew it, false when the game's own code
-- did. Listening again under a name replaces its listener.
function ItemTooltip.listenDrawn(name, listener)
    ItemTooltip.drawnListeners[name] = listener
end

local function tellDrawn(tooltip, drawnByMod)
    for _, listener in pairs(ItemTooltip.drawnListeners) do listener(tooltip, drawnByMod) end
end

-- Set to draw every item tooltip with the game's own code, to compare.
ItemTooltip.forceGame = ItemTooltip.forceGame or false

-- With a context menu open the game draws no item tooltip.
local function isHiddenByContextMenu()
    return ISContextMenu.instance ~= nil and ISContextMenu.instance.visibleCheck
end

local function contextOf(tooltip)
    return { player = getPlayer(), weightOfStack = tooltip.tooltip:getWeightOfStack() }
end

-- The least width of a tooltip, as the game has it.
local DEFAULT_MIN_WIDTH = 150

-- What went wrong was already said (an error is written once to the log).
local reportedErrors = {}

local function reportOnce(where, problem)
    local line = where .. ": " .. tostring(problem)
    if reportedErrors[line] then return end
    reportedErrors[line] = true
    print("[PET] " .. line)
end

local function drawContent(tooltip, content)
    local layout = RowList.layout(content.rows)
    local padding = Theme.padding()
    local titleHeight = getTextManager():getFontHeight(UIFont.Small)
    local rowsY = padding + titleHeight + Theme.sectionGap()
    local width = math.max(Text.width(content.title), layout.width, content.minWidth or DEFAULT_MIN_WIDTH) + 2 * padding
    local height = rowsY + layout.height + padding
    Placement.place(tooltip, width, height)
    WindowFrame.drawBackground(tooltip, height)
    WindowFrame.drawOutline(tooltip, height)
    Draw.text(tooltip, content.title, padding, padding, Theme.textColor(), 1)
    RowList.draw(tooltip, padding, rowsY, layout, width - 2 * padding)
    tellDrawn(tooltip, true)
end

-- What the game's tooltip is drawn over: the theme's background, or its text
-- colour when the background is light.
local javaBackgroundColor = PUI.Look.derived(function()
    local background = Theme.backgroundColor()
    local _, _, lightness = PUI.Color.toHsl(background)
    if lightness > 0.5 then return Theme.textColor() end
    return background
end)

local function drawJavaBackground(tooltip, x, y, w, h, ...)
    if not TooltipFrame.coversWholeBox(tooltip, x, y, w) then return ISUIElement.drawRect(tooltip, x, y, w, h, ...) end
    Draw.roundedRect(tooltip, 0, 0, w, h, WindowFrame.radius(tooltip, h), javaBackgroundColor(), Theme.backgroundAlpha())
end

local JAVA_OVERRIDES = {
    drawRect = drawJavaBackground,
    drawRectBorder = TooltipFrame.drawRectBorder,
}

-- The content of the item, or nil when there is none to draw or building it
-- failed (then the game draws it).
local function contentOf(tooltip)
    if not tooltip.item or ItemTooltip.forceGame then return nil end
    local ok, content = pcall(Common.of, tooltip.item, contextOf(tooltip))
    if ok then return content end
    reportOnce("content of " .. tooltip.item:getFullType(), content)
    return nil
end

PUI.override(ISToolTipInv, "render", function(vanilla, tooltip)
    if isHiddenByContextMenu() then return end
    local content = contentOf(tooltip)
    if content then
        local ok, problem = pcall(drawContent, tooltip, content)
        if ok then return end
        reportOnce("drawing " .. tooltip.item:getFullType(), problem)
    end
    DrawOverrides.run(tooltip, JAVA_OVERRIDES, vanilla)
    tellDrawn(tooltip, false)
end)
