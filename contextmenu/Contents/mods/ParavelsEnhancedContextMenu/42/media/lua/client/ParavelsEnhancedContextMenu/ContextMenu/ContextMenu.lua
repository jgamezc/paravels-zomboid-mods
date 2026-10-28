--[[
    Paravel's Enhanced Context Menu - context menu

    The right-click menus (ISContextMenu, submenus included) in the theme:
    the window frame around them, the hovered option as a rounded fill,
    options' text in the theme's colours (Paravel's UI,
    Theme/GameColors.lua: muted when disabled, success and danger where
    the game marks them good or bad) and Lucide icons in place of
    vanilla's "<" and ">" marks, its tick and its scroll arrows. The options' own icons stay as they are.

    The options sit inside a margin, so their icons and the hovered fill
    keep clear of the frame: vanilla lays them out from the menu's edges,
    so its content is drawn moved in by the margin, the menu is made that
    much wider (its width is set again on every render) and higher (its own
    padTopBottom), and its submenus are moved out to its new edge.

    Vanilla's render is kept: while it runs, its draw calls are swapped
    (Paravel's UI, Draw/DrawOverrides.lua) and each is recognised by where
    it draws and in what colour.
]]

require "ISUI/ISContextMenu"
require "ParavelsEnhancedContextMenu/Core/PECM"
require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Draw/DrawOverrides"
require "ParavelsUI/Shapes/Line"
require "ParavelsUI/Shapes/WindowFrame"
require "ParavelsUI/Theme/GameColors"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local DrawOverrides = PUI.DrawOverrides
local GameColors = PUI.GameColors
local Line = PUI.Line
local Theme = PUI.Theme
local WindowFrame = PUI.WindowFrame

local ContextMenu = PECM.ContextMenu or {}
PECM.ContextMenu = ContextMenu

-- ------------------------------------------------------------------ --
-- Margins
-- ------------------------------------------------------------------ --

-- Between the frame and a hovered option's fill, on every side.
local function rowInset()
    return Theme.halfGap()
end

-- Between the frame and the options' content (icons, text, marks), on
-- each side: inside the hovered fill by as much again.
local function sideMargin()
    return rowInset() * 2
end

-- ------------------------------------------------------------------ --
-- Marks
-- ------------------------------------------------------------------ --

-- Marks take the place of a line of the menu's text.
local function markSize(menu)
    return menu.fontHgt
end

-- vanilla's text y is the top of the line; the mark fills the line.
local function drawMark(menu, name, x, y, r, g, b)
    local color, alpha = GameColors.themed(r, g, b)
    Draw.icon(menu, name, x, y, markSize(menu), color, alpha)
end

-- ------------------------------------------------------------------ --
-- Draw overrides for vanilla's render
-- ------------------------------------------------------------------ --

local function isWhite(r, g, b) return r == 1 and g == 1 and b == 1 end

-- The bands at the top and bottom that hold the scroll arrows, when the
-- options do not fit.
local function isScrollBand(menu, y)
    local top = -menu:getYScroll()
    return y == top or y == top + menu.height - menu.scrollIndicatorHgt
end

-- An option's row: the hovered one, or one blinking to draw the eye (in
-- white, at the blink's opacity).
local function drawRow(menu, y, a, r, g, b)
    local alpha = isWhite(r, g, b) and a * Theme.selectedAlpha() or Theme.hoverAlpha()
    if alpha <= 0 then return end
    local inset = rowInset()
    Draw.roundedRect(menu, inset, y, menu.width - inset * 2, menu.itemHgt, Theme.smallRadius(), Theme.textColor(), alpha)
end

-- Vanilla's rectangles, by size: the line under the default options, the
-- scroll bands (left out), the rows, the background, and the column
-- behind the options' icons (left out).
local function drawRect(menu, x, y, w, h, a, r, g, b)
    if h == 1 then return Line.draw(menu, rowInset(), y, menu.width - rowInset() * 2, h) end
    if w ~= menu.width then return end
    if h == menu.scrollIndicatorHgt and isScrollBand(menu, y) then return end
    if h == menu.itemHgt then return drawRow(menu, y, a, r, g, b) end
    WindowFrame.drawBackground(menu, h, y)
end

-- The outline around the background, which vanilla draws without the
-- scroll offset it gives the background.
local function drawRectBorderStatic(menu, x, y, w, h)
    WindowFrame.drawOutline(menu, h, y - menu:getYScroll())
end

-- An option's name, or the "<" in front of the default options.
local function drawText(menu, text, x, y, r, g, b, a, font)
    x = x + sideMargin()
    if text == "<" then return drawMark(menu, "chevron-left", x, y, r, g, b) end
    local color, alpha = GameColors.themed(r, g, b)
    Draw.text(menu, text, x, y, color, alpha, font)
end

-- The ">" of an option with a submenu, its right edge at x.
local function drawTextRight(menu, text, x, y, r, g, b)
    drawMark(menu, "chevron-right", x - sideMargin() - markSize(menu), y, r, g, b)
end

-- The tick of a checked option, in the colour vanilla gives it (the good
-- one); any other texture is an option's own icon, already moved in
-- (renderOptionTextureOrColor below).
local function drawTextureScaledAspect(menu, texture, x, y, w, h, a, r, g, b)
    if texture ~= menu.tickTexture then
        return ISUIElement.drawTextureScaledAspect(menu, texture, x, y, w, h, a, r, g, b)
    end
    local color = GameColors.themed(r, g, b)
    Draw.icon(menu, "check", x + sideMargin(), y, math.min(w, h), color, a)
end

-- Vanilla draws three arrows across each scroll band; one chevron in its
-- middle takes their place.
local ARROW_SPACING = 14
local function drawTexture(menu, texture, x, y, ...)
    if texture ~= menu.arrowUp and texture ~= menu.arrowDown then
        return ISUIElement.drawTexture(menu, texture, x, y, ...)
    end
    local middleX = menu.width / 2 - ARROW_SPACING / 2
    if x ~= middleX then return end
    local size = menu.scrollIndicatorHgt
    local name = texture == menu.arrowUp and "chevron-up" or "chevron-down"
    Draw.icon(menu, name, math.floor((menu.width - size) / 2), y, size, Theme.textColor(), Theme.mutedAlpha())
end

local OVERRIDES = {
    drawRect = drawRect,
    drawRectBorder = DrawOverrides.skip,  -- the hovered row's border: the fill marks it
    drawRectBorderStatic = drawRectBorderStatic,
    drawText = drawText,
    drawTextRight = drawTextRight,
    drawTexture = drawTexture,
    drawTextureScaledAspect = drawTextureScaledAspect,
}

-- ------------------------------------------------------------------ --
-- Size and placement with the margins
-- ------------------------------------------------------------------ --

-- Vanilla places a submenu at its own edge, without the margins; one on
-- this menu's right is moved out to the new edge.
local function moveSubMenuOut(menu)
    local subMenu = menu.subMenu
    if subMenu and subMenu:isVisible() and subMenu:getX() > menu:getX() then
        subMenu:setX(menu:getX() + menu:getWidth() + 1)
    end
end

-- Vanilla's render sets the menu's width for its content; the margins are
-- added afterwards, also to the option's rect that tooltips keep clear of.
local function widenByMargins(menu)
    menu:setWidth(menu:getWidth() + sideMargin() * 2)
    if menu.currentOptionRect then menu.currentOptionRect.width = menu:getWidth() end
    moveSubMenuOut(menu)
end

PUI.override(ISContextMenu, "render", function(vanilla, menu)
    DrawOverrides.run(menu, OVERRIDES, vanilla)
    widenByMargins(menu)
end)

-- The width vanilla asks for to place a submenu on the left.
PUI.override(ISContextMenu, "calcWidth", function(vanilla, menu)
    return vanilla(menu) + sideMargin() * 2
end)

PUI.override(ISContextMenu, "calcHeight", function(vanilla, menu)
    menu.padTopBottom = rowInset()
    return vanilla(menu)
end)

PUI.override(ISContextMenu, "renderOptionTextureOrColor", function(vanilla, menu, option, x, y, w, h)
    return vanilla(menu, option, x + sideMargin(), y, w, h)
end)
