--[[
    Paravel's UI - the player's theme

    The theme is chosen once for every mod built on the framework: the
    framework's own entry on the Mods options page ("Paravel's UI") lists
    the presets (Theme/ThemePresets.lua, Theme/Themes/), and the one picked is applied at
    once. Mods keep their own settings in their own entries, and those are
    relative to the theme (100 % = as the theme has it), never a second
    choice of theme.
]]

require "ParavelsUI/Core/ModOptionsPage"
require "ParavelsUI/Theme/ThemePresets"
require "ParavelsUI/Theme/Theme"

local ThemePresets = PUI.ThemePresets

-- A saved index that names no preset (one removed since) picks the first.
PUI.ModOptionsPage.register({
    modId = "ParavelsUI",
    titleKey = "IGUI_PUI_Options",
    keyPrefix = "IGUI_PUI_",
    definitions = {
        { id = "theme", type = "choice", default = 1, choices = ThemePresets.names() },
    },
    onChange = function(values) PUI.Theme.apply(PUI.ThemePresets.ORDER[values.theme]) end,
})
