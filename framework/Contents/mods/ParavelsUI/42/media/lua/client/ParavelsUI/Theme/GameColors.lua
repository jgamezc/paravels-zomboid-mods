--[[
    Paravel's UI - the game's colours in the theme

    The game colours text and bars by what they mean, with colours of its
    own: white or grey for plain text, its good and bad colours (which the
    player can change for colour blindness), pure red, green and orange in
    rich text, any RGB a tooltip asks for. GameColors.themed turns each
    into the theme's colour for that meaning, so what a mod restyles reads
    on any theme: the player's good and bad colours and anything green, red or
    orange become the theme's success, danger and warning; other hues its
    accent; greys its text colour, muted when dimmer than plain text.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/Theme"

local Color = PUI.Color
local Theme = PUI.Theme

local GameColors = PUI.GameColors or {}
PUI.GameColors = GameColors

-- Below this difference between its strongest and weakest channel, a colour
-- reads as a grey (vanilla's pinkish (1, 0.8, 0.8) menu text included).
local GREY_CHROMA = 0.25
-- Greys this light or lighter are plain text; darker ones are dimmed text.
local PLAIN_LIGHTNESS = 0.75

local function sameColor(r, g, b, color)
    return r == color:getR() and g == color:getG() and b == color:getB()
end

-- Whether r, g, b is the player's good or bad colour.
function GameColors.isGood(r, g, b)
    return sameColor(r, g, b, getCore():getGoodHighlitedColor())
end

function GameColors.isBad(r, g, b)
    return sameColor(r, g, b, getCore():getBadHighlitedColor())
end

-- The theme's colour for a hue (0 .. 360).
local function colorForHue(hue)
    if hue < 20 or hue >= 330 then return Theme.dangerColor() end
    if hue < 70 then return Theme.warningColor() end
    if hue < 170 then return Theme.successColor() end
    return Theme.accentColor()
end

-- The theme's colour and opacity for text the game draws in r, g, b.
function GameColors.themed(r, g, b)
    if GameColors.isGood(r, g, b) then return Theme.successColor(), 1 end
    if GameColors.isBad(r, g, b) then return Theme.dangerColor(), 1 end
    local hue, _, lightness = Color.toHsl({ r = r, g = g, b = b })
    if math.max(r, g, b) - math.min(r, g, b) >= GREY_CHROMA then return colorForHue(hue), 1 end
    if lightness >= PLAIN_LIGHTNESS then return Theme.textColor(), 1 end
    return Theme.textColor(), Theme.mutedAlpha()
end
