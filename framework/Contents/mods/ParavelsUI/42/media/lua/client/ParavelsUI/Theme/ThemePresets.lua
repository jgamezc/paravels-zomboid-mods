--[[
    Paravel's UI - theme presets

    Whole looks a player picks from, one file each in Theme/Themes/. Each
    preset gives every token of Theme.TOKENS (Theme/Theme.lua) its own
    value, and nothing else: no preset is the reference for the others and
    none inherits from another, so a new token is decided in each of them.
    A choice token is set by name. `npm run check` fails when one is
    missing, unknown or not one of its choices.

    ThemePresets.ORDER is the order the player sees them in. The player's
    choice is saved as a position in it, so a new theme goes last and none
    is moved. Its name shows as IGUI_PUI_Theme_<id>. The first one is in
    use until the player's choice is read. Theme.apply(id) makes one the
    theme in use.
]]

require "ParavelsUI/Core/PUI"

local ThemePresets = PUI.ThemePresets or {}
PUI.ThemePresets = ThemePresets

ThemePresets.ORDER = { "Ruin", "Classic", "Glass", "Military", "Terminal", "Legible", "Vivid", "Neon", "Paper", "Snow" }

-- Each preset's values by id, as its file defines them.
ThemePresets.byId = ThemePresets.byId or {}

function ThemePresets.define(id, values)
    ThemePresets.byId[id] = values
end

local THEMES_FOLDER = "ParavelsUI/Theme/Themes/"

-- The files of every theme in ORDER, so all are defined before one is
-- applied.
function ThemePresets.loadAll()
    for _, id in ipairs(ThemePresets.ORDER) do require(THEMES_FOLDER .. id) end
end

function ThemePresets.names()
    local names = {}
    for i, id in ipairs(ThemePresets.ORDER) do names[i] = "IGUI_PUI_Theme_" .. id end
    return names
end
