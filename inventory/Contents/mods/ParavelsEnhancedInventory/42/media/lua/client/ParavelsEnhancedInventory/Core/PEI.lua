--[[
    Paravel's Enhanced Inventory - namespace

    Built on Paravel's UI (the ParavelsUI mod, global PUI): the theme,
    drawing, controls, PUI.override, PUI.listen and the look's changes come
    from there. This mod adds the inventory and loot windows' grid, list and
    window on top.

    PEI is the mod's only global. Every file adds one module to it, named
    after the file (Inventory/Grid/GridCell.lua is PEI.GridCell), and keeps
    everything else local. Modules are created with `PEI.X = PEI.X or {}`,
    and every file can run again over the same table: functions are
    replaced, state kept on the table survives, and nothing is installed
    twice.
]]

require "ParavelsUI/Core/PUI"

PEI = PEI or {}
