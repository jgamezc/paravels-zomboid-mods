--[[
    Paravel's UI - colours

    Colours are { r, g, b, a } tables, each channel 0..1. Color.rgb makes
    one; Color.toHsl reads its hue, saturation and lightness; Color.adjust
    moves its lightness and saturation by a number of points, which is how
    the theme derives an accent from its fill (Theme.accentOf); Color.mix
    blends two of them.
]]

require "ParavelsUI/Core/PUI"

local Color = PUI.Color or {}
PUI.Color = Color

-- An opaque colour. A new table.
function Color.rgb(r, g, b)
    return { r = r, g = g, b = b, a = 1 }
end

-- Hue (0 .. 360), saturation and lightness (0 .. 1) of `color`.
function Color.toHsl(color)
    local r, g, b = color.r, color.g, color.b
    local high, low = math.max(r, g, b), math.min(r, g, b)
    local lightness = (high + low) / 2
    if high == low then return 0, 0, lightness end
    local chroma = high - low
    local saturation = chroma / (1 - math.abs(2 * lightness - 1))
    local hue
    if high == r then hue = math.fmod((g - b) / chroma + 6, 6)
    elseif high == g then hue = (b - r) / chroma + 2
    else hue = (r - g) / chroma + 4 end
    return hue * 60, saturation, lightness
end

local function hslToRgb(hue, saturation, lightness)
    local chroma = (1 - math.abs(2 * lightness - 1)) * saturation
    local sector = hue / 60
    local x = chroma * (1 - math.abs(math.fmod(sector, 2) - 1))
    local r, g, b
    if sector < 1 then r, g, b = chroma, x, 0
    elseif sector < 2 then r, g, b = x, chroma, 0
    elseif sector < 3 then r, g, b = 0, chroma, x
    elseif sector < 4 then r, g, b = 0, x, chroma
    elseif sector < 5 then r, g, b = x, 0, chroma
    else r, g, b = chroma, 0, x end
    local m = lightness - chroma / 2
    return Color.rgb(r + m, g + m, b + m)
end

-- `color` with `lightness` and `saturation` (-1 .. 1) added to its own,
-- each kept within 0 .. 1. A new table.
function Color.adjust(color, lightness, saturation)
    local h, s, l = Color.toHsl(color)
    return hslToRgb(h, PUI.clamp(s + saturation, 0, 1), PUI.clamp(l + lightness, 0, 1))
end

-- The colour `fraction` (0 .. 1) of the way from `from` to `to`. A new table.
function Color.mix(from, to, fraction)
    fraction = PUI.clamp(fraction, 0, 1)
    return Color.rgb(
        from.r + (to.r - from.r) * fraction,
        from.g + (to.g - from.g) * fraction,
        from.b + (to.b - from.b) * fraction)
end
