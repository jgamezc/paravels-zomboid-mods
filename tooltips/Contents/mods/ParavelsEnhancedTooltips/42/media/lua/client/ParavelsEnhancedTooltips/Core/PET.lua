--[[
    Paravel's Enhanced Tooltips - namespace

    Built on Paravel's UI (the ParavelsUI mod, global PUI): the theme,
    drawing, PUI.override and PUI.RowList come from there. This mod draws the
    game's tooltips in that theme: the tooltip of items (ISToolTipInv) and the
    generic one (ISToolTip: buttons, context menu options, building...).

    PET is the mod's only global. Every file adds one module to it, named
    after the file (Content/Common.lua is PET.Common), and keeps
    everything else local. Modules are created with
    `PET.X = PET.X or {}`, and every file can run again over the same
    table: functions are replaced, state kept on the table survives, and
    nothing is installed twice.
]]

require "ParavelsUI/Core/PUI"

PET = PET or {}
