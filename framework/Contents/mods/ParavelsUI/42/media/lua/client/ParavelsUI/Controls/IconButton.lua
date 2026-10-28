--[[
    Paravel's UI - icon buttons

    Every themed button is an ISButton drawn as a Lucide icon in the theme's
    text colour, muted until hovered. What a button is lives in a spec, a
    table defined once at file level:

        local CLOSE_BUTTON = {
            icon = "x",                      -- or function(button) -> name
            iconSize = Theme.smallIconSize,  -- optional; fills the button when nil
            onClick = function(target, button) target:close() end,
            tooltip = "IGUI_MyMod_Sort",     -- optional translation key
            render = nil,                    -- optional function(button, spec): own drawing
        }

    IconButton.ensure(parent, key, spec) makes the button once (kept in
    parent[key]) and applies the spec whenever it is not the one the button
    already has. Running a file again re-creates its spec tables, so buttons made
    before it pick up the new code by themselves. Buttons are placed every
    frame by their owner (IconButton.place or Bounds.hide), so they follow
    size changes.
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Theme/Theme"
require "ParavelsUI/Controls/Bounds"

local Bounds = PUI.Bounds
local Theme = PUI.Theme
local Draw = PUI.Draw

local IconButton = PUI.IconButton or {}
PUI.IconButton = IconButton

local function iconName(button)
    local icon = button.pui_spec.icon
    if type(icon) == "function" then return icon(button) end
    return icon
end

-- The icon, centred, at the spec's size or as big as the button.
function IconButton.drawIcon(button)
    local spec = button.pui_spec
    local w, h = button:getWidth(), button:getHeight()
    local size = math.min(spec.iconSize and spec.iconSize() or w, w, h)
    Draw.icon(button, iconName(button), math.floor((w - size) / 2), math.floor((h - size) / 2),
        size, Theme.textColor(), Theme.interactiveAlpha(button:isMouseOver()))
end

-- What ISButton's render does besides drawing, for any button whose render
-- is replaced: tell the target the mouse is over it (vanilla's transfer
-- buttons light up the items they move, its container buttons the
-- container in the world).
function IconButton.keepVanillaRenderEffects(button)
    if button.mouseOver and button.onmouseover then
        button.onmouseover(button.target, button, button:getMouseX(), button:getMouseY())
    end
end

function IconButton.render(button)
    local spec = button.pui_spec
    if spec.render then spec.render(button, spec) else IconButton.drawIcon(button) end
    IconButton.keepVanillaRenderEffects(button)
end

-- No background or border; ISButton's prerender also shows the tooltip.
function IconButton.prerender(button)
    button:updateTooltip()
end

local function applyLook(button, spec)
    button.pui_spec = spec
    button.prerender = IconButton.prerender
    button.render = IconButton.render
    if spec.tooltip then button.tooltip = getText(spec.tooltip) end
end

-- Gives a button the game made (keeping its click) the look of an icon button.
function IconButton.restyle(button, spec)
    if button and button.pui_spec ~= spec then applyLook(button, spec) end
end

-- parent[key], made on the first call, with `spec`. Clicks go to
-- spec.onClick(target, button), the target being `target` or the parent.
function IconButton.ensure(parent, key, spec, target)
    local button = parent[key]
    if not button then
        button = ISButton:new(0, 0, 1, 1, "", parent, nil)
        button:initialise()
        parent:addChild(button)
        parent[key] = button
    end
    if button.pui_spec ~= spec then
        applyLook(button, spec)
        button.onclick = function(clickTarget, clicked) clicked.pui_spec.onClick(clickTarget, clicked) end
    end
    button.target = target or parent
    return button
end

-- Shows the button as a size x size square (or size x height) at x, y.
function IconButton.place(button, x, y, size, height)
    Bounds.show(button, x, y, size, height or size)
end
