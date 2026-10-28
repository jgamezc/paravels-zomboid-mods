--[[
    Paravel's Enhanced Tooltips - the game's texts

    How the game writes the numbers and labels of a tooltip.
]]

require "ParavelsEnhancedTooltips/Core/PET"

local Format = PET.Format or {}
PET.Format = Format

-- A number to two decimals with at least one, like Java's float to text.
function Format.number(value)
    local text = string.format("%.2f", math.floor(value * 100 + 0.5) / 100)
    return (text:gsub("0$", ""))
end

-- A number the way Java writes a float: a whole one keeps a ".0".
function Format.javaFloat(value)
    if value == math.floor(value) then return string.format("%d.0", value) end
    return tostring(value)
end

-- A weight: tiny ones show as 0.01.
function Format.weight(weight)
    if weight > 0 and weight < 0.01 then weight = 0.01 end
    return Format.number(weight)
end

-- A change as a whole signed number: "+5", "0", "-5" (cut toward zero).
function Format.signed(value)
    local whole = value >= 0 and math.floor(value) or -math.floor(-value)
    if whole > 0 then return "+" .. whole end
    return tostring(whole)
end

-- The label of a row: a translated text and a colon.
function Format.label(key)
    return getText(key) .. ":"
end
