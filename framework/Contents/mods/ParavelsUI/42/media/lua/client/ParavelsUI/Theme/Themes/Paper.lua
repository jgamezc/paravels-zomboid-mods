--[[
    Paravel's UI - theme: Paper

    A field notebook: cream paper, dark brown ink, thin ink lines, soft
    corners, and the declared colour order as inks and coloured pencils.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Paper", {
    bg = rgb(0.95, 0.92, 0.84),        bgOpacity = 97,
    hover = 8,                         selected = 15,
    header = 5,                        stripe = 4,
    nested = 6,                        fillOpacity = 30,
    stateOpacity = 30,
    text = rgb(0.24, 0.17, 0.11),      muted = 65,
    textOnImage = "outline",
    border = rgb(0.45, 0.35, 0.25),    borderOpacity = 45,
    borderWidth = 1,
    radius = 6,                        radiusSmall = 4,
    tileShape = "soft",
    barShape = "soft",
    barThickness = 3,                  trackOpacity = 30,
    shadow = rgb(1, 0.98, 0.93),       shadowOpacity = 85,
    shadowOffset = 1,
    glow = rgb(1, 0.99, 0.95),         glowOpacity = 40,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 16,                      scrollWidth = 5,
    accent = rgb(0.22, 0.38, 0.62),
    success = rgb(0.25, 0.5, 0.25),    warning = rgb(0.75, 0.5, 0.1),
    danger = rgb(0.7, 0.18, 0.12),
    lightnessOffset = -10,             saturationOffset = 15,
    alphaOffset = 40,
    paletteColor1 = rgb(0.698, 0.244, 0.203),   paletteColor2 = rgb(0.364, 0.588, 0.252),
    paletteColor3 = rgb(0.769, 0.391, 0.517),   paletteColor4 = rgb(0.225, 0.412, 0.675),
    paletteColor5 = rgb(0.825, 0.478, 0.175),   paletteColor6 = rgb(0.18, 0.42, 0.3),
    paletteColor7 = rgb(0.508, 0.312, 0.648),   paletteColor8 = rgb(0.464, 0.296, 0.176),
    paletteColor9 = rgb(0.231, 0.546, 0.609),   paletteColor10 = rgb(0.405, 0.45, 0.495),
    paletteColor11 = rgb(0.856, 0.688, 0.184),  paletteColor12 = rgb(0.21, 0.233, 0.49),
})
