--[[
    Paravel's Enhanced Inventory - player options

    The settings players can change, on the game's own Mods options page.
    The look itself is the theme's (Paravel's UI, whose own entry on the
    same page picks it for every mod built on it): these only say what is
    shown, and set sizes, density and preferences of the player's own (the
    icons' halo and shadow, the stack count's font).
    The game saves them in ModOptions.ini; Options.get(id) reads the plain copy
    the framework keeps of them (ModOptionsPage.register), so drawing never
    walks the ModOptions tables. A change applies at once: it is reported
    as a change of look (PUI.Look.changed), the one signal that what is
    drawn may have to be made again.

    Translation keys: IGUI_PEI_Opt_<id> for a setting and
    IGUI_PEI_Section_<section> for a section title. Settings of a section
    are listed together, in the order they are shown.
]]

require "ParavelsEnhancedInventory/Core/PEI"
require "ParavelsUI/Core/ModOptionsPage"
require "ParavelsUI/Core/Look"

local ModOptionsPage = PUI.ModOptionsPage

local Options = PEI.Options or {}
PEI.Options = Options

-- Item icons are 32 px textures drawn with nearest filtering: only whole
-- multiples of 32 keep every texel the same size on screen.
Options.ICON_SIZES = { 32, 64, 96 }

Options.DEFINITIONS = {
    { section = "grid",  id = "iconSize",          type = "choice",  default = 1,
      choices = { "IGUI_PEI_IconSmall", "IGUI_PEI_IconMedium", "IGUI_PEI_IconLarge" } },
    { section = "grid",  id = "cellPadding",       type = "slider",  min = 0,  max = 32,  step = 1, default = 12 },
    { section = "grid",  id = "stackFont",         type = "choice",  default = 1,
      choices = { "IGUI_PEI_FontSmall", "IGUI_PEI_FontMedium", "IGUI_PEI_FontLarge" } },
    { section = "grid",  id = "stackBold",         type = "tickbox", default = true },
    { section = "grid",  id = "showTopIndicator",  type = "tickbox", default = true },
    { section = "grid",  id = "showDurabilityBar", type = "tickbox", default = true },
    { section = "items", id = "showBackground",    type = "tickbox", default = true },
    { section = "items", id = "showUpgradeMark",   type = "tickbox", default = true },
    { section = "items", id = "showVolumeMark",    type = "tickbox", default = true },
    { section = "items", id = "showIconShadow",    type = "tickbox", default = true },
    { section = "items", id = "showIconHalo",      type = "tickbox", default = true },
    { section = "items", id = "iconHaloIntensity", type = "slider",  min = 0, max = 200, step = 10, default = 100 },
    { section = "tabs",  id = "loopTabs",          type = "tickbox", default = true },
}
-- ------------------------------------------------------------------ --
-- Reading values
-- ------------------------------------------------------------------ --

function Options.get(id)
    return Options.values[id]
end

-- The grid's icon size in pixels, and its cell's side (icon plus padding).
function Options.gridIconSize()
    return Options.ICON_SIZES[Options.get("iconSize")]
end

function Options.gridCellSize()
    return Options.gridIconSize() + Options.get("cellPadding") * 2
end

ModOptionsPage.register({
    modId = "ParavelsEnhancedInventory",
    titleKey = "IGUI_PEI_Options",
    keyPrefix = "IGUI_PEI_",
    definitions = Options.DEFINITIONS,
    onChange = function(values)
        PEI.Options.values = values
        PUI.Look.changed()
    end,
})
