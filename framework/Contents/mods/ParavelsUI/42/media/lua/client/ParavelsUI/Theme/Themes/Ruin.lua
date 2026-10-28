--[[
    Paravel's UI - theme: Ruin

    A modern take on a world gone to ruin: near-black warm charcoal,
    bone-white text, worn warm grey lines, field tones for meaning.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Ruin", {
    bg = rgb(0.071, 0.075, 0.067),     bgOpacity = 92,
    hover = 7,                         selected = 14,
    header = 4,                        stripe = 3,
    nested = 6,                        fillOpacity = 50,
    stateOpacity = 35,
    text = rgb(0.91, 0.886, 0.831),    muted = 55,
    textOnImage = "outline",
    border = rgb(0.55, 0.54, 0.48),    borderOpacity = 40,
    borderWidth = 1,
    radius = 16,                       radiusSmall = 9,
    tileShape = "round",
    barShape = "round",
    barThickness = 4,                  trackOpacity = 20,
    shadow = rgb(0, 0, 0),             shadowOpacity = 70,
    shadowOffset = 1,
    glow = rgb(0.91, 0.886, 0.831),    glowOpacity = 20,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 16,                      scrollWidth = 6,
    accent = rgb(0.54, 0.6, 0.36),
    success = rgb(0.45, 0.75, 0.35),   warning = rgb(0.85, 0.57, 0.18),
    danger = rgb(0.7, 0.23, 0.18),
    lightnessOffset = 8,               saturationOffset = 30,
    alphaOffset = 50,
    paletteColor1 = rgb(0.808, 0.28, 0.232),    paletteColor2 = rgb(0.458, 0.75, 0.25),
    paletteColor3 = rgb(0.829, 0.411, 0.62),    paletteColor4 = rgb(0.325, 0.55, 0.775),
    paletteColor5 = rgb(0.832, 0.52, 0.208),    paletteColor6 = rgb(0.22, 0.58, 0.43),
    paletteColor7 = rgb(0.58, 0.391, 0.769),    paletteColor8 = rgb(0.532, 0.355, 0.228),
    paletteColor9 = rgb(0.225, 0.729, 0.775),   paletteColor10 = rgb(0.505, 0.55, 0.595),
    paletteColor11 = rgb(0.798, 0.715, 0.302),  paletteColor12 = rgb(0.27, 0.3, 0.63),
})
