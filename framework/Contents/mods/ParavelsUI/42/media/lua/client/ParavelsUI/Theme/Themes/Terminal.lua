--[[
    Paravel's UI - theme: Terminal

    Old phosphor screen: black, green text and lines, square, striped
    rows, colours kept to the greens.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Terminal", {
    bg = rgb(0.02, 0.04, 0.02),        bgOpacity = 95,
    hover = 12,                        selected = 22,
    header = 8,                        stripe = 5,
    nested = 8,                        fillOpacity = 35,
    stateOpacity = 30,
    text = rgb(0.45, 1, 0.55),         muted = 50,
    textOnImage = "outline",
    border = rgb(0.3, 0.9, 0.4),       borderOpacity = 45,
    borderWidth = 1,
    radius = 0,                        radiusSmall = 0,
    tileShape = "square",
    barShape = "square",
    barThickness = 3,                  trackOpacity = 20,
    shadow = rgb(0, 0, 0),             shadowOpacity = 85,
    shadowOffset = 1,
    glow = rgb(0.45, 1, 0.55),         glowOpacity = 20,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 10,                      scrollWidth = 4,
    accent = rgb(0.3, 0.9, 0.4),
    success = rgb(0.45, 1, 0.55),      warning = rgb(0.95, 0.85, 0.25),
    danger = rgb(1, 0.35, 0.3),
    lightnessOffset = 20,              saturationOffset = 20,
    alphaOffset = 55,
    paletteColor1 = rgb(0.235, 0.865, 0.235),   paletteColor2 = rgb(0.32, 0.64, 0.16),
    paletteColor3 = rgb(0.405, 0.895, 0.568),   paletteColor4 = rgb(0.18, 0.72, 0.54),
    paletteColor5 = rgb(0.6, 0.88, 0.32),       paletteColor6 = rgb(0.12, 0.48, 0.18),
    paletteColor7 = rgb(0.28, 0.82, 0.55),      paletteColor8 = rgb(0.233, 0.525, 0.175),
    paletteColor9 = rgb(0.235, 0.865, 0.76),    paletteColor10 = rgb(0.338, 0.562, 0.356),
    paletteColor11 = rgb(0.617, 0.85, 0.15),    paletteColor12 = rgb(0.55, 0.85, 0.675),
})
