--[[
    Paravel's Enhanced Tooltips - generic tooltip

    The tooltips Lua draws itself (ISToolTip: buttons, context menu
    options, building...) in the theme: its window frame, the title in the
    theme's text colour, the foot note muted, and the description's rich
    text in the theme's colours for what each of its colours means
    (Paravel's UI, Theme/GameColors.lua). Tooltips that draw themselves
    another way (subclasses with a render of their own) are left as they
    are.
]]

require "ISUI/ISToolTip"
require "ParavelsEnhancedTooltips/Core/PET"
require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Draw/DrawOverrides"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/TooltipFrame"
require "ParavelsUI/Theme/GameColors"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local DrawOverrides = PUI.DrawOverrides
local GameColors = PUI.GameColors
local Text = PUI.Text
local Theme = PUI.Theme
local TooltipFrame = PUI.TooltipFrame

local Tooltip = PET.GenericTooltip or {}
PET.GenericTooltip = Tooltip

-- The only text vanilla's render draws itself is the title.
local function drawTitle(tooltip, text, x, y, r, g, b, a, font)
    Draw.text(tooltip, text, x, y, Theme.textColor(), 1, font)
end

-- And the only centred one, the foot note (how to rotate, for instance).
local function drawFootNote(tooltip, text, x, y, r, g, b, a, font)
    Draw.text(tooltip, text, x - Text.width(text, font) / 2, y, Theme.textColor(), Theme.mutedAlpha(), font)
end

local OVERRIDES = {
    drawRect = TooltipFrame.drawRect,
    drawRectBorder = TooltipFrame.drawRectBorder,
    drawText = drawTitle,
    drawTextCentre = drawFootNote,
}

-- The description's lines, each in its own colour, faded by the panel's
-- transparency.
local function drawDescriptionText(panel, text, x, y, r, g, b, a, font)
    local color, alpha = GameColors.themed(r, g, b)
    Draw.text(panel, text, x, y, color, alpha * a, font)
end

local function drawDescriptionTextRight(panel, text, x, y, r, g, b, a, font)
    drawDescriptionText(panel, text, x - Text.width(text, font), y, r, g, b, a, font)
end

local DESCRIPTION_OVERRIDES = {
    drawText = drawDescriptionText,
    drawTextRight = drawDescriptionTextRight,
}

PUI.override(ISToolTip, "render", function(vanilla, tooltip)
    -- The description panel is drawn from the tooltip's render.
    DrawOverrides.run(tooltip.descriptionPanel, DESCRIPTION_OVERRIDES, function()
        DrawOverrides.run(tooltip, OVERRIDES, vanilla)
    end)
end)
