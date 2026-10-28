--[[
    Paravel's Enhanced Context Menu - namespace

    Built on Paravel's UI (the ParavelsUI mod, global PUI): the theme,
    drawing, PUI.override and the look's changes come from there. This mod
    draws the game's context menus in that theme.

    PECM is the mod's only global. Every file adds one module to it, named
    after the file (ContextMenu/ContextMenu.lua is PECM.ContextMenu), and
    keeps everything else local. Modules are created with
    `PECM.X = PECM.X or {}`, and every file can run again over the same
    table: functions are replaced, state kept on the table survives, and
    nothing is installed twice.
]]

require "ParavelsUI/Core/PUI"

PECM = PECM or {}
