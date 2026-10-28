--[[
    Paravel's UI - theme: Military

    Field kit: opaque olive drab, khaki text, thick lines, nearly square,
    earthy colours.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Military", {
    bg = rgb(0.12, 0.13, 0.09),        bgOpacity = 95,
    hover = 8,                         selected = 16,
    header = 8,                        stripe = 4,
    nested = 7,                        fillOpacity = 45,
    stateOpacity = 35,
    text = rgb(0.86, 0.82, 0.66),      muted = 50,
    textOnImage = "outline",
    border = rgb(0.55, 0.52, 0.36),    borderOpacity = 60,
    borderWidth = 2,
    radius = 4,                        radiusSmall = 2,
    tileShape = "soft",
    barShape = "soft",
    barThickness = 5,                  trackOpacity = 25,
    shadow = rgb(0.03, 0.03, 0.02),    shadowOpacity = 70,
    shadowOffset = 1,
    glow = rgb(0.86, 0.82, 0.66),      glowOpacity = 18,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 12,                      scrollWidth = 7,
    accent = rgb(0.55, 0.6, 0.3),
    success = rgb(0.6, 0.7, 0.3),      warning = rgb(0.85, 0.6, 0.15),
    danger = rgb(0.65, 0.2, 0.12),
    lightnessOffset = 15,              saturationOffset = 15,
    alphaOffset = 45,
    paletteColor1 = rgb(0.54, 0.33, 0.26),      paletteColor2 = rgb(0.44, 0.52, 0.28),
    paletteColor3 = rgb(0.625, 0.375, 0.375),   paletteColor4 = rgb(0.427, 0.517, 0.383),
    paletteColor5 = rgb(0.63, 0.48, 0.27),      paletteColor6 = rgb(0.25, 0.375, 0.225),
    paletteColor7 = rgb(0.64, 0.61, 0.46),      paletteColor8 = rgb(0.39, 0.285, 0.21),
    paletteColor9 = rgb(0.625, 0.663, 0.438),   paletteColor10 = rgb(0.486, 0.486, 0.414),
    paletteColor11 = rgb(0.675, 0.588, 0.325),  paletteColor12 = rgb(0.35, 0.42, 0.28),
})
