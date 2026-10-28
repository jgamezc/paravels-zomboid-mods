--[[
    Paravel's UI - theme: Classic

    Close to the game's own windows: black, white, square, solid grey lines.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Classic", {
    bg = rgb(0, 0, 0),                 bgOpacity = 80,
    hover = 10,                        selected = 20,
    header = 6,                        stripe = 2,
    nested = 8,                        fillOpacity = 45,
    stateOpacity = 35,
    text = rgb(1, 1, 1),               muted = 60,
    textOnImage = "outline",
    border = rgb(0.4, 0.4, 0.4),       borderOpacity = 100,
    borderWidth = 1,
    radius = 0,                        radiusSmall = 0,
    tileShape = "square",
    barShape = "square",
    barThickness = 4,                  trackOpacity = 25,
    shadow = rgb(0, 0, 0),             shadowOpacity = 80,
    shadowOffset = 1,
    glow = rgb(1, 1, 1),               glowOpacity = 18,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 12,                      scrollWidth = 8,
    accent = rgb(0.3, 0.6, 0.3),
    success = rgb(0.4, 1, 0.3),        warning = rgb(0.9, 0.7, 0.1),
    danger = rgb(0.8, 0.15, 0.15),
    lightnessOffset = 10,              saturationOffset = 25,
    alphaOffset = 55,
    paletteColor1 = rgb(0.825, 0.175, 0.175),   paletteColor2 = rgb(0.285, 0.698, 0.203),
    paletteColor3 = rgb(0.84, 0.36, 0.68),      paletteColor4 = rgb(0.175, 0.446, 0.825),
    paletteColor5 = rgb(0.875, 0.475, 0.125),   paletteColor6 = rgb(0.19, 0.57, 0.38),
    paletteColor7 = rgb(0.587, 0.325, 0.775),   paletteColor8 = rgb(0.507, 0.35, 0.193),
    paletteColor9 = rgb(0.158, 0.694, 0.742),   paletteColor10 = rgb(0.55, 0.55, 0.55),
    paletteColor11 = rgb(0.85, 0.757, 0.15),    paletteColor12 = rgb(0.25, 0.25, 0.75),
})
